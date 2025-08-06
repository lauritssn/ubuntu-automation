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

echo "Copying systemd socket units for Traefik..."
# Copy separate socket units for each port
cp systemd/http-test.socket "$SYSTEMD_USER_DIR/"
cp systemd/https-test.socket "$SYSTEMD_USER_DIR/"
cp systemd/admin-test.socket "$SYSTEMD_USER_DIR/"

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

# Stop any existing services
echo "Stopping existing services..."
systemctl --user stop hello-world-test.service traefik-test.service 2>/dev/null || true
systemctl --user stop http-test.socket https-test.socket admin-test.socket 2>/dev/null || true

# Reload systemd to pick up new socket units and Quadlet files
echo "Reloading systemd configuration..."
systemctl --user daemon-reload

# Enable and start all socket units
echo "Enabling and starting Traefik socket units..."
systemctl --user enable http-test.socket https-test.socket admin-test.socket
systemctl --user start http-test.socket https-test.socket admin-test.socket

# Start hello-world service
echo "Starting hello-world service..."
systemctl --user start hello-world-test.service

echo "✅ Test environment deployed successfully with socket activation!"

# Get the actual IP address
LOCAL_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}' 2>/dev/null || echo "localhost")
echo "📊 Traefik dashboard should be available at: http://${LOCAL_IP}:8080"
echo "🌍 Hello world service available at: http://hello.localhost"
echo "🔌 Socket activation: Traefik will start automatically on first request"

# Show status
echo "📋 Service status:"
systemctl --user --no-pager status http-test.socket https-test.socket admin-test.socket hello-world-test.service

echo ""
echo "Note: Traefik service will start automatically via socket activation when traffic arrives"
echo "You can check if it's running with: systemctl --user status traefik-test.service"
echo "Socket status: systemctl --user status http-test.socket https-test.socket admin-test.socket"
