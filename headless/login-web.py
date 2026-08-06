#!/usr/bin/env python3
"""Tiny web helper for adding Audible accounts to headless Libation.

Why this exists: `LibationCli login-external` only prints the Audible sign-in
URL when stdin is a TTY, and the PKCE verifier lives in that process - so the
process must stay alive between "give me the URL" and "here is the URL I was
redirected to". This app drives it under a pty so the whole flow works in a
browser, no terminal needed.

Deliberately stdlib-only (the image is a .NET runtime + python3-minimal) and
deliberately dumb: two POSTs, an in-memory session map, no database.

Writes go to LIBATION_FILES (default /config) - the PERSISTENT volume - via
--libationFiles, NOT the ephemeral /config-internal staging copy.

Protect it behind the SSO gate: anyone who can reach it can add or list
accounts. It never sees an Amazon password (you log in on Amazon's own page);
it only relays the post-login URL.
"""
from __future__ import annotations

import html
import json
import os
import pty
import re
import secrets
import signal
import subprocess
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs

LIBATION_CLI = os.environ.get("LIBATION_CLI", "/libation/LibationCli")
LIBATION_FILES = os.environ.get("LIBATION_FILES", "/config")
PORT = int(os.environ.get("LOGIN_WEB_PORT", "8099"))
SESSION_TTL = 900  # 15 min to complete a login before the child is reaped

URL_RE = re.compile(rb"https://\S*amazon\S*")
# pending[token] = {"pid": int, "fd": int, "started": float, "email": str}
pending: dict[str, dict] = {}


def reap_stale() -> None:
    now = time.time()
    for token, s in list(pending.items()):
        if now - s["started"] > SESSION_TTL:
            _kill(s)
            pending.pop(token, None)


def _kill(session: dict) -> None:
    try:
        os.kill(session["pid"], signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        pass
    try:
        os.close(session["fd"])
    except OSError:
        pass


def start_login(email: str, locale: str) -> tuple[str | None, str]:
    """Spawn login-external under a pty; return (login_url, session_token)."""
    pid, fd = pty.fork()
    if pid == 0:  # child
        os.execv(
            LIBATION_CLI,
            [
                "LibationCli", "login-external",
                "-a", email, "-l", locale,
                "--libationFiles", LIBATION_FILES,
            ],
        )
        os._exit(127)

    buf = b""
    deadline = time.time() + 45
    os.set_blocking(fd, False)
    while time.time() < deadline:
        try:
            chunk = os.read(fd, 4096)
        except BlockingIOError:
            time.sleep(0.2)
            continue
        except OSError:
            break
        if not chunk:
            break
        buf += chunk
        m = URL_RE.search(buf)
        if m:
            token = secrets.token_urlsafe(16)
            pending[token] = {"pid": pid, "fd": fd, "started": time.time(), "email": email}
            return m.group(0).decode(errors="replace").rstrip(), token

    _kill({"pid": pid, "fd": fd})
    return None, buf.decode(errors="replace")[-800:]


def finish_login(token: str, response_url: str) -> tuple[bool, str]:
    session = pending.pop(token, None)
    if not session:
        return False, "Session expired or unknown - start again."
    fd = session["fd"]
    try:
        os.write(fd, response_url.strip().encode() + b"\n")
    except OSError as exc:
        _kill(session)
        return False, f"Could not send the URL to LibationCli: {exc}"

    buf = b""
    deadline = time.time() + 90
    while time.time() < deadline:
        try:
            chunk = os.read(fd, 4096)
        except BlockingIOError:
            time.sleep(0.3)
            continue
        except OSError:
            break
        if not chunk:
            break
        buf += chunk
    _kill(session)
    out = buf.decode(errors="replace")
    ok = "error" not in out.lower() and "fail" not in out.lower()
    return ok, out[-1500:]


def list_accounts_raw() -> str:
    try:
        res = subprocess.run(
            [LIBATION_CLI, "list-accounts", "--libationFiles", LIBATION_FILES],
            capture_output=True, text=True, timeout=45,
        )
        return (res.stdout or "") + (res.stderr or "")
    except Exception as exc:  # noqa: BLE001 - surface anything to the page
        return f"(could not list accounts: {exc})"


def accounts_table() -> str:
    """Render list-accounts as a real HTML table.

    LibationCli prints a Unicode box-drawing table; dumping that into <pre> wraps
    and looks broken on narrow screens, so parse the │-delimited rows out of it.
    Falls back to a <pre> block if the format ever changes.
    """
    raw = list_accounts_raw()
    rows: list[list[str]] = []
    for line in raw.splitlines():
        if "│" not in line:
            continue
        cells = [c.strip() for c in line.strip().strip("│").split("│")]
        if any(cells):
            rows.append(cells)
    if not rows:
        body = html.escape(raw.strip()) or "No accounts configured yet."
        return f"<p>{body}</p>"

    header, *data = rows
    width = len(header)
    out = ["<table><thead><tr>"]
    out += [f"<th>{html.escape(c)}</th>" for c in header]
    out.append("</tr></thead><tbody>")
    if not data:
        out.append(f'<tr><td colspan="{width}">No accounts configured yet.</td></tr>')
    for r in data:
        r = (r + [""] * width)[:width]
        out.append("<tr>")
        for i, c in enumerate(r):
            low = c.lower()
            # Highlight the yes/no columns (Scan library, Authenticated) - an
            # unauthenticated account is the thing you actually need to act on.
            if header[i].strip().lower() in {"authenticated", "scan library"} and low in {"yes", "no"}:
                cls = "yes" if low == "yes" else "no"
                out.append(f'<td class="{cls}">{html.escape(c)}</td>')
            else:
                out.append(f"<td>{html.escape(c) or '&mdash;'}</td>")
        out.append("</tr>")
    out.append("</tbody></table>")
    return "".join(out)


PAGE = """<!doctype html><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1">
<title>Libation - add Audible account</title>
<style>
 body{{font-family:system-ui,sans-serif;max-width:44rem;margin:2rem auto;padding:0 1rem;line-height:1.5}}
 h1{{font-size:1.4rem}} label{{display:block;margin:.75rem 0 .25rem;font-weight:600}}
 input,textarea{{width:100%;padding:.5rem;font:inherit;border:1px solid #999;border-radius:6px}}
 button{{margin-top:1rem;padding:.6rem 1.1rem;font:inherit;border:0;border-radius:6px;
        background:#2d6cdf;color:#fff;cursor:pointer}}
 pre{{background:#f4f4f4;padding:.75rem;border-radius:6px;overflow-x:auto;white-space:pre-wrap}}
 table{{width:100%;border-collapse:collapse;margin-top:.5rem;font-size:.95rem}}
 th,td{{text-align:left;padding:.45rem .6rem;border-bottom:1px solid #e0e0e0}}
 th{{font-weight:600;background:#f4f4f4}}
 td.yes{{color:#137333;font-weight:600}} td.no{{color:#b3261e;font-weight:600}}
 .wrap{{overflow-x:auto}}
 .step{{border:1px solid #ddd;border-radius:8px;padding:1rem;margin:1rem 0}}
 .ok{{color:#137333}} .err{{color:#b3261e}}
 a.big{{display:inline-block;margin:.5rem 0;font-size:1.05rem;word-break:break-all}}
 @media (prefers-color-scheme:dark){{
   body{{background:#16181c;color:#e6e6e6}} pre{{background:#23262b}}
   input,textarea{{background:#23262b;color:#e6e6e6;border-color:#555}}
   .step{{border-color:#39383d}}
   th{{background:#23262b}} th,td{{border-bottom-color:#39383d}}
   td.yes{{color:#6dd58c}} td.no{{color:#f28b82}}
 }}
</style>
<h1>Libation - add an Audible account</h1>
{body}
<div class=step>
<h2 style="font-size:1.1rem">Configured accounts</h2>
<div class=wrap>{accounts}</div>
</div>
"""

STEP1 = """<div class=step>
<form method=post action=/start>
<label for=email>Audible / Amazon email</label>
<input id=email name=email type=email required placeholder="someone@example.com">
<label for=locale>Marketplace</label>
<input id=locale name=locale value=uk required>
<button type=submit>Get sign-in link</button>
</form>
<p style="font-size:.9rem;color:#777">Repeat once per family account. You sign in on
Amazon's own page - this helper never sees your password.</p>
</div>"""


def step2(url: str, token: str) -> str:
    return f"""<div class=step>
<p><strong>1.</strong> Open this link, sign in to Amazon/Audible, and complete any 2FA:</p>
<a class=big href="{html.escape(url)}" target=_blank rel=noopener>{html.escape(url[:110])}...</a>
<p><strong>2.</strong> You will land on a page that may look like an error - that is expected.
Copy the <em>whole URL from your browser's address bar</em> and paste it below.</p>
<form method=post action=/finish>
<input type=hidden name=token value="{html.escape(token)}">
<label for=response>Final URL after signing in</label>
<textarea id=response name=response rows=4 required
 placeholder="https://www.amazon.co.uk/ap/maplanding?openid...."></textarea>
<button type=submit>Finish sign-in</button>
</form>
</div>"""


class Handler(BaseHTTPRequestHandler):
    server_version = "libation-login/1.0"

    def _send(self, body: str, code: int = 200) -> None:
        raw = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _page(self, body: str, code: int = 200) -> None:
        self._send(PAGE.format(body=body, accounts=accounts_table()), code)

    def _form(self) -> dict[str, str]:
        length = int(self.headers.get("Content-Length", "0") or 0)
        data = self.rfile.read(length).decode()
        return {k: v[0] for k, v in parse_qs(data).items()}

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        reap_stale()
        if self.path.startswith("/healthz"):
            self._send("ok")
            return
        self._page(STEP1)

    def do_POST(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        reap_stale()
        form = self._form()
        if self.path.startswith("/start"):
            email = (form.get("email") or "").strip()
            locale = (form.get("locale") or "uk").strip()
            if not email:
                self._page("<p class=err>Email is required.</p>" + STEP1, 400)
                return
            url, token_or_err = start_login(email, locale)
            if not url:
                self._page(
                    "<p class=err>Could not get a sign-in link.</p><pre>"
                    + html.escape(token_or_err) + "</pre>" + STEP1, 500)
                return
            self._page(step2(url, token_or_err))
        elif self.path.startswith("/finish"):
            ok, out = finish_login(form.get("token", ""), form.get("response", ""))
            cls = "ok" if ok else "err"
            msg = "Account added." if ok else "Sign-in did not complete."
            self._page(
                f"<p class={cls}><strong>{msg}</strong></p><pre>{html.escape(out)}</pre>" + STEP1)
        else:
            self._page(STEP1, 404)

    def log_message(self, fmt: str, *args) -> None:  # quieter, still useful
        print("[login-web] " + fmt % args, flush=True)


if __name__ == "__main__":
    print(f"[login-web] serving on :{PORT}, libationFiles={LIBATION_FILES}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
