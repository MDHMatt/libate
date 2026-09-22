# Changelog

All notable changes to **libate** (the Docker packaging for [Libation](https://github.com/rmcrackan/Libation))
are documented here.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Two version numbers, kept separate.** `libate` has its OWN version — the git tag / GitHub release
> (e.g. `v1.0.0`) — tracking the *packaging*: the Dockerfiles, scripts, CI and docs. It is independent of
> the **Libation** version it packages (e.g. `13.7.5`), which is only ever a Docker image tag. A Libation
> bump is a libate patch/minor; a change to the container contract is the SemVer bump it warrants on its own.

## [Unreleased]

### Security
- **`login-web.py` hardening** (closes #61) — the request-body read is capped at 64 KiB and an
  oversized/malformed `Content-Length` is rejected with 413 + connection close, so it can no longer
  exhaust memory; the shared session map is guarded by a `threading.Lock`.

### Changed
- **`login-web.py`** — the bind address is configurable via `LOGIN_WEB_BIND` (default `0.0.0.0`,
  still required to sit behind the SSO gate); login success is judged by LibationCli's **exit status**
  instead of scanning its output for "error"/"fail" (which flipped on benign strings like "0 errors");
  child processes are now reaped, fixing a zombie-process leak.

## [1.1.0] - 2026-09-21

### Changed
- **Libation 13.7.5 → 14.2.2** (major upstream release). Both image variants now package
  14.2.2; both Dockerfiles bumped in lockstep (the version guard asserts they match). The
  libate container contract (ports, volumes, env, image tags) is unchanged, so this is a
  libate minor bump. Clears the ~month-old backlog of unmerged upstream bumps (#47–#59).

## [1.0.0] - 2026-09-20

First tagged release. Packages **Libation 13.7.5**. Two image variants are published to
[`mdhmatt/libate`](https://hub.docker.com/r/mdhmatt/libate): the GUI/KasmVNC image (`:latest`,
`:<libation-version>`) and the headless image (`:headless`, `:headless-<libation-version>`).

It also brings the repository in line with the current build principles: a Keep-a-Changelog history and
tagged releases, a static-analysis CI gate, an accessible (WCAG 2.2 AA) web login helper, and a canonical
`AGENTS.md`.

### Added
- **Headless variant** (`Dockerfile.headless`): the official upstream `rmcrackan/libation` CLI image plus a
  sync loop with a post-cycle hook (`/hooks/post-sync.sh`), published as `:headless` / `:headless-<ver>`.
  Scans every configured Audible account and liberates into the Audiobookshelf layout.
- **Browser login helper** (`headless/login-web.py`): drives `LibationCli login-external` under a pty so
  accounts can be added from a browser with no terminal; renders configured accounts as an HTML table with
  per-account book counts.
- **GUI/KasmVNC container** (`Dockerfile`): web VNC on port 3000, PUID/PGID mapping, `/config/Books` +
  `/config/Libation` volumes.
- **CI / automation**: multi-arch (amd64 + arm64) build-and-push with GHA layer caching and concurrency
  control; a daily upstream update-checker that opens auto-PRs (API retry + duplicate-PR guard + `.deb`
  verification); a version-consistency guard; Renovate + Dependabot (Docker daily, GitHub Actions weekly).
- **Static-analysis CI gate** (`.github/workflows/checks.yml`): actionlint, ShellCheck, ruff + `py_compile`,
  hadolint, `docker compose config` and JSON validation on every push and PR.
- **Accessibility**: the web login helper now meets WCAG 2.2 AA — a document language, a labelled form with
  `autocomplete`, a captioned accounts table with header scopes, and AA-contrast text/borders in both themes.
- Housekeeping: `AGENTS.md` as the canonical cross-agent guide (with a thin `@AGENTS.md` `CLAUDE.md`), a
  `.gitignore`, and a `.hadolint.yaml` baseline.

### Changed
- **Image-size optimisation** (GUI): aggressive cleanup (docs/man/locales/.NET debug symbols) and
  config-copy-after-install layer ordering — image ~1 GB → ~850 MB, config-change rebuilds ~10 min → ~30 s.
- Single-sourced `LIBATION_VERSION` to the `Dockerfile` ARG; `build.yml` derives it (so the update-checker
  never edits a workflow file). Both Dockerfiles are now kept in lockstep by the updater and the guard.
- Headless image built **amd64-only** (arm64 QEMU apt-install ground for 15 min and got cancelled); the GUI
  image stays multi-arch.
- CI actions bumped to current majors (checked at source 2026-09-20); `docker/build-push-action` held at v6
  deliberately (v7 changes the pushed image's attestation manifest — a measured, separate bump).

### Fixed
- **`compose.yml`** did not parse: `ports` was a scalar (must be a sequence), so the documented
  `docker compose up -d` failed off the committed file. Fixed, plus the PUID/PGID + TZ the README documents.
- Headless: pre-create `/config` and `/db` world-writable so named volumes are writable under an arbitrary
  uid; delegate to upstream's entrypoint (env initialised) and run the loop as CMD; install full `python3`
  (not `python3-minimal`, which omits `html` / `http.server`).
- CI: restored `check-libation-updates` after a column-0 heredoc broke its YAML; dropped an invalid
  `workflows:` permission scope.
- Docs: `CLAUDE.md` / `README` corrected — they claimed Libation 13.1.1 (actual 13.7.5) and described only
  the GUI container.

[Unreleased]: https://github.com/MDHMatt/libate/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/MDHMatt/libate/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/MDHMatt/libate/releases/tag/v1.0.0
