#!/bin/bash
set -euo pipefail

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Deploy Traefik Test Environment using Quadlets with Socket Activation
echo "Deploying Traefik Test Environment with Quadlets and Socket Activation..."

# Ensure we're in the right directory
cd "$(dirname "$0")/.."

# Stop any existing services as podman user first
echo "Stopping existing services..."
sudo -u podman -i bash -c "systemctl --user stop whoami-test.service traefik-test.service 2>/dev/null || true"
sudo -u podman -i bash -c "systemctl --user stop http-test.socket traefik-test.socket 2>/dev/null || true"

# Define directories for podman user
PODMAN_HOME="/home/podman"
SYSTEMD_USER_DIR="$PODMAN_HOME/.config/systemd/user"
QUADLET_DIR="$PODMAN_HOME/.config/containers/systemd"

# Create directories with proper ownership
echo "Creating systemd and quadlet directories..."
mkdir -p "$SYSTEMD_USER_DIR"
mkdir -p "$QUADLET_DIR"
chown -R podman:podman "$PODMAN_HOME/.config"

echo "Copying systemd socket units for Traefik..."
# Remove existing files and copy new ones
rm -f "$SYSTEMD_USER_DIR/http-test.socket"
rm -f "$SYSTEMD_USER_DIR/traefik-test.socket"
cp systemd/http-test.socket "$SYSTEMD_USER_DIR/"
cp systemd/traefik-test.socket "$SYSTEMD_USER_DIR/"
chown podman:podman "$SYSTEMD_USER_DIR"/*.socket

echo "Copying Quadlet container files..."
# Remove existing files and copy new ones
rm -f "$QUADLET_DIR/traefik-test.container"
rm -f "$QUADLET_DIR/whoami-test.container"
cp quadlets/traefik-test.container "$QUADLET_DIR/"
cp quadlets/whoami-test.container "$QUADLET_DIR/"
chown podman:podman "$QUADLET_DIR"/*.container

# Create logs directory
mkdir -p /srv/apps/deploy/traefik/logs
chmod 755 /srv/apps/deploy/traefik/logs
chown podman:podman /srv/apps/deploy/traefik/logs

# Ensure data directory exists with correct permissions
mkdir -p /srv/apps/deploy/traefik/data
touch /srv/apps/deploy/traefik/data/acme.json
chmod 600 /srv/apps/deploy/traefik/data/acme.json
chown -R podman:podman /srv/apps/deploy/traefik/data

# Reload systemd to pick up new socket units and Quadlet files
echo "Reloading systemd configuration..."
sudo -u podman -i bash -c "systemctl --user daemon-reload"

# Enable and start all socket units as podman user
echo "Enabling and starting Traefik socket units..."
sudo -u podman -i bash -c "systemctl --user enable http-test.socket traefik-test.socket"
sudo -u podman -i bash -c "systemctl --user start http-test.socket traefik-test.socket"

# Start whoami service as podman user
echo "Starting whoami service..."
sudo -u podman -i bash -c "systemctl --user start whoami-test.service"

echo "✅ Test environment deployed successfully with socket activation!"

# Get the actual IP address
LOCAL_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}' 2>/dev/null || echo "localhost")
echo "📊 Traefik dashboard should be available at: http://${LOCAL_IP}:8080"
echo "🌍 Whoami service available at: http://whoami.localhost"
echo "🔌 Socket activation: Traefik will start automatically on first request"

# Show status
echo "📋 Service status:"
sudo -u podman -i bash -c "systemctl --user --no-pager status http-test.socket traefik-test.socket whoami-test.service"

echo ""
echo "Note: Traefik service will start automatically via socket activation when traffic arrives"
echo "You can check if it's running with: sudo -u podman -i bash -c 'systemctl --user status traefik-test.service'"
echo "Socket status: sudo -u podman -i bash -c 'systemctl --user status http-test.socket traefik-test.socket'"
