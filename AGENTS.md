# AGENTS.md

Canonical guidance for AI coding agents (Claude Code, Codex, and any other) working in this repository.
**This is the single source of truth** — `CLAUDE.md` imports this file (`@AGENTS.md`) so every agent shares
one set of instructions. Edit this file, not a per-agent copy.

## What this repo is

**libate** is a Docker **packaging** repo (no application source) for
[Libation](https://github.com/rmcrackan/Libation), the Audible audiobook library manager. It builds and
publishes images to Docker Hub at [`mdhmatt/libate`](https://hub.docker.com/r/mdhmatt/libate). GPLv3.

### Two image variants

| Variant | Dockerfile | Base image | Arch | Tags | What it is |
| --- | --- | --- | --- | --- | --- |
| **Headless** (primary) | `Dockerfile.headless` | `rmcrackan/libation:<ver>` (official CLI) | amd64 only | `:headless`, `:headless-<ver>` | LibationCli + a sync loop + a browser login helper. What the homelab's `libation-sync` stack runs. |
| **GUI** | `Dockerfile` | `lsiobase/kasmvnc:debianbookworm` | amd64 + arm64 | `:latest`, `:<ver>` | Libation's desktop UI over web VNC (KasmVNC) on port 3000. General/manual use. |

The headless variant is the **primary, maintained deployment path** (the homelab's KasmVNC GUI container
was retired 2026-08-10 in favour of it). The GUI image is still built and published for general Docker Hub
users.

**Headless internals:**
- `headless/sync-loop.sh` — each cycle re-stages config from the persistent volume, scans every configured
  Audible account, liberates new books, then runs `/hooks/post-sync.sh` if one is mounted (downstream
  integrations — AudioBookRequest reconcile, Audiobookshelf scan — live in the hook, OUTSIDE the image, so
  the deploying stack evolves them via GitOps without an image rebuild). `SYNC_INTERVAL` controls the sleep
  (`-1` = single cycle then exit).
- `headless/login-web.py` — a stdlib-only web helper to add Audible accounts from a browser. It drives
  `LibationCli login-external` under a pty (the PKCE verifier must stay alive across the two POSTs) and
  writes to the persistent `/config` via `--libationFiles`. **Security contract: it binds `0.0.0.0:8099`
  with NO authentication of its own** — anyone who can reach it can add/list accounts. It MUST sit behind
  the SSO gate (the homelab's Caddy config). It never sees an Amazon password (you log in on Amazon's own
  page); it only relays the post-login URL. `LOGIN_WEB_PORT` overrides the port.

## The two version numbers — do not conflate them

- **libate version** — the repo's OWN SemVer, as a git tag / GitHub release (`vX.Y.Z`). Tracks the
  *packaging*: Dockerfiles, scripts, CI, docs. This is what `CHANGELOG.md` and releases use.
- **Libation version** — the upstream app version (e.g. `13.7.5`) that an image packages. This is only ever
  a Docker image tag (`:<ver>`, `:headless-<ver>`) and a build arg. **Never treated as the repo version.**

A Libation bump is a libate patch/minor; a container-contract change is the SemVer bump it warrants on its
own. State the mapping in release notes ("libate v1.0.0 packages Libation 13.7.5").

### Updating the Libation version — SINGLE SOURCE OF TRUTH

The pinned Libation version lives in **exactly one place agents edit**: the `ARG LIBATION_VERSION=X.Y.Z`
line in **`Dockerfile`** (near the top, before `FROM`).

- `build.yml` **derives** it from the Dockerfile with `sed` and passes it as a build-arg to *both* images —
  so **never edit `build.yml` for the version** (the default `GITHUB_TOKEN` cannot push workflow-file
  changes anyway; that constraint is why the value was single-sourced).
- `Dockerfile.headless` carries the same `ARG` default so it is buildable standalone; the update-checker
  seds **both** files in lockstep and `libation-guard` **asserts they are equal**, so they cannot drift.
- Manual bump: edit `Dockerfile`'s `ARG LIBATION_VERSION=` and `Dockerfile.headless`'s to match, commit
  `chore: Update Libation to version X.Y.Z`. Or just let the daily `check-libation-updates` workflow open
  the PR. Do **not** hard-code the version in docs — link to Docker Hub tags / the changelog instead.

## CI / automation (`.github/workflows/`)

- **`build.yml`** — builds + pushes both images on push to `main` / manual dispatch, and builds (no push) on
  PRs. Derives `LIBATION_VERSION` from the Dockerfile. GUI is multi-arch; headless is amd64-only (arm64 QEMU
  apt-install ground for 15 min and got the job cancelled, 2026-08-06).
- **`checks.yml`** — the static-analysis gate on every push + PR: actionlint, ShellCheck, ruff + `py_compile`,
  hadolint (reads `.hadolint.yaml`), `docker compose config`, JSON validation. Tool versions are pinned;
  re-check them at source when touching this file (see the accessibility/build rules below). **Keep it green
  on the committed state.** What it CANNOT run — and must stay a live/manual check — is a real container
  smoke test (LibationCli + KasmVNC + the pty browser-login flow need a live container, a browser and real
  Audible credentials).
- **`libation-guard.yml`** — enforces "on the newest upstream Libation" (warns on PRs, fails on `main`,
  skips `update/libation-*` automation PRs) AND asserts the two Dockerfiles pin the same version. NB: `main`
  can flip red on an upstream Libation release with no code change here — a deliberate ratchet.
- **`check-libation-updates.yml`** — daily: queries upstream, verifies the `.deb` exists, checks for a
  duplicate PR, then seds **both** Dockerfiles and opens an `update/libation-<ver>` PR. The PR-body heredoc
  must keep the YAML block indentation — a column-0 heredoc breaks the block scalar and silently disables
  cron + `workflow_dispatch` (learned 2026-08-06; actionlint now guards this).
- **Renovate** (`renovate.json`) tracks `rmcrackan/Libation` GitHub releases (high priority, `deps:libation`
  label); **Dependabot** (`.github/dependabot.yml`) covers Docker (daily) + GitHub Actions (weekly). Both
  Dockerfiles carry the same Renovate annotation so they are treated as one.

## Standing build rules (the operator's, applied here)

- **Changelog & releases (Rule 7):** keep `CHANGELOG.md` in [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/)
  format (`## [Unreleased]` on top, dated SemVer sections, Added/Changed/Deprecated/Removed/Fixed/Security).
  Cut a tagged GitHub release on a real milestone. Say in the PR whether a release was cut.
- **Build & checking automation (Rule 8):** work is guarded by `checks.yml` with no manual step. A bug that
  slips through becomes a new check. **Base versions:** never pin a base image or action version from memory
  — check the current support state at source and record the date; note that Dependabot/Renovate watch
  package feeds, not OS/language support calendars (the GUI's `debianbookworm` = Debian 12 is a rolling tag;
  digest-pin it for Dependabot to bump it).
- **Accessibility (Rule 9):** the web login helper (`login-web.py`) ships HTML, so **WCAG 2.2 AA is
  non-negotiable, AAA the target**. It is currently AA-clean (document language, labelled form with
  `autocomplete`, captioned accounts table with header scopes, AA-contrast text/borders in both themes).
  Keep it so, and re-check with axe when changing the emitted markup.

## Conventions

- **Never modify application code** — there is none; this repo is deployment configuration only.
- **Branches:** manual/AI branches use the `claude/<description>-<session-id>` prefix; automation uses
  `update/libation-<version>`. **`main` has no direct pushes without the operator's say-so** — open a PR.
- **Git push retry** with exponential backoff (2s, 4s, 8s, 16s).
- **All output escaping stays via `html.escape`** in `login-web.py` — every interpolation is escaped and the
  login URL is regex-locked to `https://…amazon…`; keep that discipline for any new interpolation.
- **Docker builds:** test locally before committing Dockerfile changes —
  `docker build --build-arg LIBATION_VERSION=<ver> -t test .` (GUI) or `-f Dockerfile.headless`.
- UK English; the operator is UK-based (`£`, `Europe/London`).

## Ask before

Architecture changes (base image, VNC setup, container structure), breaking changes to an existing
deployment's contract, removing/disabling a CI workflow, pinning to a non-latest Libation version (fights
the guard), and security changes (user permissions, network, secrets).

## Known follow-ups

- **`login-web.py` hardening** (tracked, deferred): make the bind address an env var (keep `0.0.0.0` as the
  container default) + document that `:8099` must never be published without the SSO gate; cap the
  request-body read; guard the shared `pending` session dict with a `threading.Lock`; replace the fragile
  `"error"/"fail"` substring success heuristic with the child's exit status.
- **GUI base image** is the rolling `lsiobase/kasmvnc:debianbookworm` tag — digest-pin it so Dependabot can
  bump it, and record the Debian 12 → 13 (`debiantrixie`) evaluation date.
