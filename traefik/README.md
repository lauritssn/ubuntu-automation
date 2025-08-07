# Traefik Container Setup

This repository contains configurations for running Traefik reverse proxy in different environments using modern containerization approaches.

## Architecture

### Development Environment
- Uses **Docker Compose** for simplicity
- Direct port binding (80, 443, 8080)
- Simplified configuration for local development
- No socket activation (not needed for dev)

### Test/Production Environments
- Uses **Podman Quadlets** for systemd integration
- **Socket activation** for client IP preservation
- Rootless containers with full security isolation
- Automatic container updates via systemd

## Directory Structure

```
traefik/
├── quadlets/                   # Quadlet configurations for test/prod
│   ├── traefik-test.container
│   ├── traefik-prod.container
│   ├── whoami-test.container
│   └── whoami-prod.container
├── scripts/                    # Deployment and management scripts
│   ├── deploy-dev.sh
│   ├── deploy-test.sh
│   └── deploy-prod.sh
├── systemd/                    # Socket activation files
│   ├── http-prod.socket
│   ├── http-test.socket
│   ├── https-prod.socket
│   ├── https-test.socket
│   ├── traefik-prod.socket
│   └── traefik-test.socket
├── docker-compose.dev.yml      # Development compose file
├── traefik-dev.yml            # Dev Traefik config
├── traefik-test.yml           # Test Traefik config  
├── traefik.yml                # Production Traefik config
├── dynamic/                   # Dynamic configuration files
│   ├── dev/                   # Development-specific configs
│   │   ├── dashboard.yml
│   │   └── whoami.yml
│   ├── test/                  # Test environment configs
│   │   ├── dashboard.yml
│   │   └── whoami.yml
│   ├── prod/                  # Production configs
│   │   ├── dashboard.yml
│   │   └── whoami.yml
│   └── shared/                # Shared configurations
│       └── middlewares.yml
├── data/                      # Persistent data (ACME certs, etc.)
│   └── acme.json
├── logs/                      # Traefik logs
│   ├── access.log
│   └── traefik.log
├── plugins-storage/           # Plugin storage
└── env.template              # Environment variables template
```

## Quick Start

### Development Environment

```bash
# Set up environment variables
cp env.template .env
# Edit .env with your settings

# Deploy development environment
./scripts/deploy-dev.sh

# Access services
# - Dashboard: http://localhost:8080 or http://traefik.localhost
# - Whoami: http://whoami.localhost

# Stop development environment
# (No cleanup script - use docker-compose down)
```

### Test Environment

```bash
# Set environment variables
export APP_DOMAIN="test.yourdomain.com"
export LETSENCRYPT_EMAIL="admin@yourdomain.com"

# Deploy test environment with Quadlets
./scripts/deploy-test.sh

# Check status
systemctl --user status traefik-test.service

# Stop test environment
# (Use systemctl --user stop commands)
```

### Production Environment

```bash
# Set environment variables
export APP_DOMAIN="yourdomain.com"
export LETSENCRYPT_EMAIL="admin@yourdomain.com"
export TRAEFIK_DASHBOARD_DOMAIN="traefik.yourdomain.com"

# Deploy production environment with Quadlets
./scripts/deploy-prod.sh

# Check status
systemctl --user status traefik-prod.service

# Stop production environment
# (Use systemctl --user stop commands)
```

## Key Features

### Socket Activation (Test/Prod)
- Preserves real client IP addresses in rootless containers
- Near-native network performance
- systemd manages privileged port binding
- Automatic failover and restart capabilities

### Quadlet Benefits
- Declarative container management
- Automatic systemd service generation
- Integrated with systemd logging and monitoring
- Built-in health checks and restart policies
- AutoUpdate support for container images

### Security Features
- Rootless containers for all environments
- AppArmor profile management
- Proper file permissions for ACME certificates
- Resource limits in production
- Network isolation between services

## Environment Variables

Create a `.env` file or set these environment variables:

```bash
# Required for all environments
APP_DOMAIN=yourdomain.com
LETSENCRYPT_EMAIL=admin@yourdomain.com

# Optional
TRAEFIK_VERSION=v3.5.0
TRAEFIK_LOG_LEVEL=INFO
TRAEFIK_NETWORK=traefik
TRAEFIK_DASHBOARD_DOMAIN=traefik.yourdomain.com

# Development only
TRAEFIK_WEB_PORT=80
TRAEFIK_WEBSECURE_PORT=443
TRAEFIK_DASHBOARD_PORT=8080

# Production security
TRAEFIK_DASHBOARD_USERS=admin:$$2y$$10$$...
TRUSTED_IPS=172.18.0.0/16,172.19.0.0/16,172.20.0.0/16,127.0.0.1/32
```

## Monitoring and Logs

### Systemd Integration (Test/Prod)
```bash
# View logs
journalctl --user -u traefik-prod.service -f

# Check status
systemctl --user status traefik-prod.service

# Restart service
systemctl --user restart traefik-prod.service
```

### Development Logs
```bash
# View logs
docker-compose -f docker-compose.dev.yml logs -f traefik

# Check status
docker-compose -f docker-compose.dev.yml ps
```

## Socket Activation Setup

The systemd socket files enable socket activation for Traefik services:

- `systemd/traefik-test.socket` → Activates test environment
- `systemd/traefik-prod.socket` → Activates production environment
- `systemd/http-{test,prod}.socket` → HTTP port (80) activation
- `systemd/https-{test,prod}.socket` → HTTPS port (443) activation

Quadlet containers in `quadlets/` directory work with these socket files for systemd integration.

## Troubleshooting

### Socket Activation Issues
```bash
# Check if sockets are listening
ss -tlnp | grep ':80\|:443\|:8080'

# Verify systemd socket activation
systemctl --user status traefik-test.socket
```

### Container Issues
```bash
# Check container logs
podman logs traefik-test

# Inspect container
podman inspect traefik-test

# Check network connectivity
podman exec traefik-test traefik healthcheck --ping
```

### Development Issues
```bash
# Check Docker system
docker info

# Verify network
docker network ls | grep traefik

# Check port conflicts
netstat -tlnp | grep ':80\|:443\|:8080'
```

## Notes

- Development environment uses standard Docker/Docker Compose for simplicity
- Test/Production use Podman Quadlets for better systemd integration and security
- Socket activation is only used in test/production for client IP preservation
- All environments support the same Traefik dynamic configuration files
- Environment-specific configurations are stored in `dynamic/` subdirectories
