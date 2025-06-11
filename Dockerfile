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

COPY configs/menu.xml /defaults/menu.xml
COPY configs/appsettings.json /config/Libation/appsettings.json
COPY configs/Settings.json /config/Libation/Settings.json


# Step 2: Create the autostart file
# RUN echo '#!/bin/bash\n\
# # Find Libation executable and run it\n\
# if [ -f /usr/bin/libation ]; then\n\
#   /usr/bin/libation\n\
# elif [ -f /usr/share/libation/Libation ]; then\n\
#   /usr/share/libation/Libation\n\
# else\n\
#   echo "ERROR: Cannot find Libation executable"\n\
# fi' > /defaults/autostart && \
#     chmod +x /defaults/autostart

# # Step 3: Create the Openbox menu file
# RUN echo '<?xml version="1.0" encoding="utf-8"?>\n\
# <openbox_menu xmlns="http://openbox.org/3.4/menu">\n\
# <menu id="root-menu" label="MENU">\n\
# <item label="xterm" icon="/usr/share/pixmaps/xterm-color_48x48.xpm"><action name="Execute"><command>/usr/bin/xterm</command></action></item>\n\
# <item label="Libation" icon="/usr/share/icons/hicolor/scalable/apps/libation.svg"><action name="Execute"><command>/usr/bin/libation</command></action></item>\n\
# </menu>\n\
# </openbox_menu>' > /defaults/menu.xml

# # Step 4: Create the appsettings.json file
# RUN echo '{\n\
#     "LibationFiles": "/config/Libation"\n\
#   }' > /config/Libation/appsettings.json

# # Step 5: Create the Settings.json file
# RUN echo '{\n\
#   "Books": "/config/Books",\n\
#   "InProgress": "/config/Libation/tmp",\n\
#   "ThemeVariant": "Dark",\n\
#   "Serilog": {\n\
#     "MinimumLevel": "Information",\n\
#     "WriteTo": [\n\
#       {\n\
#         "Name": "ZipFile",\n\
#         "Args": {\n\
#           "path": "/config/Libation/logs/_Log.log",\n\
#           "rollingInterval": "Month",\n\
#           "outputTemplate": "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] (at {Caller}) {Message:lj}{NewLine}{Exception} {Properties:j}"\n\
#         }\n\
#       }\n\
#     ],\n\
#     "Using": [\n\
#       "Dinah.Core",\n\
#       "Serilog.Exceptions"\n\
#     ],\n\
#     "Enrich": [\n\
#       "WithCaller",\n\
#       "WithExceptionDetails"\n\
#     ]\n\
#   },\n\
#   "MessageBoxWindow": {\n\
#     "X": 532,\n\
#     "Y": 294,\n\
#     "Height": 110,\n\
#     "Width": 269,\n\
#     "IsMaximized": false\n\
#   },\n\
#   "FirstLaunch": true,\n\
#   "AutoScan": true,\n\
#   "SettingsDialog": {\n\
#     "X": 414,\n\
#     "Y": 83,\n\
#     "Height": 750,\n\
#     "Width": 900,\n\
#     "IsMaximized": false\n\
#   },\n\
#   "MainWindow": {\n\
#     "X": 43,\n\
#     "Y": 76,\n\
#     "Height": 698,\n\
#     "Width": 1159,\n\
#     "IsMaximized": true\n\
#   }\n\
# }' > /config/Libation/Settings.json

# Step 6: Install dependencies and set up libation

# RUN echo fs.inotify.max_user_instances=524288 | tee -a /etc/sysctl.conf && \
#     # Install dependencies including PyXDG for openbox-xdg-autostart
#     apt-get update && \
#     apt-get install -y --no-install-recommends \
#     libgtk-3-0 \
#     python3-xdg && \
#     # Determine architecture for the package
#     ARCH=$(dpkg --print-architecture) && \
#     echo "Building for architecture: $ARCH" && \
#     # Download the correct package for the architecture
#     curl -fSL "https://github.com/rmcrackan/Libation/releases/download/v${GIT_TAG}/Libation.${GIT_TAG}-linux-chardonnay-${ARCH}.deb" -o libation.deb && \
#     # Install the package
#     dpkg -i libation.deb || apt-get install -f -y && \
#     # Make sure libation is in PATH
#     which libation || echo "WARNING: libation not found in PATH" && \
#     # Create symbolic link if needed
#     if [ ! -f /usr/bin/libation ] && [ -f /usr/share/libation/Libation ]; then \
#         ln -s /usr/share/libation/Libation /usr/bin/libation; \
#     fi && \
#     # Download icon
#     curl -fSL https://raw.githubusercontent.com/rmcrackan/Libation/master/Source/LoadByOS/LinuxConfigApp/libation_glass.svg --output /usr/share/icons/hicolor/scalable/apps/libation.svg && \
#     # Set permissions
#     chown -R ${PUID}:${PGID} /config/Libation /config/Books && \
#     # Create symlink for Books folder
#     ln -s /config/Books /home/kasm-user/ && \
#     # Clean up
#     rm -rf /var/lib/apt/lists/* && \
#     rm -f libation.deb

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
