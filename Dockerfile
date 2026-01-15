# syntax=docker/dockerfile:1-labs

# This Dockerfile is optimized for fast builds and minimal image size
# - Layer caching optimized (config changes don't invalidate Libation install)
# - Split RUN commands for better debugging and caching
# - BuildKit cache mounts for faster apt operations
# - Aggressive cleanup for ~150MB size reduction

# renovate: datasource=github-releases depName=rmcrackan/Libation extractVersion=^v?(?<version>.*)$
ARG LIBATION_VERSION=13.1.3

FROM lsiobase/kasmvnc:debianbookworm

ARG LIBATION_VERSION
ARG TARGETARCH

ENV PUID=${PUID:-1000} \
    PGID=${PGID:-1000} \
    LIBATION_VERSION=${LIBATION_VERSION}

# Create all necessary directories
RUN mkdir -p /defaults \
    /config/Libation \
    /config/Books \
    /config/Libation/logs \
    /config/Libation/tmp

# Configure system settings
RUN echo fs.inotify.max_user_instances=524288 | tee -a /etc/sysctl.conf

# Install system dependencies with BuildKit cache mount
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -eux; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libgtk-3-0 \
        python3-xdg \
        ca-certificates \
        curl

# Download and install Libation
RUN set -eux; \
    ARCH=$(dpkg --print-architecture); \
    echo "Building for architecture: $ARCH"; \
    curl -fSL "https://github.com/rmcrackan/Libation/releases/download/v${LIBATION_VERSION}/Libation.${LIBATION_VERSION}-linux-chardonnay-${ARCH}.deb" -o /tmp/libation.deb; \
    dpkg -i /tmp/libation.deb || apt-get install -f -y; \
    rm /tmp/libation.deb

# Post-install configuration
RUN set -eux; \
    # Ensure libation is in PATH
    if [ ! -f /usr/bin/libation ] && [ -f /usr/share/libation/Libation ]; then \
        ln -s /usr/share/libation/Libation /usr/bin/libation; \
    fi; \
    which libation || echo "WARNING: libation not found in PATH"

# Download application icon
RUN curl -fSL https://raw.githubusercontent.com/rmcrackan/Libation/master/Source/LoadByOS/LinuxConfigApp/libation_glass.svg \
    --output /usr/share/icons/hicolor/scalable/apps/libation.svg

# AGGRESSIVE CLEANUP in separate layer for clarity (saves ~100-150MB)
RUN set -eux; \
    # Remove curl (no longer needed)
    apt-get purge -y --auto-remove curl; \
    apt-get clean; \
    # Remove temporary files
    rm -rf /tmp/* \
           /var/tmp/* \
           /var/lib/apt/lists/* \
           /var/cache/debconf/*; \
    # Remove documentation and man pages (~20MB)
    rm -rf /usr/share/doc/* \
           /usr/share/man/*; \
    # Remove localization files (~30MB, keep only en_US)
    find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' -exec rm -rf {} + 2>/dev/null || true; \
    # Remove log files
    rm -rf /var/log/*; \
    # Remove .NET debug symbols (.pdb files) (~40-50MB)
    find /usr -type f -name '*.pdb' -delete 2>/dev/null || true; \
    find /usr/share/libation -type f -name '*.pdb' -delete 2>/dev/null || true; \
    # Remove .NET XML documentation (~10MB)
    find /usr/share/libation -type f -name '*.xml' -delete 2>/dev/null || true

# Copy config files AFTER expensive operations
# Changes to these files won't invalidate earlier layers
COPY configs/autostart /defaults/autostart
RUN chmod +x /defaults/autostart

COPY configs/menu.xml /defaults/menu.xml
COPY configs/appsettings.json /config/Libation/appsettings.json
COPY configs/Settings.json /config/Libation/Settings.json

# Set final permissions and create symlinks
RUN chown -R ${PUID}:${PGID} /config/Libation /config/Books && \
    ln -s /config/Books /home/kasm-user/

# Expose KasmVNC port
EXPOSE 3000
