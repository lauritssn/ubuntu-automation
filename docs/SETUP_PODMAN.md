# Podman Setup Guide

This guide walks you through using Podman on Ubuntu after installation. Podman is a daemonless container engine that provides a Docker-compatible command-line interface while running in rootless mode by default for enhanced security.

## Overview

Podman is installed with:

- **Dedicated user**: `podman` user for running containers
- **Rootless mode**: Enhanced security with user namespaces
- **Socket activation**: Systemd integration for services
- **Docker compatibility**: Drop-in replacement for most Docker commands

## Key Management Scripts

### podman-user

Execute Podman commands as the podman user with proper environment setup.

**Note**: These scripts automatically detect if you're running as the `podman` user or another user:

- If running as `podman` user: Commands execute directly (no sudo required)
- If running as another user: Commands use `sudo -u podman` to switch users

```bash
# Basic container operations
podman-user ps -a                    # List all containers
podman-user images                   # List images
podman-user run hello-world          # Run test container
podman-user pull nginx               # Pull image
podman-user run -d --name web nginx  # Run container in background

# Container management
podman-user stop web                 # Stop container
podman-user start web                # Start container
podman-user rm web                   # Remove container
podman-user rmi nginx                # Remove image

# System operations
podman-user version                  # Show version
podman-user info                     # System info
podman-user system prune             # Clean up unused resources
```

### podman-status

Comprehensive status check and diagnostics:

```bash
podman-status
```

Output includes:

- User and environment information
- Socket service status
- Socket file verification
- Version information
- Running containers
- Network configuration

### podman-socket

Manage socket-activated containers and services:

```bash
# List socket services
podman-socket list

# Service management
podman-socket status [service]       # Check status
podman-socket start [service]        # Start service
podman-socket stop [service]         # Stop service
podman-socket restart [service]      # Restart service
podman-socket logs [service]         # View logs

# Boot management
podman-socket enable [service]       # Enable on boot
podman-socket disable [service]      # Disable on boot
```

## Working with Podman

### Running as podman User vs Other Users

You can work with Podman in two ways:

**Option 1: Using management scripts (from any user)**

```bash
# Works from any user account (uses sudo when needed)
podman-user ps -a
podman-status
podman-socket list
```

**Option 2: Direct commands as podman user**

```bash
# Switch to podman user first
sudo su - podman

# Then run commands directly (no podman-user wrapper needed)
podman ps -a
podman images
podman run hello-world

# Environment is automatically set up in podman user's ~/.bashrc
echo $XDG_RUNTIME_DIR    # Should show /run/user/1001
```

### Basic Container Operations

```bash
# Run interactive container
podman-user run -it ubuntu bash

# Run container with port mapping
podman-user run -d -p 8080:80 --name webserver nginx

# Mount volume
podman-user run -d -v /host/path:/container/path --name app myapp

# Environment variables
podman-user run -e ENV_VAR=value --name app myapp

# Check container logs
podman-user logs webserver

# Execute command in running container
podman-user exec -it webserver bash
```

### Pod Management (Kubernetes-style)

```bash
# Create a pod
podman-user pod create --name mypod -p 8080:80

# Add containers to pod
podman-user run -d --pod mypod --name web nginx
podman-user run -d --pod mypod --name cache redis

# List pods
podman-user pod list

# Stop/start entire pod
podman-user pod stop mypod
podman-user pod start mypod

# Remove pod (removes all containers)
podman-user pod rm mypod
```

### Docker Compose Alternative (podman-compose)

```bash
# Using podman-compose (if installed)
sudo -u podman bash -c 'cd /path/to/compose/dir && podman-compose up -d'
sudo -u podman bash -c 'cd /path/to/compose/dir && podman-compose down'
```

## Systemd Integration

Podman excels at systemd integration for service management:

### Generate Systemd Units

```bash
# Generate systemd service files for containers
podman-user generate systemd --new --files --name webserver

# This creates: container-webserver.service
# Move it to systemd directory and enable:
sudo mv container-webserver.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable container-webserver.service
sudo systemctl start container-webserver.service
```

### Socket Activation

```bash
# Create socket-activated service
podman-user run -d --name traefik -p 80:80 -p 443:443 traefik
podman-user generate systemd --new --files --name traefik

# Enable socket activation
sudo systemctl enable container-traefik.service
```

## Troubleshooting

### Common Issues

**"podman is not in the sudoers file" error:**
This is expected and correct! The `podman` user is intentionally not in sudoers for security.

```bash
# Solution 1: Use the management scripts from another user
podman-status        # Works from any user with sudo access
podman-user ps -a    # Works from any user with sudo access

# Solution 2: Switch to podman user and run commands directly
sudo su - podman
podman ps -a         # No sudo needed when running as podman user
```

**"Permission denied" errors:**

```bash
# Check if podman user exists
id podman

# Verify socket is running
podman-status

# Manual socket start (as podman user)
sudo su - podman
systemctl --user start podman.socket
```

**Container fails to start:**

```bash
# Check detailed logs
podman-user logs --details container-name

# Check system events
podman-user events --since 1h

# Verbose mode
podman-user --log-level debug run image-name
```

**Storage issues:**

```bash
# Check storage info
podman-user system df

# Clean up unused resources
podman-user system prune -a

# Check storage configuration
podman-user info --format "{{.Store}}"
```

### Debug Commands

```bash
# System information
podman-user info

# Version details
podman-user version

# Storage usage
podman-user system df

# Events monitoring
podman-user events

# Service logs
sudo -u podman bash -c 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"; journalctl --user -u podman.socket'
```

## Security Benefits

### Rootless Operation

- Containers run without root privileges
- Improved security isolation
- Reduced attack surface
- User namespace separation

### No Daemon

- No background daemon running as root
- Direct container execution
- Better resource isolation
- Simpler security model

### User Separation

- Dedicated `podman` user
- Isolated from system processes
- Protected configuration files
- Separate network namespaces

## Key Differences from Docker

| Feature             | Docker                             | Podman                      |
| ------------------- | ---------------------------------- | --------------------------- |
| Architecture        | Client-server (daemon)             | Daemonless                  |
| Root requirement    | Optional (rootless mode available) | Rootless by default         |
| Systemd integration | Limited                            | Native                      |
| Pod support         | No                                 | Yes (Kubernetes-compatible) |
| Image compatibility | Docker images                      | Docker + OCI images         |
| Compose support     | docker-compose                     | podman-compose              |

## Performance Considerations

### Benefits

- **No daemon overhead**: Direct container execution
- **Better resource isolation**: Per-user containers
- **Systemd integration**: Native service management
- **Socket activation**: Containers start on-demand

### Limitations

- **Networking**: Some advanced networking features differ
- **Privileged operations**: Limited in rootless mode
- **Port binding**: No access to ports < 1024 without privileges
- **Volume mounting**: Some restrictions with rootless operation

## Migration from Docker

### Command Translation

Most Docker commands work with `podman-user`:

```bash
# Docker -> Podman
docker ps        -> podman-user ps
docker run       -> podman-user run
docker build     -> podman-user build
docker pull      -> podman-user pull
docker push      -> podman-user push
docker images    -> podman-user images
docker exec      -> podman-user exec
```

### Docker Compose Files

Use podman-compose for existing docker-compose.yml files:

```bash
# Install podman-compose (if not already installed)
sudo apt install podman-compose

# Use existing compose files
sudo -u podman bash -c 'cd /path/to/project && podman-compose up -d'
```

## Best Practices

### Container Management

1. **Use pods for related containers** - Group related services
2. **Leverage systemd integration** - Generate service files for production
3. **Regular cleanup** - Use `podman-user system prune` regularly
4. **Monitor resources** - Check `podman-user system df` periodically

### Security

1. **Keep images updated** - Regular `podman-user pull` for base images
2. **Use minimal base images** - Reduce attack surface
3. **Avoid privileged containers** - Leverage rootless benefits
4. **Regular security scans** - Scan images for vulnerabilities

### Performance

1. **Use socket activation** - For services that start on-demand
2. **Monitor resource usage** - `podman-user stats` for running containers
3. **Optimize storage** - Regular pruning of unused images/containers
4. **Consider pod networking** - Efficient inter-container communication

## Advanced Configuration

### Custom Storage Location

Podman stores data in `/home/podman/.local/share/containers/storage` by default.

### Network Configuration

```bash
# List networks
podman-user network ls

# Create custom network
podman-user network create --driver bridge mynetwork

# Use custom network
podman-user run -d --network mynetwork --name app nginx
```

### Registry Configuration

Edit `/home/podman/.config/containers/registries.conf` for custom registries.

## Monitoring and Maintenance

### Regular Maintenance Tasks

```bash
# Weekly cleanup (add to cron/systemd timer)
podman-user system prune -f

# Update base images monthly
podman-user images --format "table {{.Repository}}:{{.Tag}}" | tail -n +2 | xargs -I {} podman-user pull {}

# Check system health
podman-status
```

### Monitoring Commands

```bash
# Resource usage
podman-user stats

# System events
podman-user events --since 24h

# Storage usage
podman-user system df

# Network inspection
podman-user network inspect bridge
```

## Support and Resources

- **Official Documentation**: https://podman.io/docs/
- **Container Images**: https://hub.docker.com/ (Docker Hub compatible)
- **Podman GitHub**: https://github.com/containers/podman
- **Red Hat Guides**: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/building_running_and_managing_containers/

## Summary

Podman provides a secure, daemonless alternative to Docker with excellent systemd integration and rootless operation by default. Use the provided management scripts (`podman-user`, `podman-status`, `podman-socket`) for easy container management while maintaining security best practices.
