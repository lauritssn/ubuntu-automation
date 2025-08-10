#!/bin/bash
set -euo pipefail

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Deploy Traefik Production Environment using Quadlets with Socket Activation
echo "Deploying Traefik Production Environment with Quadlets and Socket Activation..."

# Ensure we're in the right directory
cd "$(dirname "$0")/.."

# Verify environment variables are set
if [[ -z "${LETSENCRYPT_EMAIL:-}" ]]; then
    echo "ERROR: LETSENCRYPT_EMAIL must be set"
    exit 1
fi

if [[ -z "${APP_DOMAIN:-}" ]]; then
    echo "ERROR: APP_DOMAIN must be set"
    exit 1
fi

# Ensure podman user session is properly established first
echo "Ensuring podman user session state..."
loginctl enable-linger podman 2>/dev/null || true

# Stop any existing services as podman user first
echo "Stopping existing services..."
sudo -u podman -i bash -c "source ~/.bashrc && systemctl --user stop whoami-prod.service traefik-prod.service 2>/dev/null || true"
sudo -u podman -i bash -c "source ~/.bashrc && systemctl --user stop http-prod.socket https-prod.socket traefik-prod.socket 2>/dev/null || true"

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
rm -f "$SYSTEMD_USER_DIR/http-prod.socket"
rm -f "$SYSTEMD_USER_DIR/https-prod.socket"
rm -f "$SYSTEMD_USER_DIR/traefik-prod.socket"
cp systemd/http-prod.socket "$SYSTEMD_USER_DIR/"
cp systemd/https-prod.socket "$SYSTEMD_USER_DIR/"
cp systemd/traefik-prod.socket "$SYSTEMD_USER_DIR/"
chown podman:podman "$SYSTEMD_USER_DIR"/*.socket

echo "Copying Quadlet container files..."
# Remove existing files and copy new ones
rm -f "$QUADLET_DIR/traefik-prod.container"
rm -f "$QUADLET_DIR/whoami-prod.container"
cp quadlets/traefik-prod.container "$QUADLET_DIR/"
cp quadlets/whoami-prod.container "$QUADLET_DIR/"
chown podman:podman "$QUADLET_DIR"/*.container

# Create base deployment directory
DEPLOY_DIR="/srv/apps/deploy/traefik"
mkdir -p "$DEPLOY_DIR"

# Copy Traefik configuration file
echo "Copying Traefik production configuration..."
cp traefik.yml "$DEPLOY_DIR/"
chown podman:podman "$DEPLOY_DIR/traefik.yml"
chmod 644 "$DEPLOY_DIR/traefik.yml"

# Copy dynamic configuration folder (prod and shared only)
echo "Copying dynamic configuration..."
mkdir -p "$DEPLOY_DIR/dynamic"
cp -r dynamic/prod "$DEPLOY_DIR/dynamic/"
cp -r dynamic/shared "$DEPLOY_DIR/dynamic/"
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
echo "📊 Traefik dashboard should be available at: https://traefik.${APP_DOMAIN} (with Let's Encrypt SSL)"
echo "🌍 Whoami service available at: https://whoami.${APP_DOMAIN}"
echo "🔌 Socket activation: Traefik will start automatically on first request"

echo ""
echo "⚠️  Manual steps required to complete deployment:"
echo "❗ IMPORTANT: These commands must be run as the podman user, NOT as root!"
echo ""
echo "1. Switch to podman user and reload systemd:"
echo "   systemctl --user daemon-reload"
echo ""
echo "2. Enable and start socket units:"
echo "   systemctl --user enable http-prod.socket https-prod.socket traefik-prod.socket"
echo "   systemctl --user start http-prod.socket https-prod.socket traefik-prod.socket"
echo ""
echo "3. Start whoami service:"
echo "   systemctl --user start whoami-prod.service"
echo ""
echo "4. Check status:"
echo "   systemctl --user status http-prod.socket https-prod.socket traefik-prod.socket whoami-prod.service"
