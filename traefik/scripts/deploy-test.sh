#!/bin/bash
set -euo pipefail

# Deploy Traefik Test Environment using Quadlets
echo "Deploying Traefik Test Environment with Quadlets..."

# Ensure we're in the right directory
cd "$(dirname "$0")/.."

# Copy Quadlet files to user systemd directory
QUADLET_DIR="$HOME/.config/containers/systemd"
mkdir -p "$QUADLET_DIR"

echo "Copying Quadlet files..."
cp quadlets/traefik-test.socket "$QUADLET_DIR/"
cp quadlets/traefik-test.container "$QUADLET_DIR/"
cp quadlets/hello-world-test.container "$QUADLET_DIR/"

# Create logs directory
mkdir -p logs
chmod 755 logs

# Ensure data directory exists with correct permissions
mkdir -p data
touch data/acme.json
chmod 600 data/acme.json

# Reload systemd to pick up new Quadlet files
echo "Reloading systemd configuration..."
systemctl --user daemon-reload

# Enable and start socket (this will start the service on first connection)
echo "Starting Traefik socket..."
systemctl --user enable traefik-test.socket
systemctl --user start traefik-test.socket

# Start hello-world service
echo "Starting hello-world service..."
systemctl --user start hello-world-test.service

echo "✅ Test environment deployed successfully!"

# Get the actual IP address
LOCAL_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}' 2>/dev/null || echo "localhost")
echo "📊 Traefik dashboard should be available at: http://${LOCAL_IP}:8080"
echo "🌍 Hello world service available at: http://hello.${APP_DOMAIN:-localhost}"

# Show status
echo "📋 Service status:"
systemctl --user --no-pager status traefik-test.socket hello-world-test.service
