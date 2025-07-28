# Docker Rootless Setup Guide

This guide walks you through setting up Docker to run in rootless mode on Ubuntu, allowing Docker to run without root privileges for enhanced security.

## Prerequisites

- Ubuntu server with sudo access
- A dedicated user account for running Docker (recommended)

## Step 1: Use Dedicated Docker User (Optional but Recommended)

```bash
# Create a dedicated user for rootless Docker (should already have been created)
# sudo useradd -m -s /bin/bash dockerrootless

# Switch to the new user
sudo su - dockerrootless
```

## Step 2: Install Rootless Docker

```bash
# As the dockerrootless user, install rootless Docker
dockerd-rootless-setuptool.sh install

# If you get permission errors, you may need to enable lingering for the user
# (run this as root/sudo):
# sudo loginctl enable-linger dockerrootless
```

## Step 3: Configure Environment

```bash
# Set up environment variables permanently
echo 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"' >> ~/.bashrc
echo 'export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock' >> ~/.bashrc

# Apply the changes
source ~/.bashrc
```

## Step 4: Start and Enable Docker Service

```bash
# Enable Docker to start automatically
systemctl --user enable docker

# Start Docker service
systemctl --user start docker

# Check status
systemctl --user status docker
```

## Step 5: Test Installation

```bash
# Test with Hello World
docker run hello-world
```

## Troubleshooting

### Error: "another RootlessKit is running with the same state directory"

This happens when there are leftover processes from a previous installation:

```bash
# Kill existing processes
pkill -f dockerd-rootless
pkill -f rootlesskit

# Clean up lock directory
rm -rf /run/user/$(id -u)/dockerd-rootless

# Wait for processes to terminate
sleep 2

# Restart the service
systemctl --user restart docker
```

### Error: "Unit docker.service could not be found"

The rootless setup wasn't completed properly:

```bash
# Complete cleanup
systemctl --user stop docker.service 2>/dev/null || true
dockerd-rootless-setuptool.sh uninstall -f
pkill -f dockerd-rootless
pkill -f rootlesskit
rm -rf /run/user/$(id -u)/dockerd-rootless
rm -rf ~/.local/share/docker

# Reinstall
dockerd-rootless-setuptool.sh install

# Start service
systemctl --user start docker
```

### Error: "Cannot connect to the Docker daemon"

Check if the environment variables are set correctly:

```bash
# Check current environment
echo $DOCKER_HOST
echo $XDG_RUNTIME_DIR

# Set them manually if needed
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock

# Add to ~/.bashrc to make permanent
echo 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"' >> ~/.bashrc
echo 'export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock' >> ~/.bashrc
```

### Manual Start (for debugging)

If the systemd service fails, you can start Docker manually to see detailed errors:

```bash
# Start in foreground with debug output
/usr/bin/dockerd-rootless.sh --experimental --debug

# Or start in background
/usr/bin/dockerd-rootless.sh --experimental &
```

## Verification Commands

```bash
# Check Docker version and info
docker version
docker info

# List running containers
docker ps

# Check systemd service status
systemctl --user status docker

# View logs
journalctl --user --unit docker.service
```

## Key Benefits of Rootless Docker

- **Enhanced Security**: Docker daemon runs without root privileges
- **User Isolation**: Each user has their own Docker daemon
- **Reduced Attack Surface**: Potential security vulnerabilities have limited impact
- **Multi-tenant Safe**: Multiple users can run Docker independently

## Important Notes

- Rootless Docker has some limitations compared to regular Docker (e.g., no access to privileged ports < 1024)
- Each user needs their own rootless Docker setup
- The Docker daemon runs only when the user is logged in (unless using lingering)
- Some Docker features may not work in rootless mode

## Cleaning Up Completely

If you need to completely remove rootless Docker:

```bash
# Stop and disable service
systemctl --user stop docker
systemctl --user disable docker

# Uninstall rootless setup
dockerd-rootless-setuptool.sh uninstall -f

# Remove Docker data
rm -rf ~/.local/share/docker
rm -rf /run/user/$(id -u)/dockerd-rootless

# Remove environment variables from ~/.bashrc
# (manually edit the file to remove the export lines)
```
