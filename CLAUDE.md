# CLAUDE.md - AI Assistant Guide for Libate Repository

## Repository Overview

**Project Name:** Libate
**Purpose:** Docker containerization wrapper for [Libation](https://github.com/rmcrackan/Libation), an Audible audiobook library manager
**Tech Stack:** Docker, Docker Compose, KasmVNC, GitHub Actions
**License:** GPLv3
**Docker Registry:** `mdhmatt/libate` on DockerHub

This repository does NOT contain application source code. It is a deployment and automation project focused on:
- Packaging Libation in a Docker container with web-based VNC access
- Automating version updates from upstream Libation releases
- Maintaining version consistency across the codebase
- Providing easy deployment via Docker Compose

## Project Structure

```
/home/user/libate/
├── .github/
│   ├── workflows/
│   │   ├── build.yml                      # Docker build & push to DockerHub
│   │   ├── check-libation-updates.yml     # Daily upstream version checks
│   │   └── libation-guard.yml             # Version consistency enforcement
│   └── dependabot.yml                     # Automated dependency updates
├── configs/
│   ├── autostart                          # Bash script to launch Libation
│   ├── menu.xml                           # Openbox window manager menu
│   ├── appsettings.json                   # .NET application configuration
│   └── Settings.json                      # Libation application settings
├── .dockerignore                          # Docker build exclusions
├── Dockerfile                             # Multi-stage container build
├── compose.yml                            # Docker Compose orchestration
├── renovate.json                          # Renovate dependency management
├── LICENSE                                # GPLv3 license file
└── README.md                              # Basic project information
```

## Key Architecture Concepts

### Container Design
- **Base Image:** `lsiobase/kasmvnc:debianbookworm` (Debian Bookworm + KasmVNC)
- **VNC Access:** Web-based VNC on port 3000 for remote GUI access
- **User Mapping:** Supports PUID/PGID environment variables for proper file permissions
- **Non-root Execution:** Runs as `kasm-user` for security
- **Volume Mounts:**
  - `/config/Books` - Audiobook library storage
  - `/config/Libation` - Application data and configuration

### Version Management Philosophy
This repository implements **strict version synchronization**:
1. The `LIBATION_VERSION` in `Dockerfile` is the single source of truth
2. The same version must be specified in `.github/workflows/build.yml`
3. CI fails if versions don't match the latest upstream release
4. Automated workflows check for new releases daily and create PRs to `main`
5. Three-layer enforcement: Renovate, Dependabot, and custom guard workflow

## Development Workflows

### Branch Strategy
- **`main`** - Production branch, builds and pushes Docker images automatically
- **Feature branches** - Use `claude/` prefix for AI-generated branches (e.g., `claude/add-feature-abc123`)

### CI/CD Pipeline

#### 1. Build Workflow (`.github/workflows/build.yml`)
**Triggers:** Push to `main`, pull requests, manual dispatch
**Optimizations:**
- Multi-platform builds: `linux/amd64`, `linux/arm64`
- Docker layer caching via GitHub Actions cache
- Concurrency control (cancels outdated builds)
- Only logs into DockerHub when actually pushing

**Job:**
- `build` - Builds and pushes Docker images
  - Tags: `<sha>`, `<version>`, `latest`
  - Only pushes on successful merges to `main` (not on PRs)
  - Includes OCI metadata and annotations

**Docker Build Arguments:**
- `LIBATION_VERSION` - Version to download from upstream releases

#### 2. Version Guard Workflow (`.github/workflows/libation-guard.yml`)
**Triggers:** Push to `main`, PRs, weekly schedule (Mondays 7 AM UTC)
**Purpose:** Enforce version consistency
**Smart Behavior:**
- **Skips** automation PRs (`update/libation-*`) to avoid catch-22
- **Warns** on PRs (doesn't fail)
- **Enforces** on main branch (fails if not latest)
- Provides clear notices when versions match

**Process:**
1. Check if PR is from automation (skip if yes)
2. Extract `LIBATION_VERSION` from `Dockerfile`
3. Fetch latest release from `rmcrackan/Libation` GitHub API
4. Warn on PRs, fail on main if versions don't match

#### 3. Update Checker Workflow (`.github/workflows/check-libation-updates.yml`)
**Triggers:** Daily at 2 AM UTC, manual dispatch
**Purpose:** Automated version updates
**Improvements:**
- API retry logic (3 attempts with backoff)
- Verifies .deb package exists before creating PR
- Checks for duplicate PRs (prevents spam)
- Proper token handling for PR creation
- Links to release notes in PR body

**Process:**
1. Query GitHub API for latest Libation release (with retries)
2. Verify .deb package is available
3. Check if update PR already exists
4. Compare with current `LIBATION_VERSION` in `build.yml`
5. If newer version exists and package verified:
   - Update `build.yml` and `Dockerfile`
   - Create PR with branch `update/libation-<version>`
   - Label with `automation` and `dependencies`

### Dependency Management

**Dependabot** (`.github/dependabot.yml`):
- **Docker:** Daily checks, targets `main` branch
- **GitHub Actions:** Weekly checks, targets `main` branch
- Max 5 open PRs per ecosystem

**Renovate** (`renovate.json`):
- Tracks `rmcrackan/Libation` GitHub releases
- High priority (prPriority: 10)
- Labels PRs with `deps:libation`
- Timezone: Europe/London

## Important Files Reference

### Dockerfile (Container Build - Fully Optimized)
**Current Version:** `LIBATION_VERSION=13.1.1` (line 10)
**Key Sections:**
- Lines 1-10: Build arguments and version setup with optimization comments
- Lines 12-26: Base image and directory creation
- Lines 28-29: System configuration
- Lines 31-40: Dependencies installation with BuildKit cache mounts
- Lines 42-48: Libation download and install
- Lines 50-56: Post-install configuration
- Lines 58-60: Icon download
- Lines 62-83: Aggressive cleanup layer (~100-150MB savings)
- Lines 85-96: Config files copy and permissions (moved AFTER expensive operations)
- Line 99: Port exposure (3000)

**Architecture Detection:** Automatically detects `amd64`, `arm64`, etc. for proper .deb download

**Build Optimizations:**
- **Layer caching:** Config files copied AFTER Libation install
  - Config change rebuild: 30 seconds (was 10 minutes!)
- **Split RUN commands:** 7 logical steps for better debugging
- **BuildKit cache mounts:** Apt packages cached between builds (saves 1-2 min)
- **Aggressive cleanup:** Removes docs, man pages, locales, .NET debug symbols
  - Image size: ~750-850MB (was ~1GB, saves 150-250MB)

**IMPORTANT - Single Source of Truth:**
- Only ONE `ARG LIBATION_VERSION=X.Y.Z` declaration exists (line 10)
- This is re-declared after FROM (line 14) to make it available in build stages
- No duplicate or conflicting version declarations

**Critical:** The Renovate comment on line 9 enables automatic dependency tracking:
```dockerfile
# renovate: datasource=github-releases depName=rmcrackan/Libation extractVersion=^v?(?<version>.*)$
```

### compose.yml (Orchestration)
- Service name: `libation`
- Image: `mdhmatt/libate:latest`
- Port mapping: `3000:3000`
- Volumes: `./Books` → `/config/Books`, `./data` → `/config/Libation`
- Restart policy: `on-failure`
- Grace period: `1m` for shutdown

### configs/autostart (Startup Script)
Simple bash script that:
1. Checks for `/usr/bin/libation`
2. Falls back to `/usr/share/libation/Libation`
3. Exits with error if neither found

**Note:** Must be executable (`chmod +x`)

### configs/Settings.json (Libation Configuration)
Contains default Libation settings:
- Books directory: `/config/Books`
- Theme: Dark variant
- Logging: Serilog with monthly rolling logs to `/config/Libation/logs`
- Auto-scan enabled
- Window positions and sizes for UI elements

## Common Development Tasks

### Updating Libation Version

**Manual Process:**
1. Check latest release: `curl -s https://api.github.com/repos/rmcrackan/Libation/releases/latest | jq -r '.tag_name'`
2. Update `Dockerfile` line 14: `ARG LIBATION_VERSION=X.Y.Z`
3. Update `.github/workflows/build.yml` line 21: `LIBATION_VERSION: X.Y.Z`
4. Commit with message: `chore: Update Libation to version X.Y.Z`
5. Push and verify CI passes

**Automated Process:**
- Wait for daily `check-libation-updates.yml` workflow
- Review and merge auto-generated PR

### Testing Container Locally

```bash
# Build with specific version
docker build --build-arg LIBATION_VERSION=12.5.2 -t libate:test .

# Run with compose
docker compose up -d

# Access VNC interface
# Open browser to http://localhost:3000

# View logs
docker compose logs -f libation

# Clean up
docker compose down
```

### Adding New Configuration Files

1. Add file to `configs/` directory
2. Update `Dockerfile` with `COPY` command (around lines 38-46)
3. Ensure proper permissions (use `chown` if needed)
4. Test container build locally

### Modifying Workflow Behavior

**build.yml:**
- Change Docker tags in `tags:` sections (lines 56-59, 90-93)
- Modify build frequency by adjusting `on:` triggers
- Add build arguments in `build-args:` sections

**libation-guard.yml:**
- Adjust schedule cron expression (line 7) for different enforcement frequency
- Modify version extraction regex (line 18) if Dockerfile format changes

## AI Assistant Guidelines

### When Working on This Repository

1. **Never Modify Application Code** - This repo contains no Libation source code, only deployment configuration

2. **Maintain Version Consistency** - Always update versions in BOTH:
   - `Dockerfile` (line 14)
   - `.github/workflows/build.yml` (line 21)

3. **Test Docker Builds** - Before committing Dockerfile changes:
   ```bash
   docker build --build-arg LIBATION_VERSION=<version> -t test .
   ```

4. **Respect Branch Strategy:**
   - Feature branches must start with `claude/` prefix
   - Push to designated branch (check task description)
   - Never push directly to `main` without permission

5. **Configuration Changes:**
   - Any new files in `configs/` need corresponding `COPY` in Dockerfile
   - Preserve file permissions (especially for `autostart` script)
   - Test that configuration files are accessible at runtime

6. **Dependency Updates:**
   - Prefer automated PRs from workflows/Renovate/Dependabot
   - If manual update needed, verify version exists on GitHub releases
   - Check that .deb package is available for all architectures

7. **CI/CD Modifications:**
   - Workflow changes should maintain existing triggers unless explicitly requested
   - Don't disable `libation-guard.yml` - it's critical for version enforcement
   - Test workflow syntax with `actionlint` if available

8. **Documentation:**
   - Update this file (CLAUDE.md) when making structural changes
   - Keep version numbers in documentation examples current
   - Document any new environment variables or configuration options

### Common Pitfalls to Avoid

1. **Version Mismatch:** Updating version in only one location (Dockerfile OR build.yml)
2. **Permission Issues:** Forgetting to set execute permission on scripts (`chmod +x`)
3. **Architecture Assumptions:** Hardcoding `amd64` instead of using `$TARGETARCH`
4. **Volume Paths:** Changing volume paths without updating Settings.json
5. **Port Conflicts:** Exposing different ports in Dockerfile vs compose.yml
6. **Git Operations:** Using branches without `claude/` prefix (will cause 403 on push)

### Git Push Retry Logic

**CRITICAL:** Git push operations must implement retry with exponential backoff:
```bash
# Retry up to 4 times: 2s, 4s, 8s, 16s delays
# Example:
git push -u origin claude/my-branch || sleep 2
git push -u origin claude/my-branch || sleep 4
# ... etc
```

**Branch Naming:** Must use format `claude/<description>-<session-id>` for successful push

### When to Ask for Clarification

1. **Architecture Changes:** Modifying base image, VNC setup, or container structure
2. **Breaking Changes:** Updates that would affect existing user deployments
3. **Workflow Removal:** Disabling or removing any CI/CD workflows
4. **Version Pinning:** If asked to pin to non-latest version (conflicts with guard workflow)
5. **Security Changes:** Modifying user permissions, network configuration, or secrets

## Version History Context

**Current State (as of 2026-01-06):**
- Libation Version: 13.1.1
- Base Image: lsiobase/kasmvnc:debianbookworm
- Docker Hub: mdhmatt/libate
- GitHub: MDHMatt/libate
- Branch: main (dev branch removed)

**Recent Changes:**
- **Docker image optimization:**
  - Added aggressive cleanup to reduce image size by ~50-100MB
  - Remove .NET debug symbols and documentation files
  - Target size: ~850-900MB (down from ~1GB)
- **Simplified repository structure:**
  - Removed `dev` branch - all work happens on `main`
  - Simplified build workflow to single job
  - Updated all automation to target `main` branch
- **Fixed version management issues:**
  - Removed duplicate LIBATION_VERSION declarations in Dockerfile
  - Fixed check-libation-updates.yml to update correct ARG line
  - Streamlined version to single source of truth
- Updated to Libation v13.1.1
- Implemented version guard workflow for enforcement
- Added automated update checker workflow
- Configured Dependabot for Docker and GitHub Actions
- Set up Renovate for Libation release tracking

## Quick Reference Commands

```bash
# Check current version
grep LIBATION_VERSION Dockerfile | head -1

# Get latest upstream version
curl -s https://api.github.com/repos/rmcrackan/Libation/releases/latest | jq -r .tag_name

# Build container
docker build -t libate:local .

# Run container
docker compose up -d

# View logs
docker compose logs -f

# Stop container
docker compose down

# Test version guard locally
bash -c "$(curl -s https://raw.githubusercontent.com/MDHMatt/libate/main/.github/workflows/libation-guard.yml | grep -A 20 'Extract pinned')"
```

## External Resources

- **Upstream Libation:** https://github.com/rmcrackan/Libation
- **KasmVNC Base Image:** https://hub.docker.com/r/lsiobase/kasmvnc
- **Docker Hub Repository:** https://hub.docker.com/r/mdhmatt/libate
- **Libation Documentation:** https://github.com/rmcrackan/Libation/wiki

## Support and Feedback

For issues related to:
- **This container:** Open issue at MDHMatt/libate
- **Libation application:** Open issue at rmcrackan/Libation
- **KasmVNC base image:** Check linuxserver.io documentation

---

**Last Updated:** 2026-01-06
**Document Version:** 2.1.0
**Repository Version:** Libation 13.1.1
