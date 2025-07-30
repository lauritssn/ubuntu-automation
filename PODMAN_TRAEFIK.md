# Traefik with Podman

This document explains how to run Traefik with Podman using socket activation for optimal performance and real IP forwarding.

## Socket Activation Benefits

Socket activation preserves real client IP addresses without NAT layer, meaning applications see true user IPs in logs. This is optimal for Traefik to log real user IP addresses.

## Prerequisites

- Podman installed with rootless configuration
- Socket activation configured (done automatically by podman_install.sh)
- Networking configured for real IP forwarding

## Socket Activation Setup

### Using the Helper Script

The installation provides a socket setup helper script:

```bash
sudo su - podman
~/.config/containers/socket-setup.sh traefik 80 443
```

This creates a systemd socket unit for Traefik that listens on ports 80 and 443.

### Manual Socket Unit Creation

Create a socket unit file at `~/.config/systemd/user/traefik.socket`:

```ini
[Unit]
Description=traefik socket
Requires=traefik.service

[Socket]
ListenStream=0.0.0.0:80
ListenStream=0.0.0.0:443

[Install]
WantedBy=sockets.target
```

## Container Configuration

Create a Traefik container unit file at `~/.config/containers/systemd/traefik.container`:

```ini
[Unit]
Description=Traefik Reverse Proxy
After=network-online.target
Wants=network-online.target

[Container]
Image=traefik:latest
PublishPort=80:80
PublishPort=443:443
PublishPort=8080:8080
Volume=/home/podman/traefik:/etc/traefik:Z
Volume=/var/run/docker.sock:/var/run/docker.sock:ro
PodmanArgs=--log-driver=journald

[Service]
Restart=always
TimeoutStartSec=60
TimeoutStopSec=30

[Install]
WantedBy=default.target
```

## Managing Socket-Activated Traefik

### Enable and Start Socket

```bash
sudo su - podman
systemctl --user daemon-reload
systemctl --user enable traefik.socket
systemctl --user start traefik.socket
```

### Check Status

```bash
# Check socket status
podman-socket status traefik

# Start socket service
podman-socket start traefik-http

# View service logs
podman-socket logs traefik
```

### Using podman-user wrapper

```bash
# Run Traefik container directly
podman-user run -d --name traefik -p 80:80 -p 443:443 traefik

# Generate systemd unit
podman-user generate systemd --new --files --name traefik
```

## Network Configuration

The Podman installation configures networking for real IP forwarding:

- IPv4 forwarding enabled in sysctl
- IPv6 forwarding enabled in sysctl
- Netavark backend for better networking
- Socket activation preserves original client IPs

## Container Configuration Files

Key configuration files for optimal Traefik operation:

- **Containers config**: `/home/podman/.config/containers/containers.conf`
- **Storage config**: `/home/podman/.config/containers/storage.conf`
- **Socket setup script**: `/home/podman/.config/containers/socket-setup.sh`
- **Systemd user units**: `/home/podman/.config/systemd/user/`
- **Container units**: `/home/podman/.config/containers/systemd/`

## Real IP Forwarding

When using socket activation, containers receive direct connections which preserves the original client IP addresses. This configuration is optimal for Traefik logging and access control.

The containers.conf includes specific settings for socket activation:

```ini
[network]
# Socket activation preserves original client IPs without NAT
default_network = "netavark"
enable_ipv6 = true

[engine]
# Socket activation configuration
service_timeout = 0
stop_timeout = 10
```

## Management Commands

- Switch to podman user: `sudo su - podman`
- Run commands as podman user: `podman-user <command>`
- Check status: `podman-status`
- Manage socket services: `podman-socket <command>`
- Test installation: `podman-user run --rm hello-world`

## Example Setup Process

1. Switch to podman user:
   ```bash
   sudo su - podman
   ```

2. Create socket for Traefik:
   ```bash
   ~/.config/containers/socket-setup.sh traefik 80 443
   ```

3. Create your Traefik container configuration in `~/.config/containers/systemd/traefik.container`

4. Enable and start the socket:
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable traefik.socket
   systemctl --user start traefik.socket
   ```

5. Verify the setup:
   ```bash
   systemctl --user status traefik.socket
   podman-socket status traefik
   ```

## Troubleshooting

If you encounter issues:

1. Check socket status: `systemctl --user status traefik.socket`
2. Check container logs: `podman-socket logs traefik`
3. Verify socket connectivity: `podman system connection list`
4. Test basic functionality: `podman-user version`
5. Use the fix script if needed: `./utils/podman_fix.sh`