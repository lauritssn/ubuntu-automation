#!/bin/bash
set -euo pipefail

# Deploy Traefik Test Environment using Quadlets with Socket Activation
echo "Deploying Traefik Test Environment with Quadlets and Socket Activation..."

# Ensure we're in the right directory
cd "$(dirname "$0")/.."

# Create systemd user directory for socket units
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
QUADLET_DIR="$HOME/.config/containers/systemd"
mkdir -p "$SYSTEMD_USER_DIR"
mkdir -p "$QUADLET_DIR"

echo "Copying systemd socket unit for Traefik..."
# Copy systemd socket unit (not Quadlet - regular systemd socket)
cp systemd/traefik-test.socket "$SYSTEMD_USER_DIR/"

echo "Copying Quadlet container files..."
cp quadlets/traefik-test.container "$QUADLET_DIR/"
cp quadlets/hello-world-test.container "$QUADLET_DIR/"

# Create logs directory
mkdir -p logs
chmod 755 logs

# Ensure data directory exists with correct permissions
mkdir -p data
touch data/acme.json
chmod 600 data/acme.json

# Reload systemd to pick up new socket unit and Quadlet files
echo "Reloading systemd configuration..."
systemctl --user daemon-reload

# Enable and start socket (this will automatically start the service when traffic arrives)
echo "Enabling and starting Traefik socket..."
systemctl --user enable traefik-test.socket
systemctl --user start traefik-test.socket

# Start hello-world service
echo "Starting hello-world service..."
systemctl --user start hello-world-test.service

echo "✅ Test environment deployed successfully with socket activation!"

# Get the actual IP address
LOCAL_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}' 2>/dev/null || echo "localhost")
echo "📊 Traefik dashboard should be available at: http://${LOCAL_IP}:8080"
echo "🌍 Hello world service available at: http://hello.${APP_DOMAIN:-localhost}"
echo "🔌 Socket activation: Traefik will start automatically on first request"

# Show status
echo "📋 Service status:"
systemctl --user --no-pager status traefik-test.socket hello-world-test.service

echo ""
echo "Note: Traefik service will start automatically via socket activation when traffic arrives"
echo "You can check if it's running with: systemctl --user status traefik-test.service"
