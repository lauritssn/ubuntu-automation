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
- Updated `socket-setup.sh` script with Traefik support
- IPv4 and IPv6 forwarding enabled in sysctl
- Domain name(s) pointing to your server
- Ports 80, 443, and 8080 accessible from the internet

## Local Mac Development Setup

For local development on Mac with Podman, you can run Traefik directly without socket activation:

### Quick Start for Mac Development

```bash
# Clone the repository
git clone <your-repo> traefik-setup
cd traefik-setup/traefik

# Set up environment
cp env.template .env
# Edit .env with your preferences (defaults work for local development)

# Create network and start services
podman network create traefik
podman-compose -f docker-compose.dev.yml up -d

# Test the setup
curl http://localhost:8080/api/overview  # Traefik dashboard API
curl -H "Host: hello.localhost" http://localhost  # Hello world service
```

### Access Services (Mac Development)

- **Traefik Dashboard**: `http://localhost:8080`
- **Hello World Example**: Add `127.0.0.1 hello.localhost traefik.localhost` to `/etc/hosts`, then visit `http://hello.localhost`

---

## Production Server Setup (Ubuntu with Socket Activation)

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
sudo mkdir /srv/apps/deploy
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

### Option A: Using the Updated Helper Script (Recommended)

The updated Podman installation script now includes special handling for Traefik that creates a single optimized socket file with multiple entrypoints:

```bash
# As podman user, create Traefik socket file using the helper script
/srv/apps/scripts/socket-setup.sh traefik 80 443 8080
```

This automatically creates a single optimized socket file:

- `traefik.socket` - Single socket with multiple ListenStream entries for all ports
- Uses `FileDescriptorName=web` for optimal socket activation
- Includes `FreeBind=true` for enhanced reliability

The script provides:

- ✅ **Traefik-specific detection** - Automatically creates optimized single socket for Traefik
- ✅ **Multiple entrypoint support** - Single socket handles all ports (80, 443, 8080)
- ✅ **Optimal performance** - Uses `FileDescriptorName=web` for best socket activation
- ✅ **Enhanced reliability** - Includes `FreeBind=true` for robust socket binding
- ✅ **Comprehensive validation** - Validates service name and port ranges
- ✅ **Clear next-step instructions** - Shows exactly what to enable and start

**Important:** The single socket file approach is more efficient than separate sockets and provides optimal client IP preservation.

### Option B: Manual Socket Creation (Alternative)

If you prefer to create the socket file manually or need to customize it:

```bash
# As podman user, create single socket file for all Traefik entrypoints
mkdir -p ~/.config/systemd/user

# Single Traefik socket with multiple entrypoints
cat > ~/.config/systemd/user/traefik.socket << 'EOF'
[Unit]
Description=Traefik socket activation

[Socket]
ListenStream=0.0.0.0:80
ListenStream=0.0.0.0:443
ListenStream=0.0.0.0:8080
# FileDescriptorName=web
FreeBind=true

[Install]
WantedBy=sockets.target
EOF
```

## Step 4: Create Container Configuration

### Method A: Using Quadlet with Docker Compose (Recommended)

The traefik directory includes pre-configured Quadlet files that manage docker-compose deployments. This approach combines the simplicity of docker-compose with the power of systemd service management.

#### Copy Quadlet Configuration Files

```bash
# As podman user, copy the appropriate Quadlet configuration
# For Development:
cp /srv/apps/deploy/WTools/traefik/quadlet/traefik-dev.container ~/.config/containers/systemd/traefik.container

# For Production:
cp /srv/apps/deploy/WTools/traefik/quadlet/traefik-prod.container ~/.config/containers/systemd/traefik.container
```

The Quadlet configurations provide:

- ✅ **Automatic network creation** - Creates traefik network if it doesn't exist
- ✅ **Environment file integration** - Uses .env file for all configuration
- ✅ **Proper service dependencies** - Waits for socket activation
- ✅ **Health checking and restart policies** - Robust service management
- ✅ **Graceful shutdown** - Proper container lifecycle management

#### Key Features of the Quadlet Approach

- **Development Configuration** includes a hello world service example accessible at `http://hello.localhost`
- **Production Configuration** uses socket activation for optimal performance and client IP preservation
- **Development Configuration** uses direct port mapping for local Mac/development environments
- **Environment-driven** - All configuration comes from the `.env` file
- **Socket activation ready** - Production integrates seamlessly with systemd socket activation

### Method B: Using Pure Quadlet (Recommended)

#### Production Configuration (HTTPS + Let's Encrypt)

Create a pure Quadlet container configuration for production:

```bash
cat > ~/.config/containers/systemd/traefik.container << 'EOF'
[Unit]
Description=Traefik reverse proxy (Production)
After=traefik.socket
Requires=traefik.socket

[Container]
Image=docker.io/traefik:v3.5.0
ContainerName=traefik-prod
Network=traefik
SecurityLabelDisable=true
# NO PublishPort directives - socket activation handles port binding
Volume=/run/user/$UID/podman/podman.sock:/var/run/docker.sock:ro
Volume=/srv/apps/deploy/WTools/traefik/traefik.yml:/etc/traefik/traefik.yml:ro
Volume=/srv/apps/deploy/WTools/traefik/data:/data:Z
Volume=/srv/apps/deploy/WTools/traefik/dynamic/prod:/etc/traefik/dynamic:ro
EnvironmentFile=/srv/apps/deploy/WTools/traefik/.env
# Socket activation entrypoint configuration
Environment=TRAEFIK_ENTRYPOINTS_WEB_ADDRESS=:80
Environment=TRAEFIK_ENTRYPOINTS_WEBSECURE_ADDRESS=:443
Environment=TRAEFIK_ENTRYPOINTS_TRAEFIK_ADDRESS=:8080
# Forwarded headers for client IP preservation
Environment=TRAEFIK_ENTRYPOINTS_WEB_FORWARDEDHEADERS_TRUSTEDIPS=172.18.0.0/16,172.19.0.0/16,172.20.0.0/16,127.0.0.1/32,::1/128
Environment=TRAEFIK_ENTRYPOINTS_WEBSECURE_FORWARDEDHEADERS_TRUSTEDIPS=172.18.0.0/16,172.19.0.0/16,172.20.0.0/16,127.0.0.1/32,::1/128
Environment=TRAEFIK_ENTRYPOINTS_TRAEFIK_FORWARDEDHEADERS_TRUSTEDIPS=172.18.0.0/16,172.19.0.0/16,172.20.0.0/16,127.0.0.1/32,::1/128
# Docker provider configuration
Environment=TRAEFIK_PROVIDERS_DOCKER=true
Environment=TRAEFIK_PROVIDERS_DOCKER_EXPOSEDBYDEFAULT=false
Environment=TRAEFIK_PROVIDERS_DOCKER_NETWORK=traefik

[Service]
Restart=on-failure

[Install]
WantedBy=default.target
EOF
```

#### Development Configuration (HTTP-only)

Create a pure Quadlet container configuration for development:

```bash
cat > ~/.config/containers/systemd/traefik.container << 'EOF'
[Unit]
Description=Traefik reverse proxy (Development)
After=traefik.socket
Requires=traefik.socket

[Container]
Image=docker.io/traefik:v3.5.0
ContainerName=traefik-dev
Network=traefik
SecurityLabelDisable=true
# NO PublishPort directives - socket activation handles port binding
Volume=/run/user/$UID/podman/podman.sock:/var/run/docker.sock:ro
Volume=/srv/apps/deploy/WTools/traefik/traefik-dev.yml:/etc/traefik/traefik.yml:ro
Volume=/srv/apps/deploy/WTools/traefik/dynamic/dev:/etc/traefik/dynamic:ro
EnvironmentFile=/srv/apps/deploy/WTools/traefik/.env
# Development socket activation - HTTP only for simplicity
Environment=TRAEFIK_ENTRYPOINTS_WEB_ADDRESS=:80
Environment=TRAEFIK_ENTRYPOINTS_TRAEFIK_ADDRESS=:8080
Environment=TRAEFIK_LOG_LEVEL=DEBUG
# Docker provider configuration
Environment=TRAEFIK_PROVIDERS_DOCKER=true
Environment=TRAEFIK_PROVIDERS_DOCKER_EXPOSEDBYDEFAULT=false
Environment=TRAEFIK_PROVIDERS_DOCKER_NETWORK=traefik

[Service]
Restart=on-failure

[Install]
WantedBy=default.target
EOF
```

> **Development Note:** The development configuration uses direct port mapping for local development environments. It focuses on HTTP access to avoid SSL certificate complications. Access services via:
>
> - Dashboard: `http://traefik.localhost` or `http://localhost:8080`
> - Hello World Example: `http://hello.localhost`
> - Services: `http://servicename.localhost` (e.g., `http://monitor.localhost`)

### Choosing Between Production and Development

- **Production**: Use when deploying to an Ubuntu server with socket activation, real domain and HTTPS requirements
- **Development**: Use for local Mac/Linux development with direct port mapping and `.localhost` domains

Production uses socket activation for real client IP preservation and enhanced security. Development uses traditional port mapping for simplicity on local development machines and includes a hello world example service for testing Traefik routing.

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

Enable socket activation for all entrypoints (containers start on first connection):

```bash
systemctl --user enable traefik.socket
```

**Note:** Do NOT try to enable `traefik.service` - it will be automatically generated and managed by the socket activation system.

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

# For development, test the hello world service
curl -H "Host: hello.localhost" http://localhost

# Check if Traefik container started
podman ps

# Access the dashboard
curl http://localhost:8080/api/overview

# Development: Access hello world service
curl http://hello.localhost
```

### Development Environment Testing

The development configuration includes a hello world service that demonstrates Traefik routing:

```bash
# Test the hello world service
curl -H "Host: hello.localhost" http://localhost

# Or if using a browser, add to /etc/hosts:
echo "127.0.0.1 hello.localhost traefik.localhost" | sudo tee -a /etc/hosts

# Then access:
# http://hello.localhost - Hello world service
# http://traefik.localhost - Traefik dashboard (or use :8080)
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
sudo podman-socket status web
sudo podman-socket status websecure
sudo podman-socket status traefik

# View logs
sudo podman-socket logs traefik

# Restart services
sudo podman-socket restart web
sudo podman-socket restart websecure
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

# Restart sockets
systemctl --user restart traefik.socket

# Check all user services
systemctl --user list-units --type=service
```

## Network Configuration Details

The Podman installation automatically configures networking for real IP forwarding:

- **IPv4 forwarding** enabled in sysctl (`net.ipv4.ip_forward=1`)
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
ls -la ~/.config/systemd/user/traefik.socket
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

### Socket Activation Errors

If you see errors like "Socket activation TCP listeners must have one and only one listener per name":

1. **Remove old combined socket file** (if it exists):

   ```bash
   rm ~/.config/systemd/user/traefik.socket
   ```

2. **Create separate socket files** as shown in Option A above

3. **Reload systemd and restart**:
   ```bash
   systemctl --user daemon-reload
   systemctl --user stop traefik.service traefik.socket
   systemctl --user start traefik.socket
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

- Socket units: `~/.config/systemd/user/traefik.socket`
- Container unit: `~/.config/containers/systemd/traefik.container`
- Traefik config: `/srv/apps/deploy/WTools/traefik/traefik.yml` (production)
- Traefik dev config: `/srv/apps/deploy/WTools/traefik/traefik-dev.yml` (development)
- Environment: `/srv/apps/deploy/WTools/traefik/.env`
- ACME data: `/srv/apps/deploy/WTools/traefik/data/acme.json`
- Docker Compose (prod): `/srv/apps/deploy/WTools/traefik/docker-compose.prod.yml`
- Docker Compose (dev): `/srv/apps/deploy/WTools/traefik/docker-compose.dev.yml`
- Shared middlewares: `/srv/apps/deploy/WTools/traefik/dynamic/shared/middlewares.yml`
- Dev hello world: `/srv/apps/deploy/WTools/traefik/dynamic/dev/hello-world.yml`
- Quadlet configs: `/srv/apps/deploy/WTools/traefik/quadlet/`
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
