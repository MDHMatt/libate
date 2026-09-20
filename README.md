# Libate — Libation in Docker

[![Docker Hub](https://img.shields.io/docker/pulls/mdhmatt/libate?style=flat-square)](https://hub.docker.com/r/mdhmatt/libate)
[![Docker Image Size](https://img.shields.io/docker/image-size/mdhmatt/libate/latest?style=flat-square)](https://hub.docker.com/r/mdhmatt/libate)
[![GitHub release](https://img.shields.io/github/v/release/MDHMatt/libate?style=flat-square)](https://github.com/MDHMatt/libate/releases)
[![GitHub](https://img.shields.io/github/license/MDHMatt/libate?style=flat-square)](LICENSE)

Docker packaging for [Libation](https://github.com/rmcrackan/Libation) — the Audible audiobook library
manager. Two image variants are published to [`mdhmatt/libate`](https://hub.docker.com/r/mdhmatt/libate):
a **headless** CLI/sync image and a **GUI** desktop image served over web VNC.

## 🔢 Versions

Libate has **two independent version numbers** — keep them separate:

| Version | What it is | Where it lives |
| --- | --- | --- |
| **libate release** (e.g. `v1.0.0`) | This repository's own [SemVer](https://semver.org) — the *packaging*: Dockerfiles, scripts, CI, docs. | Git tags · [GitHub Releases](https://github.com/MDHMatt/libate/releases) · [`CHANGELOG.md`](CHANGELOG.md) |
| **Libation version** (e.g. `13.7.5`) | The upstream [Libation](https://github.com/rmcrackan/Libation) app version an image bundles. | Docker **image tags** + the `LIBATION_VERSION` build arg |

A Libation bump is a libate patch/minor; a change to the container contract is the SemVer bump it warrants
on its own. Example: **libate `v1.0.0` packages Libation `13.7.5`.**

### Image tags

| Tag | Variant | Contents |
| --- | --- | --- |
| `mdhmatt/libate:latest` | GUI | Newest GUI/KasmVNC build from `main` |
| `mdhmatt/libate:<libation-version>` — e.g. `:13.7.5` | GUI | GUI build pinned to that Libation version |
| `mdhmatt/libate:headless` | Headless | Newest headless build from `main` |
| `mdhmatt/libate:headless-<libation-version>` — e.g. `:headless-13.7.5` | Headless | Headless build pinned to that Libation version |

The current Libation version is pinned in [`Dockerfile`](Dockerfile) (`ARG LIBATION_VERSION`) and tracked
automatically against upstream — see the [Docker Hub tags](https://hub.docker.com/r/mdhmatt/libate/tags).

## 🧭 Which variant?

| | **Headless** (`:headless`) | **GUI** (`:latest`) |
| --- | --- | --- |
| Use it for | Automated, unattended liberation on a server | Interactive use / managing settings with the real Libation desktop UI |
| Base | Official `rmcrackan/libation` CLI | `lsiobase/kasmvnc` (Debian + KasmVNC) |
| Interface | A sync loop + an optional browser login helper | Web VNC on port 3000 |
| Architectures | amd64 | amd64 + arm64 |

---

## 🖥️ GUI variant (`:latest`)

Libation's desktop UI in a container, reachable from any browser over web VNC — no VNC client needed.

### Quick start (Docker Compose)

```yaml
services:
  libation:
    image: mdhmatt/libate:latest
    container_name: libation
    ports:
      - "3000:3000"
    volumes:
      - ./Books:/config/Books
      - ./data:/config/Libation
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
    restart: on-failure
```

```bash
docker compose up -d   # then open http://localhost:3000
```

(A ready-to-use [`compose.yml`](compose.yml) is in the repo.)

### Docker CLI

```bash
docker run -d \
  --name=libation \
  -p 3000:3000 \
  -v "$(pwd)/Books:/config/Books" \
  -v "$(pwd)/data:/config/Libation" \
  -e PUID=1000 -e PGID=1000 -e TZ=Europe/London \
  --restart on-failure \
  mdhmatt/libate:latest
```

### Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | `1000` | User ID for file permissions |
| `PGID` | `1000` | Group ID for file permissions |
| `TZ` | — | Container timezone (e.g. `Europe/London`) |

| Container path | Description |
|----------------|-------------|
| `/config/Books` | Audiobook library storage |
| `/config/Libation` | Libation application data and settings |

| Port | Description |
|------|-------------|
| `3000` | KasmVNC web interface |

---

## 🤖 Headless variant (`:headless`)

The official upstream LibationCli image plus a **sync loop** and an **optional browser login helper** — for
unattended liberation on a server, with a post-cycle hook for downstream integrations.

- **Sync loop** (`headless/sync-loop.sh`): each cycle re-stages config, scans every configured Audible
  account, liberates new books, then runs `/hooks/post-sync.sh` if one is mounted. `SYNC_INTERVAL` sets the
  sleep between cycles (`-1` = run once and exit).
- **Post-sync hook**: bind-mount your own `/hooks/post-sync.sh` to trigger downstream work (e.g. an
  Audiobookshelf scan) without rebuilding the image.
- **Adding accounts** — either the CLI (`docker exec -it <container> LibationCli login-external`) or the
  browser helper `headless/login-web.py` (drives the login under a pty; renders an accounts table with
  per-account book counts).

> ⚠️ **The login helper has no authentication of its own** and binds `0.0.0.0:8099`. Anyone who can reach it
> can add or list Audible accounts. **Only expose it behind an authenticating reverse proxy / SSO gate** —
> never publish `:8099` directly. It never sees your Amazon password (you sign in on Amazon's own page).

---

## 🔄 Automated version updates

A daily workflow checks for new Libation releases, verifies the `.deb` exists, and opens an update PR; a
guard workflow keeps `main` on the newest upstream version and both Dockerfiles in lockstep. See
[`CHANGELOG.md`](CHANGELOG.md) for released versions.

## 🛠️ Building from source

```bash
git clone https://github.com/MDHMatt/libate.git
cd libate

# GUI image
docker build -t libate:local .

# Headless image
docker build -f Dockerfile.headless -t libate:headless-local .
```

## 🐛 Troubleshooting

- **Container won't start:** `docker logs libation`
- **Permission issues on volumes:** ensure `PUID`/`PGID` match your host user (`id -u`, `id -g`)
- **Can't reach the GUI:** verify the container is running (`docker ps`), the port binding
  (`docker port libation`), and that port 3000 isn't firewalled

## 🤝 Contributing

Contributions welcome — this is a containerisation project; for Libation application issues see the
[upstream repository](https://github.com/rmcrackan/Libation). Agent/contributor conventions live in
[`AGENTS.md`](AGENTS.md).

## 📝 License

GPLv3 — see [LICENSE](LICENSE).

## 🙏 Credits

- **Libation** — [rmcrackan/Libation](https://github.com/rmcrackan/Libation)
- **GUI base image** — [linuxserver.io KasmVNC](https://hub.docker.com/r/lsiobase/kasmvnc)

---

*Unofficial Docker packaging for Libation. For official support, see the
[Libation project](https://github.com/rmcrackan/Libation).*
