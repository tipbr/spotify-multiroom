FROM debian:bullseye-slim

# Install necessary tools and dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    apt-transport-https \
    ca-certificates \
    systemd \
    lsb-release \
    procps \
    avahi-daemon \
    avahi-utils \
    libnss-mdns \
    && rm -rf /var/lib/apt/lists/*

# Install raspotify (which includes librespot) with the correct repository approach
RUN curl -sSL https://dtcooper.github.io/raspotify/key.asc | tee /usr/share/keyrings/raspotify-archive-keyrings.asc >/dev/null \
    && echo 'deb [signed-by=/usr/share/keyrings/raspotify-archive-keyrings.asc] https://dtcooper.github.io/raspotify raspotify main' | tee /etc/apt/sources.list.d/raspotify.list \
    && apt-get update \
    && apt-get install -y raspotify \
    && rm -rf /var/lib/apt/lists/*

# Install snapcast server
RUN apt-get update && apt-get install -y \
    snapserver \
    && rm -rf /var/lib/apt/lists/*

# Create directory for snapcast config
RUN mkdir -p /etc/snapserver

# Create a simple snapserver config
RUN echo '[stream]' > /etc/snapserver/snapserver.conf \
    && echo 'source = pipe:///tmp/snapfifo?name=Spotify&sampleformat=44100:16:2&buffer=2000' >> /etc/snapserver/snapserver.conf \
    && echo '[http]' >> /etc/snapserver/snapserver.conf \
    && echo 'doc_root = /usr/share/snapserver/snapweb' >> /etc/snapserver/snapserver.conf

# Enable Avahi service for snapcast
COPY snapserver.service /etc/avahi/services/snapserver.service

# Create startup script with Avahi
RUN echo '#!/bin/bash' > /start.sh \
    && echo 'mkdir -p /tmp' >> /start.sh \
    && echo 'mkfifo -m a=rw /tmp/snapfifo' >> /start.sh \
    && echo 'systemctl disable raspotify' >> /start.sh \
    && echo '# Start Avahi daemon' >> /start.sh \
    && echo 'avahi-daemon --daemonize' >> /start.sh \
    && echo '# Start librespot' >> /start.sh \
    && echo 'librespot --backend pipe --device /tmp/snapfifo --name "Spotify Multiroom" &' >> /start.sh \
    && echo '# Start snapserver' >> /start.sh \
    && echo 'snapserver -c /etc/snapserver/snapserver.conf' >> /start.sh \
    && chmod +x /start.sh

# Expose the snapcast server ports
EXPOSE 1704 1705 1780
# Expose Avahi mDNS port
EXPOSE 5353/udp

# Use init system to handle processes
ENTRYPOINT ["/start.sh"]
