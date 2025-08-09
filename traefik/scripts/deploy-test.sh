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

# Ensure podman user session is properly established first
echo "Ensuring podman user session state..."
loginctl enable-linger podman 2>/dev/null || true

# Stop any existing services as podman user first
echo "Stopping existing services..."
sudo -u podman -i bash -c "source ~/.bashrc && systemctl --user stop whoami-test.service traefik-test.service 2>/dev/null || true"
sudo -u podman -i bash -c "source ~/.bashrc && systemctl --user stop http-test.socket traefik-test.socket 2>/dev/null || true"

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

# Create base deployment directory
DEPLOY_DIR="/srv/apps/deploy/traefik"
mkdir -p "$DEPLOY_DIR"

# Copy Traefik configuration file
echo "Copying Traefik test configuration..."
cp traefik-test.yml "$DEPLOY_DIR/"
chown podman:podman "$DEPLOY_DIR/traefik-test.yml"
chmod 644 "$DEPLOY_DIR/traefik-test.yml"

# Copy dynamic configuration folder
echo "Copying dynamic configuration..."
cp -r dynamic "$DEPLOY_DIR/"
chown -R podman:podman "$DEPLOY_DIR/dynamic"
find "$DEPLOY_DIR/dynamic" -type d -exec chmod 755 {} \;
find "$DEPLOY_DIR/dynamic" -type f -exec chmod 644 {} \;

# Create plugins-storage directory structure
echo "Creating plugins storage directory..."
mkdir -p "$DEPLOY_DIR/plugins-storage/archives"
mkdir -p "$DEPLOY_DIR/plugins-storage/sources"
chown -R podman:podman "$DEPLOY_DIR/plugins-storage"
chmod -R 755 "$DEPLOY_DIR/plugins-storage"

# Create logs directory
echo "Creating logs directory..."
mkdir -p "$DEPLOY_DIR/logs"
chmod 755 "$DEPLOY_DIR/logs"
chown podman:podman "$DEPLOY_DIR/logs"

# Ensure data directory exists with correct permissions
echo "Setting up data directory..."
mkdir -p "$DEPLOY_DIR/data"
touch "$DEPLOY_DIR/data/acme.json"
chmod 600 "$DEPLOY_DIR/data/acme.json"
chown -R podman:podman "$DEPLOY_DIR/data"

echo "✅ Files deployed successfully!"

# Get the actual IP address
LOCAL_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}' 2>/dev/null || echo "localhost")
echo "📊 Traefik dashboard should be available at: http://${LOCAL_IP}:8080"
echo "🌍 Whoami service available at: http://whoami.localhost"
echo "🔌 Socket activation: Traefik will start automatically on first request"

echo ""
echo "⚠️  Manual steps required to complete deployment:"
echo "❗ IMPORTANT: These commands must be run as the podman user, NOT as root!"
echo ""
echo "1. Switch to podman user and reload systemd:"
echo "   systemctl --user daemon-reload"
echo ""
echo "2. Enable and start socket units:"
echo "   systemctl --user enable http-test.socket traefik-test.socket"
echo "   systemctl --user start http-test.socket traefik-test.socket"
echo ""
echo "3. Start whoami service:"
echo "   systemctl --user start whoami-test.service"
echo ""
echo "4. Check status:"
echo "   systemctl --user status http-test.socket traefik-test.socket whoami-test.service"
