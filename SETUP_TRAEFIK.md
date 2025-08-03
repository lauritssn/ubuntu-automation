# Traefik Setup with Podman Socket Activation

This comprehensive guide explains how to set up Traefik with Podman using socket activation for optimal performance, real IP forwarding, and enhanced security.

## Socket Activation Benefits

Socket activation preserves real client IP addresses without NAT layer, meaning applications see true user IPs in logs. This approach provides:

- ✅ **Real client IP addresses preserved** - No NAT layer between client and Traefik
- ✅ **Enhanced security** - Containers can run with `--network=none`
- ✅ **Automatic container startup** - Services start on demand when connections arrive
- ✅ **Native network performance** - No slirp4netns overhead for socket connections
- ✅ **Better resource efficiency** - Containers only run when needed

## Prerequisites

- Ubuntu server with Podman installed via the `podman_install.sh` script
- A dedicated `podman` user created during installation
- Socket activation configured (done automatically by podman_install.sh)
- IPv4 and IPv6 forwarding enabled in sysctl
- Domain name(s) pointing to your server
- Ports 80, 443, and 8080 accessible from the internet

## Step 1: Verify Podman Installation

Switch to the podman user and verify the environment:

```bash
sudo su - podman
```

Verify your environment:

```bash
echo $XDG_RUNTIME_DIR
# Should output: /run/user/[podman-user-id]

podman version
# Should display Podman version without errors

# Check if helper scripts are available
ls /srv/apps/scripts/socket-setup.sh
# Should exist and be executable
```

## Step 2: Prepare Traefik Configuration

Create the deployment directory and copy the traefik configuration:

```bash
# As root user, configure the deployment directory structure
sudo chown -R podman:podman /srv/apps/deploy
```

Switch to podman user and prepare configuration:

> **Note:** The included `traefik.yml` configuration is already optimized for socket activation with proper forwarded headers, trusted IPs, security middlewares, and Let's Encrypt certificate resolution. No additional configuration changes are needed.

```bash
sudo su - podman

# Change dir
cd /srv/apps/deploy/

# Clone WTools
git clone WTools

# Change dir to traefik
cd /srv/apps/deploy/WTools/traefik

# Set up the environment file
cp env.template .env

# Edit .env file with your domain and email
vi .env
# Update these key values:
# APP_DOMAIN=your-app.domain.com
# LETSENCRYPT_EMAIL=your-email@domain.com
# TRAEFIK_DASHBOARD_DOMAIN=traefik.yourdomain.com
# XDG_RUNTIME_DIR=/run/user/$(id -u podman)

# Ensure the ACME file has correct permissions
touch data/acme.json
chmod 600 data/acme.json

# Check that all required files are present
ls -la /srv/apps/deploy/WTools/traefik/
# Should show: docker-compose.prod.yml, .env, data/, traefik.yml, etc.
```

## Step 3: Create Socket Configuration

### Option A: Using the Helper Script (Recommended)

The Podman installation includes a helper script for easy socket creation:

```bash
# As podman user, create socket for HTTP, HTTPS, and dashboard ports
/srv/apps/scripts/socket-setup.sh traefik 80 443 8080
```

This automatically creates a socket unit file with IPv4 and IPv6 listeners for all three ports.

The script provides comprehensive validation:
- Service name format (alphanumeric, hyphens, underscores only)
- Port number ranges (1-65535)
- Proper user execution (must be run as podman user)
- Automatic IPv4 and IPv6 dual-stack configuration

### Option B: Manual Socket Creation

Create the systemd user directory structure:

```bash
mkdir -p ~/.config/systemd/user
mkdir -p ~/.config/containers/systemd
```

Create a single socket file with multiple listeners:

```bash
cat > ~/.config/systemd/user/traefik.socket << 'EOF'
[Unit]
Description=Traefik socket
Requires=traefik.service

[Socket]
ListenStream=0.0.0.0:80
ListenStream=[::]:80
ListenStream=0.0.0.0:443
ListenStream=[::]:443
ListenStream=0.0.0.0:8080
ListenStream=[::]:8080

[Install]
WantedBy=sockets.target
EOF
```

## Step 4: Create Container Configuration

### Method A: Using Docker Compose (if podman-compose available)

Create a systemd service that runs your docker-compose.prod.yml:

```bash
cat > ~/.config/containers/systemd/traefik.container << 'EOF'
[Unit]
Description=Traefik reverse proxy using docker-compose
Requires=traefik.socket
After=traefik.socket

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=/srv/apps/deploy/WTools/traefik
ExecStart=/usr/bin/podman-compose -f /srv/apps/deploy/WTools/traefik/docker-compose.prod.yml up -d
ExecStop=/usr/bin/podman-compose -f /srv/apps/deploy/WTools/traefik/docker-compose.prod.yml down
TimeoutStartSec=60
TimeoutStopSec=30

[Install]
WantedBy=default.target
EOF
```

## Step 5: Create Traefik Network

Create the Traefik network for container communication:

```bash
podman network create traefik
```

## Step 6: Enable and Start Services

Reload systemd configuration:

```bash
systemctl --user daemon-reload
```

Enable socket activation (containers start on first connection):

```bash
systemctl --user enable traefik.socket
systemctl --user enable traefik.service
```

Start the socket listeners:

```bash
systemctl --user start traefik.socket
```

## Step 7: Enable User Lingering

To ensure services start at boot and persist after logout:

```bash
# As root user:
sudo loginctl enable-linger podman
```

## Step 8: Verify Installation

Check socket status:

```bash
# As podman user
systemctl --user status traefik.socket
systemctl --user list-sockets

# Test HTTP access (this will trigger container startup)
curl -H "Host: your-domain.com" http://localhost

# Check if Traefik container started
podman ps

# Access the dashboard
curl http://localhost:8080/api/overview
```

## Step 9: Deploy Additional Services

Create a test service using Quadlet. Create `~/.config/containers/systemd/hello-world.container`:

```bash
cat > ~/.config/containers/systemd/hello-world.container << 'EOF'
[Unit]
Description=Hello World test service
After=traefik.service

[Container]
Image=docker.io/traefik/whoami
ContainerName=hello-world-prod
Network=traefik
Label=traefik.enable=true
Label=traefik.http.routers.hello.rule=Host(`hello.your-domain.com`)
Label=traefik.http.routers.hello.entrypoints=web,websecure
Label=traefik.http.routers.hello.tls.certresolver=letsencrypt
Label=traefik.http.services.hello.loadbalancer.server.port=80

[Install]
WantedBy=default.target
EOF
```

Reload and start:

```bash
systemctl --user daemon-reload
systemctl --user enable --now hello-world.service
```

## Management Commands

### Using Pre-installed Helper Scripts

The Podman installation provides these management tools:

```bash
# Check overall Podman status
sudo podman-status

# Check socket services
sudo podman-socket list
sudo podman-socket status traefik

# View logs
sudo podman-socket logs traefik

# Restart services
sudo podman-socket restart traefik

# Run commands as podman user
sudo podman-user ps -a
sudo podman-user logs traefik-prod
```

### Direct systemctl Management

```bash
# As podman user
sudo su - podman

# Check socket status
systemctl --user status traefik.socket

# View service logs
journalctl --user -u traefik.service -f

# Restart socket
systemctl --user restart traefik.socket

# Check all user services
systemctl --user list-units --type=service
```

## Network Configuration Details

The Podman installation automatically configures networking for real IP forwarding:

- **IPv4 forwarding** enabled in sysctl (`net.ipv4.ip_forward=1`)
- **IPv6 forwarding** enabled in sysctl (`net.ipv6.conf.all.forwarding=1`)
- **Netavark backend** for better networking performance
- **Socket activation** preserves original client IPs without NAT

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

## Security Benefits

With socket activation and proper configuration:

- ✅ **Real client IP addresses preserved** in logs
- ✅ **No network access for compromised containers** (when using `--network=none`)
- ✅ **Automatic container startup** on connection
- ✅ **Reduced attack surface** through privilege limitation
- ✅ **No port mapping complexity** - systemd handles network binding

## Troubleshooting

### Container Not Starting

```bash
# Check socket status
systemctl --user status traefik.socket

# Check service logs
journalctl --user -u traefik.service -f

# Manually start service for debugging
systemctl --user start traefik.service

# Check systemd socket files
ls -la ~/.config/systemd/user/traefik*
```

### Permission Issues

```bash
# Fix ownership
sudo chown -R podman:podman /srv/apps/deploy
chmod 600 /srv/apps/deploy/WTools/traefik/data/acme.json

# Check podman user environment
sudo su - podman -c 'echo $XDG_RUNTIME_DIR'
```

### Socket Binding Issues

```bash
# Check if ports are already in use
sudo netstat -tlnp | grep -E ':(80|443|8080)'

# Verify socket connectivity
sudo -u podman podman system connection list
```

### Network Issues

```bash
# Recreate Traefik network
podman network rm traefik
podman network create traefik

# Check IPv6 support
ip -6 addr show
```

### Docker Compose Conflicts

If using docker-compose.prod.yml with socket activation:

1. **Remove or comment out** the `ports:` sections in docker-compose.prod.yml
2. Socket activation handles port binding, so explicit port mapping conflicts
3. Use environment variables instead of port mappings

## File Locations Reference

### Configuration Files Created During Setup

- Socket unit: `~/.config/systemd/user/traefik.socket`
- Container unit: `~/.config/containers/systemd/traefik.container`
- Traefik config: `/srv/apps/deploy/WTools/traefik/traefik.yml`
- Environment: `/srv/apps/deploy/WTools/traefik/.env`
- ACME data: `/srv/apps/deploy/WTools/traefik/data/acme.json`
- Docker Compose: `/srv/apps/deploy/WTools/traefik/docker-compose.prod.yml`
- Convenience symlink: `/home/podman/traefik -> /srv/apps/deploy/WTools/traefik`

### Pre-installed Helper Files (from podman_install.sh)

- Socket setup script: `/srv/apps/scripts/socket-setup.sh`
- Example documentation: `~/.config/containers/traefik-example.md`
- Container config: `~/.config/containers/containers.conf`
- Storage config: `~/.config/containers/storage.conf`
- Runtime socket: `$XDG_RUNTIME_DIR/podman/podman.sock`

### System Management Scripts

- Podman user wrapper: `/usr/local/bin/podman-user`
- Status checker: `/usr/local/bin/podman-status`
- Socket manager: `/usr/local/bin/podman-socket`

## Summary

This setup provides a production-ready Traefik instance with:

- **Socket activation** for real IP preservation and enhanced security
- **IPv4 and IPv6 support** for modern networking requirements
- **Automatic container startup** on demand
- **Comprehensive management tools** for monitoring and maintenance
- **Integration with existing docker-compose.prod.yml** configurations
- **Systemd integration** for proper service management

The configuration leverages all the infrastructure created by the `podman_install.sh` script while providing a robust, secure, and efficient Traefik deployment.
