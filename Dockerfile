# syntax=docker/dockerfile:1-labs

# This Dockerfile is designed to build a KasmVNC container for the Libation application.
# Libation is a book management application that allows users to organize and track their reading.
# The container is based on the lsiobase/kasmvnc:debianbookworm image, which provides a lightweight VNC server environment.
# The Dockerfile sets up the necessary directories, configuration files, and dependencies for Libation.
# It also includes a custom autostart script and Openbox menu configuration.
# The container is configured to run Libation with a default user and group ID, which can be overridden by environment variables.
# The Libation application is downloaded from its GitHub releases page, and the appropriate version is installed based on the specified GIT_TAG.
# The container exposes port 3000 for KasmVNC access.

# Step 1: Get base image 
ARG GIT_TAG=${GIT_TAG:-12.4.0}
FROM lsiobase/kasmvnc:debianbookworm

ARG GIT_TAG
ARG TARGETARCH

ENV PUID=${PUID:-1000} \
    PGID=${PGID:-1000} \
    GIT_TAG=${GIT_TAG}

# Step 2: Create all necessary directories
RUN mkdir -p /defaults \
    /config/Libation \
    /config/Books \
    /config/Libation/logs \
    /config/Libation/tmp

# Step 3: Copy static config files
COPY configs/autostart /defaults/autostart
RUN chmod +x /defaults/autostart

# Copy Openbox menu configuration
COPY configs/menu.xml /defaults/menu.xml
# Copy default settings and configuration files
COPY configs/appsettings.json /config/Libation/appsettings.json
COPY configs/Settings.json /config/Libation/Settings.json


# Step 4: Install dependencies and set up libation
RUN set -eux; \
    echo fs.inotify.max_user_instances=524288 | tee -a /etc/sysctl.conf; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libgtk-3-0 \
        python3-xdg \
        ca-certificates \
        curl; \
    # Determine architecture for the package
        ARCH=$(dpkg --print-architecture); \
    echo "Building for architecture: $ARCH"; \
    # Download the correct package for the architecture
    curl -fSL "https://github.com/rmcrackan/Libation/releases/download/v${GIT_TAG}/Libation.${GIT_TAG}-linux-chardonnay-${ARCH}.deb" -o libation.deb; \
    dpkg -i libation.deb || apt-get install -f -y; \
    # Make sure libation is in PATH
    which libation || echo "WARNING: libation not found in PATH"; \
    if [ ! -f /usr/bin/libation ] && [ -f /usr/share/libation/Libation ]; then \
        ln -s /usr/share/libation/Libation /usr/bin/libation; \
    fi; \
    # Download icon
    curl -fSL https://raw.githubusercontent.com/rmcrackan/Libation/master/Source/LoadByOS/LinuxConfigApp/libation_glass.svg --output /usr/share/icons/hicolor/scalable/apps/libation.svg; \
    # Set permissions
    chown -R ${PUID}:${PGID} /config/Libation /config/Books; \
    # Create symlink for Books folder
    ln -s /config/Books /home/kasm-user/; \
    # Clean up
    apt-get purge -y --auto-remove curl; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* libation.deb

# Expose KasmVNC port
EXPOSE 3000
