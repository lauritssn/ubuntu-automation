# Traefik Dynamic Configuration Setup

This directory contains a comprehensive Traefik reverse proxy setup with dynamic service configuration, supporting both development and production environments.

## 📁 Directory Structure

```
traefik/
├── traefik.yml              # Main production configuration
├── traefik-dev.yml          # Development-specific configuration
├── docker-compose.prod.yml  # Production (socket activation)
├── docker-compose.dev.yml   # Development (direct ports)
├── env.template             # Environment variables template
├── dynamic/
│   ├── dev/                 # Development dynamic configs
│   │   ├── dashboard.yml    # Dashboard routing
│   │   └── services.yml     # Development services
│   └── prod/                # Production dynamic configs
│       ├── strapi.yml       # Strapi service
│       ├── vaultwarden.yml  # Vaultwarden service
│       └── monitor.yml      # Monitoring service
└── data/                    # Persistent data (certificates, etc.)
```

## 🚀 Quick Start

### Development Setup

1. **Set up Podman environment:**

   ```bash
   # Set XDG_RUNTIME_DIR if not set
   export XDG_RUNTIME_DIR="/run/user/$(id -u)"

   # Start Podman socket (if not already running)
   systemctl --user enable --now podman.socket
   ```

2. **Create environment file:**

   ```bash
   cp env.template .env
   # Edit .env with your settings (especially XDG_RUNTIME_DIR)
   ```

3. **Create Traefik network:**

   ```bash
   podman network create traefik
   ```

4. **Start development environment:**

   ```bash
   podman-compose -f docker-compose.dev.yml up -d
   ```

5. **Access dashboard:**
   - Direct: http://localhost:8080
   - Via proxy: http://traefik.localhost

### Production Setup (with Socket Activation)

1. **Setup as podman user:**

   ```bash
   sudo su - podman
   ```

2. **Create socket activation:**

   ```bash
   /srv/apps/scripts/socket-setup.sh traefik 80 443 8080
   ```

3. **Create systemd service:**

   ```bash
   cat > ~/.config/containers/systemd/traefik.container << 'EOF'
   [Unit]
   Description=Traefik reverse proxy
   Requires=traefik.socket
   After=traefik.socket

   [Service]
   Type=oneshot
   RemainAfterExit=true
   WorkingDirectory=/srv/apps/deploy/WTools/traefik
   ExecStart=/usr/bin/podman-compose -f docker-compose.prod.yml up -d
   ExecStop=/usr/bin/podman-compose -f docker-compose.prod.yml down
   TimeoutStartSec=60
   TimeoutStopSec=30

   [Install]
   WantedBy=default.target
   EOF
   ```

4. **Enable and start:**
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable traefik.socket traefik.service
   systemctl --user start traefik.socket
   ```

## 🔧 Configuration Files

### Main Configurations

- **`traefik.yml`**: Production configuration with security headers, rate limiting, and socket activation support
- **`traefik-dev.yml`**: Development configuration with debug logging and relaxed security

### Dynamic Configurations

Service configurations are automatically loaded from the `dynamic/` directory:

- **Development** (`dynamic/dev/`): Uses `.localhost` domains for easy local testing
- **Production** (`dynamic/prod/`): Uses environment variables for domain configuration

## 🛡️ Security Features

### Production Security

- **HTTPS by default** with automatic Let's Encrypt certificates
- **Security headers** (HSTS, frame protection, XSS protection)
- **Rate limiting** to prevent abuse
- **Trusted IP forwarding** for real client IP preservation
- **Basic authentication** for sensitive services

### Development Convenience

- **HTTP access** for easy local development
- **Debug logging** for troubleshooting
- **Relaxed rate limits** for development workflows
- **No HTTPS redirects** to avoid certificate issues

## 📝 Adding New Services

### Development Service

Create `dynamic/dev/my-service.yml`:

```yaml
http:
  routers:
    my-service-dev:
      rule: "Host(`my-service.localhost`)"
      service: "my-service-dev"
      entryPoints:
        - "web"
      middlewares:
        - "dev-headers"

  services:
    my-service-dev:
      loadBalancer:
        servers:
          - url: "http://my-service-dev:3000"
```

### Production Service

Create `dynamic/prod/my-service.yml`:

```yaml
http:
  routers:
    my-service-prod:
      rule: "Host(`${MY_SERVICE_DOMAIN}`)"
      service: "my-service-prod"
      entryPoints:
        - "websecure"
      tls:
        certResolver: "letsencrypt"
      middlewares:
        - "security-headers"
        - "rate-limit"

  services:
    my-service-prod:
      loadBalancer:
        servers:
          - url: "http://my-service-prod:3000"
        healthCheck:
          path: "/health"
          interval: "30s"
```

Add the domain to your `.env` file:

```env
MY_SERVICE_DOMAIN=service.yourdomain.com
```

## 🔍 Monitoring and Debugging

### Check Service Status

```bash
# Development
podman-compose -f docker-compose.dev.yml logs traefik

# Production (as podman user)
systemctl --user status traefik.socket
journalctl --user -u traefik.service -f
```

### Dashboard Access

- **Development**: http://localhost:8080 or http://traefik.localhost
- **Production**: https://your-domain.com:8080 (if API access is enabled)

### Health Checks

All services include health checks for better reliability and monitoring.

## 🌐 Network Configuration

### Development

- Uses Podman bridge network
- Direct port mapping (80, 443, 8080)
- Standard Podman socket access

### Production

- Uses Podman with socket activation
- Real IP preservation through trusted headers
- IPv4 and IPv6 support
- Enhanced security isolation

## 📊 Environment Variables

Key environment variables (see `env.template`):

- `TRAEFIK_LOG_LEVEL`: Logging level (DEBUG, INFO, WARN, ERROR)
- `APP_DOMAIN`: Main application domain
- `VAULTWARDEN_URL`: Vaultwarden service domain
- `MONITOR_URL`: Monitoring service domain
- `XDG_RUNTIME_DIR`: Podman runtime directory (production)

## 🔒 Best Practices

1. **Use environment variables** for all domain configurations
2. **Enable health checks** for all services
3. **Apply security middlewares** to production services
4. **Use specific rate limits** for different service types
5. **Regularly update certificates** (automatic with Let's Encrypt)
6. **Monitor logs** for security and performance issues
7. **Test configurations** in development before production deployment

## 🚨 Troubleshooting

### Common Issues

1. **Certificate issues**: Check domain DNS and firewall settings
2. **Service not accessible**: Verify network connectivity and service health
3. **Socket activation fails**: Check user permissions and systemd configuration
4. **Dashboard not accessible**: Verify API configuration and network settings
5. **Podman socket not found**: Ensure `XDG_RUNTIME_DIR` is set and Podman socket is running
6. **Permission denied on socket**: Check that user has access to Podman socket

### Useful Commands

```bash
# Reload dynamic configuration
podman-compose -f docker-compose.dev.yml restart traefik

# Check network connectivity
podman network ls
podman network inspect traefik

# Validate configuration
podman-compose -f docker-compose.dev.yml config

# Podman-specific commands
podman system info                    # Check Podman system status
systemctl --user status podman.socket # Check Podman socket status
podman ps -a                         # List all containers
echo $XDG_RUNTIME_DIR                # Verify runtime directory
```

This setup provides a robust, scalable, and secure reverse proxy solution suitable for both development and production environments.
