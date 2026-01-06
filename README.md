# Libate - Libation Docker Container

[![Docker Hub](https://img.shields.io/docker/pulls/mdhmatt/libate?style=flat-square)](https://hub.docker.com/r/mdhmatt/libate)
[![Docker Image Size](https://img.shields.io/docker/image-size/mdhmatt/libate/latest?style=flat-square)](https://hub.docker.com/r/mdhmatt/libate)
[![GitHub](https://img.shields.io/github/license/MDHMatt/libate?style=flat-square)](LICENSE)

A Docker container for [Libation](https://github.com/rmcrackan/Libation) - the Audible audiobook library manager - with web-based VNC access powered by KasmVNC.

## 🎯 What is Libate?

Libate packages the Libation application in a Docker container with remote desktop access, allowing you to:
- **Manage your Audible library** from any device with a web browser
- **Run Libation on headless servers** without a physical display
- **Access your audiobooks remotely** through a secure web interface
- **Organize and backup** your Audible collection

## ✨ Features

- 🌐 **Web-based VNC access** on port 3000 - no VNC client needed
- 🏗️ **Multi-architecture support** - `amd64` and `arm64`
- 📦 **Optimized image size** - ~850MB with aggressive cleanup
- 🔄 **Automated version updates** - Always stays current with latest Libation releases
- 🛡️ **User/Group ID mapping** - Proper file permissions with PUID/PGID
- 💾 **Persistent storage** - Your library and settings survive container restarts

## 🚀 Quick Start

### Using Docker Compose (Recommended)

1. Create a `compose.yml` file:

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
    restart: on-failure
```

2. Start the container:

```bash
docker compose up -d
```

3. Access Libation in your browser:

```
http://localhost:3000
```

### Using Docker CLI

```bash
docker run -d \
  --name=libation \
  -p 3000:3000 \
  -v $(pwd)/Books:/config/Books \
  -v $(pwd)/data:/config/Libation \
  -e PUID=1000 \
  -e PGID=1000 \
  --restart on-failure \
  mdhmatt/libate:latest
```

## 📋 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | `1000` | User ID for file permissions |
| `PGID` | `1000` | Group ID for file permissions |

### Volumes

| Container Path | Description |
|----------------|-------------|
| `/config/Books` | Your audiobook library storage |
| `/config/Libation` | Libation application data and settings |

### Ports

| Port | Description |
|------|-------------|
| `3000` | KasmVNC web interface |

## 🔧 Advanced Configuration

### Custom User/Group IDs

To match your host user permissions:

```bash
docker run -d \
  -e PUID=$(id -u) \
  -e PGID=$(id -g) \
  ...
  mdhmatt/libate:latest
```

### Persistent Configuration

The container stores configuration in `/config/Libation`:
- `Settings.json` - Application settings
- `appsettings.json` - .NET configuration
- `logs/` - Application logs

Mount this directory to preserve settings across container updates.

## 📚 Documentation

- **Upstream Libation:** https://github.com/rmcrackan/Libation
- **Libation Wiki:** https://github.com/rmcrackan/Libation/wiki
- **Docker Hub:** https://hub.docker.com/r/mdhmatt/libate

## 🔄 Version Updates

This repository automatically tracks Libation releases:
- **Daily checks** for new versions
- **Automated PRs** when updates are available
- **Version enforcement** ensures latest version is always used

Current Version: **13.1.1**

## 🛠️ Building from Source

```bash
# Clone the repository
git clone https://github.com/MDHMatt/libate.git
cd libate

# Build the image
docker build -t libate:local .

# Run your local build
docker run -d -p 3000:3000 libate:local
```

## 🐛 Troubleshooting

### Container won't start
Check logs:
```bash
docker logs libation
```

### Permission issues with mounted volumes
Ensure PUID/PGID match your host user:
```bash
id -u  # Your user ID
id -g  # Your group ID
```

### Can't access web interface
1. Verify container is running: `docker ps`
2. Check port binding: `docker port libation`
3. Ensure port 3000 isn't blocked by firewall

## 🤝 Contributing

Contributions welcome! This is a containerization project - for Libation application issues, see the [upstream repository](https://github.com/rmcrackan/Libation).

### Repository Structure
- `Dockerfile` - Optimized multi-stage build
- `.github/workflows/` - Automated CI/CD pipelines
- `configs/` - Default configuration files
- `CLAUDE.md` - Comprehensive development documentation

## 📝 License

This project is licensed under the GPLv3 License - see the [LICENSE](LICENSE) file for details.

## 🙏 Credits

- **Libation** - [rmcrackan/Libation](https://github.com/rmcrackan/Libation)
- **Base Image** - [linuxserver.io KasmVNC](https://hub.docker.com/r/lsiobase/kasmvnc)

## ⚠️ Disclaimer

This is an unofficial Docker container for Libation. For official support, please visit the [Libation project](https://github.com/rmcrackan/Libation).

---

**Made with ❤️ for the audiobook community**
