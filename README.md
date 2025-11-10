# Spotify Multiroom Audio System

This project sets up a multiroom audio system using Spotify Connect (via librespot) and Snapcast.

## Overview

The system consists of:
- **Librespot**: A Spotify Connect client that appears as a Spotify device
- **Snapcast**: A multiroom audio server that streams audio to multiple clients
- **Avahi**: mDNS service for automatic network discovery

### Step 1: Install Base Dependencies

```bash
sudo apt-get update
sudo apt-get install -y \
    curl \
    gnupg \
    apt-transport-https \
    ca-certificates \
    lsb-release \
    procps \
    avahi-daemon \
    avahi-utils \
    libnss-mdns
```

### Step 2: Install Raspotify (Librespot)

```bash
# Add the raspotify repository key
curl -sSL https://dtcooper.github.io/raspotify/key.asc | sudo tee /usr/share/keyrings/raspotify-archive-keyrings.asc >/dev/null

# Add the repository
echo 'deb [signed-by=/usr/share/keyrings/raspotify-archive-keyrings.asc] https://dtcooper.github.io/raspotify raspotify main' | sudo tee /etc/apt/sources.list.d/raspotify.list

# Update and install
sudo apt-get update
sudo apt-get install -y raspotify
```

### Step 3: Install Snapcast Server

```bash
sudo apt-get install -y snapserver
```

### Step 4: Configure Snapserver

Create the snapserver configuration file. You can use the minimal configuration below, or copy the more detailed `snapserver.conf` file from this repository:

**Minimal configuration (matches Docker setup):**

```bash
sudo mkdir -p /etc/snapserver

sudo tee /etc/snapserver/snapserver.conf > /dev/null <<EOF
[stream]
source = pipe:///tmp/snapfifo?name=Spotify&sampleformat=44100:16:2&buffer=2000

[http]
doc_root = /usr/share/snapserver/snapweb
EOF
```

**Or use the detailed configuration from the repository:**

```bash
sudo cp snapserver.conf /etc/snapserver/snapserver.conf
```

Key configuration settings:
- **source**: Named pipe at `/tmp/snapfifo` where librespot writes audio
- **sampleformat**: 44100 Hz, 16-bit, stereo
- **buffer**: 2000ms buffer for network sync
- **port**: 1704 (default Snapcast port)

### Step 5: Create Avahi Service File

Enable mDNS discovery for Snapcast:

```bash
sudo tee /etc/avahi/services/snapserver.service > /dev/null <<EOF
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">Snapcast on %h</name>
  <service>
    <type>_snapcast._tcp</type>
    <port>1704</port>
  </service>
</service-group>
EOF
```

### Step 6: Disable Raspotify Systemd Service

We'll run librespot manually, so disable the default service:

```bash
sudo systemctl disable raspotify
sudo systemctl stop raspotify
```

### Step 7: Create the Named Pipe

```bash
# Create the FIFO pipe
sudo mkfifo /tmp/snapfifo
sudo chmod 666 /tmp/snapfifo
```

### Step 8: Create a Startup Script

```bash
sudo tee /usr/local/bin/spotify-multiroom.sh > /dev/null <<'EOF'
#!/bin/bash

# Ensure the FIFO exists
if [ ! -p /tmp/snapfifo ]; then
    mkfifo /tmp/snapfifo
    chmod 666 /tmp/snapfifo
fi

# Start librespot in the background
librespot --backend pipe --device /tmp/snapfifo --name "Spotify Multiroom" &

# Wait a moment for librespot to initialize
sleep 2

# Start snapserver in the foreground
snapserver -c /etc/snapserver/snapserver.conf
EOF

sudo chmod +x /usr/local/bin/spotify-multiroom.sh
```

### Step 9: Create a Systemd Service

Make the service start automatically on boot:

```bash
sudo tee /etc/systemd/system/spotify-multiroom.service > /dev/null <<EOF
[Unit]
Description=Spotify Multiroom Audio System
After=network.target avahi-daemon.service
Requires=avahi-daemon.service

[Service]
Type=simple
ExecStart=/usr/local/bin/spotify-multiroom.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable spotify-multiroom.service
sudo systemctl start spotify-multiroom.service
```

### Step 10: Verify Everything is Running

```bash
# Check if Avahi is running
sudo systemctl status avahi-daemon

# Check if your service is running
sudo systemctl status spotify-multiroom

# Check if snapserver is listening
sudo netstat -tlnp | grep snapserver
```

### Access the Web Interface

Once running, you can access the Snapcast web interface at:

```
http://your-debian-ip:1780
```

---

## Troubleshooting

### Service won't start
```bash
# Check the logs
sudo journalctl -u spotify-multiroom -f
```

### No audio output
- Verify the named pipe exists: `ls -la /tmp/snapfifo`
- Check if librespot is writing to the pipe
- Ensure snapserver is reading from the pipe

### Can't find the Spotify device
- Ensure Avahi is running: `sudo systemctl status avahi-daemon`
- Check if the device appears in your Spotify app's device list
- The device name is "Spotify Multiroom"

### Web interface not accessible
- Verify snapserver is listening on port 1780: `sudo netstat -tlnp | grep 1780`
- Check firewall rules if accessing from another machine

## Snapcast Clients

To play audio on other devices, install Snapcast clients:

```bash
sudo apt-get install snapclient
```

Configure each client to connect to your server's IP address.

## License

This project is open source. See the repository for license details.
