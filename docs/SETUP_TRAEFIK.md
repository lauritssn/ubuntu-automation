# Traefik Setup with Podman - Service File Approach

This guide explains how to set up Traefik with Podman using **systemd service files** with Podman Compose for maximum configuration flexibility. Production uses socket activation for real client IP preservation, while development uses direct port mapping for simplicity.

## Overview: Service File + Docker Compose Approach

This approach provides the best balance of features:

### ✅ **Why Service Files + Podman Compose?**

- **Socket activation compatibility** - Perfect integration with systemd socket activation
- **Maximum compose configuration** - Configure everything in `podman-compose.yml`
- **Environment-driven** - Single `.env` file controls all settings
- **Easy debugging** - Clear systemd and compose logs
- **Production-ready** - Proper restart policies and dependencies
- **Scalable** - Add any number of services to compose files

### 🚫 **Why Not Quadlet?**

- Poor socket activation support
- Limited systemd integration
- Harder to debug when issues arise
- Less environment variable substitution support

## Environment-Specific Features

### Production (Socket Activation)
- ✅ **Real client IP preservation** - No NAT layer between client and Traefik
- ✅ **Enhanced security** - Containers run with network isolation  
- ✅ **Automatic HTTPS** - Let's Encrypt with HTTP to HTTPS redirects
- ✅ **Secure dashboard** - Authentication required, HTTPS-only
- ✅ **Comprehensive logging** - Structured JSON logs with rotation

### Development (Direct Port Mapping)
- ✅ **Simple configuration** - No systemd socket complexity
- ✅ **Fast iteration** - Quick container restarts and debugging
- ✅ **Local .localhost domains** - Easy local testing with hosts file
- ✅ **Insecure dashboard** - No authentication needed for convenience
- ✅ **Debug logging** - Verbose output for troubleshooting

## Prerequisites

- Ubuntu server with Podman installed via the `podman_install.sh` script
- A dedicated `podman` user created during installation
- Socket activation configured (done automatically by podman_install.sh)
- IPv4 and IPv6 forwarding enabled in sysctl
- Domain name(s) pointing to your server (production only)
- Ports 80, 443, and 8080 accessible from the internet (production only)

## Quick Start Guide

### Development Setup (Mac/Local)

```bash
# Clone the repository
git clone <your-repo> traefik-setup
cd traefik-setup/traefik

# Set up environment for development
cp env.template .env

# Edit .env with development settings:
cat > .env << 'EOF'
ENVIRONMENT=development
TRAEFIK_LOG_LEVEL=DEBUG
TRAEFIK_API_INSECURE=true
APP_DOMAIN=localhost
HELLO_WORLD_DOMAIN=hello.localhost
TRAEFIK_DASHBOARD_DOMAIN=traefik.localhost
XDG_RUNTIME_DIR=/run/user/$(id -u)
TRAEFIK_NETWORK=traefik
WHOAMI_VERSION=latest
EOF

# Create network and start services
podman network create traefik
podman-compose -f docker-compose.dev.yml up -d

# Add to /etc/hosts for easy access
echo "127.0.0.1 hello.localhost traefik.localhost" | sudo tee -a /etc/hosts

# Test the setup
curl http://localhost:8080/api/overview  # Traefik dashboard API
curl -H "Host: hello.localhost" http://localhost  # Hello world service
```

**Development Access:**
- **Traefik Dashboard**: `http://localhost:8080` or `http://traefik.localhost`
- **Hello World**: `http://hello.localhost`

---

## Production Setup (Ubuntu with Socket Activation)

### Step 1: Verify Podman Installation

Switch to the podman user and verify the environment:

```bash
sudo su - podman

# Verify environment
echo $XDG_RUNTIME_DIR  # Should show: /run/user/[podman-user-id]
podman version         # Should display version without errors
ls /srv/apps/scripts/socket-setup.sh  # Should exist and be executable
```

### Step 2: Deploy Traefik Configuration

```bash
# As root, set up deployment directory
sudo mkdir -p /srv/apps/deploy
sudo chown -R podman:podman /srv/apps/deploy

# As podman user
sudo su - podman
cd /srv/apps/deploy/

# Clone your repository
git clone <your-repo> WTools
cd /srv/apps/deploy/WTools/traefik

# Set up production environment
cp env.template .env
```

Edit the `.env` file for production:

```bash
vi .env
# Update these values for PRODUCTION:
ENVIRONMENT=production
APP_DOMAIN=your-app.domain.com
LETSENCRYPT_EMAIL=your-email@domain.com
TRAEFIK_DASHBOARD_DOMAIN=traefik.yourdomain.com
TRAEFIK_LOG_LEVEL=INFO
TRAEFIK_API_INSECURE=false
XDG_RUNTIME_DIR=/run/user/$(id -u)
# Generate with: htpasswd -nb admin password
TRAEFIK_DASHBOARD_USERS=admin:$2y$10$...
```

### Step 3: Install Systemd Configuration

```bash
# As podman user, create systemd directories
mkdir -p ~/.config/systemd/user

# Copy service files
cp systemd/traefik-prod.service ~/.config/systemd/user/traefik.service
cp systemd/traefik.socket ~/.config/systemd/user/traefik.socket

# Set up permissions
chmod 600 data/acme.json 2>/dev/null || touch data/acme.json && chmod 600 data/acme.json
mkdir -p logs
```

### Step 4: Enable and Start Services (Production)

```bash
# Reload systemd configuration
systemctl --user daemon-reload

# Enable socket activation (containers start on first connection)
systemctl --user enable traefik.socket

# Start the socket listeners
systemctl --user start traefik.socket

# Enable user lingering to survive logout
sudo loginctl enable-linger podman
```

### Step 5: Verify Production Installation

```bash
# Check socket status
systemctl --user status traefik.socket
systemctl --user list-sockets

# Test HTTP access (this will trigger container startup)
curl -H "Host: your-domain.com" http://localhost

# Check if Traefik container started
podman ps

# Access the dashboard via HTTPS
curl https://traefik.your-domain.com/api/overview

# Check logs
journalctl --user -u traefik.service -f
```

---

## Development Deployment (Direct Port Mapping)

For development on the production server:

```bash
# As podman user
sudo su - podman
cd /srv/apps/deploy/WTools/traefik

# Use development configuration
cp systemd/traefik-dev.service ~/.config/systemd/user/traefik.service

# Update .env for development
sed -i 's/ENVIRONMENT=production/ENVIRONMENT=development/' .env
sed -i 's/TRAEFIK_API_INSECURE=false/TRAEFIK_API_INSECURE=true/' .env
sed -i 's/TRAEFIK_LOG_LEVEL=INFO/TRAEFIK_LOG_LEVEL=DEBUG/' .env

# Reload and start
systemctl --user daemon-reload
systemctl --user enable --now traefik.service

# Test
curl http://localhost:8080/api/overview
```

---

## Configuration Architecture

### Service File Hierarchy

```
traefik/
├── systemd/
│   ├── traefik-prod.service    # Production service (socket activation)
│   ├── traefik-dev.service     # Development service (direct ports)
│   └── traefik.socket          # Socket activation config
├── podman-compose.prod.yml     # Production compose (no port mappings)
├── podman-compose.dev.yml      # Development compose (with port mappings)
├── traefik.yml                 # Production config (socket activation)
├── traefik-dev.yml            # Development config (direct ports)
└── .env                       # Environment-driven configuration
```

### Production Features in Compose File

The production `podman-compose.prod.yml` includes:

```yaml
services:
  traefik:
    # NO port mappings - socket activation handles this
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard-prod.rule=Host(`${TRAEFIK_DASHBOARD_DOMAIN}`)"
      - "traefik.http.routers.dashboard-prod.service=api@internal"
      - "traefik.http.routers.dashboard-prod.entrypoints=websecure"
      - "traefik.http.routers.dashboard-prod.tls.certresolver=letsencrypt"
      - "traefik.http.routers.dashboard-prod.middlewares=basic-auth@file,security-headers@file"
    deploy:
      resources:
        limits:
          memory: 512M
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
    # All other services can be added here
```

### Development Features in Compose File

The development `podman-compose.dev.yml` includes:

```yaml
services:
  traefik:
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # Direct dashboard access
    labels:
      - "traefik.http.routers.dashboard-dev.middlewares=dev-headers@file"
    deploy:
      resources:
        limits:
          memory: 256M  # Lower resource limits for development
```

## Dynamic Configuration

### Shared Middlewares (`dynamic/shared/middlewares.yml`)

```yaml
http:
  middlewares:
    # Production security headers
    security-headers:
      headers:
        frameDeny: true
        sslRedirect: true
        forceSTSHeader: true
        stsSeconds: 31536000

    # Development headers (relaxed)
    dev-headers:
      headers:
        frameDeny: false
        customRequestHeaders:
          X-Forwarded-Proto: "http"

    # Authentication
    basic-auth:
      basicAuth:
        users:
          - "${TRAEFIK_DASHBOARD_USERS}"
```

### Production Dashboard (`dynamic/prod/dashboard.yml`)

```yaml
http:
  routers:
    dashboard-secure:
      rule: "Host(`${TRAEFIK_DASHBOARD_DOMAIN}`)"
      entryPoints: ["websecure"]
      middlewares: ["basic-auth", "security-headers"]
      service: "api@internal"
      tls:
        certResolver: "letsencrypt"
```

## Management Commands

### Production (Socket Activation)

```bash
# Check status
systemctl --user status traefik.socket
systemctl --user status traefik.service

# View logs
journalctl --user -u traefik.service -f

# Restart (graceful)
systemctl --user reload traefik.service

# Full restart
systemctl --user restart traefik.socket
```

### Development (Direct Service)

```bash
# Check status
systemctl --user status traefik.service

# View logs
journalctl --user -u traefik.service -f
podman logs traefik-dev -f

# Restart
systemctl --user restart traefik.service
```

### Using Pre-installed Helper Scripts

```bash
# Check overall Podman status
sudo podman-status

# Production management
sudo podman-socket status traefik
sudo podman-socket restart traefik
sudo podman-socket logs traefik

# Development management  
sudo podman-user systemctl --user status traefik.service
sudo podman-user systemctl --user restart traefik.service

# View containers
sudo podman-user ps -a
```

## Adding New Services

### Production Service Example

Add to `podman-compose.prod.yml`:

```yaml
services:
  # ... existing traefik service ...
  
  my-app:
    image: my-app:latest
    container_name: my-app-prod
    restart: unless-stopped
    networks:
      - traefik
    # NO PublishPort - stays internal
    # Configuration via labels or dynamic files
```

Then create `dynamic/prod/my-app.yml`:

```yaml
http:
  routers:
    my-app-prod:
      rule: "Host(`app.${APP_DOMAIN}`)"
      entryPoints: ["web", "websecure"]
      middlewares: ["security-headers", "rate-limit"]
      service: "my-app-prod"
      tls:
        certResolver: "letsencrypt"

  services:
    my-app-prod:
      loadBalancer:
        servers:
          - url: "http://my-app-prod:8080"
```

### Development Service Example

Add to `podman-compose.dev.yml`:

```yaml
services:
  # ... existing traefik service ...
  
  my-app:
    image: my-app:latest
    container_name: my-app-dev
    restart: unless-stopped
    networks:
      - traefik
    # NO PublishPort - stays internal
```

Create `dynamic/dev/my-app.yml`:

```yaml
http:
  routers:
    my-app-dev:
      rule: "Host(`app.localhost`)"
      entryPoints: ["web"]
      middlewares: ["dev-headers"]
      service: "my-app-dev"

  services:
    my-app-dev:
      loadBalancer:
        servers:
          - url: "http://my-app-dev:8080"
```

## Troubleshooting

### Production Issues

```bash
# Check socket activation
systemctl --user status traefik.socket
systemctl --user list-sockets

# Check service logs
journalctl --user -u traefik.service --no-pager -l

# Manual container debugging
podman logs traefik-prod
podman exec -it traefik-prod /bin/sh

# Check compose status
cd /srv/apps/deploy/WTools/traefik
podman-compose -f podman-compose.prod.yml ps
```

### Development Issues

```bash
# Check service status
systemctl --user status traefik.service

# Check port conflicts
sudo netstat -tlnp | grep -E ':(80|443|8080)'

# Check container logs
podman logs traefik-dev -f

# Restart everything
systemctl --user restart traefik.service
```

### Common Fixes

```bash
# Fix ownership
sudo chown -R podman:podman /srv/apps/deploy
chmod 600 /srv/apps/deploy/WTools/traefik/data/acme.json

# Recreate network
podman network rm traefik
podman network create traefik

# Check environment
sudo su - podman -c 'echo $XDG_RUNTIME_DIR'
```

## Environment File Reference

### Production .env

```bash
ENVIRONMENT=production
APP_DOMAIN=myapp.example.com
TRAEFIK_DASHBOARD_DOMAIN=traefik.example.com
LETSENCRYPT_EMAIL=admin@example.com
TRAEFIK_LOG_LEVEL=INFO
TRAEFIK_API_INSECURE=false
TRAEFIK_DASHBOARD_USERS=admin:$2y$10$...
XDG_RUNTIME_DIR=/run/user/1001
```

### Development .env

```bash
ENVIRONMENT=development
APP_DOMAIN=localhost
TRAEFIK_DASHBOARD_DOMAIN=traefik.localhost
HELLO_WORLD_DOMAIN=hello.localhost
TRAEFIK_LOG_LEVEL=DEBUG
TRAEFIK_API_INSECURE=true
XDG_RUNTIME_DIR=/run/user/$(id -u)
```

## Summary

This **Service File + Podman Compose** approach provides:

### Production Benefits
- **Socket activation** preserves real client IP addresses
- **Maximum security** with HTTPS-only, authentication, and security headers
- **Automatic certificates** with Let's Encrypt
- **Comprehensive logging** with rotation and structured output
- **Resource management** with memory limits and health checks

### Development Benefits  
- **Simple port mapping** for easy local access
- **Debug-friendly** with verbose logging and insecure dashboard
- **Fast iteration** with quick container restarts
- **Local domains** with .localhost for testing

### Both Environments
- **Everything in compose files** - full configuration control
- **Environment-driven** - single .env file for all settings
- **Systemd integration** - proper service management and logging
- **Scalable architecture** - easy to add new services
- **Network isolation** - internal services remain unexposed

The configuration leverages all infrastructure from the `podman_install.sh` script while providing clear separation between production (socket activation) and development (direct port mapping) patterns with maximum compose file flexibility.
