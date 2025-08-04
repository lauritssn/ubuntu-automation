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
cp quadlets/traefik.network "$QUADLET_DIR/"
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
systemctl --user daemon-reload

# Start network first
systemctl --user start traefik-network.service

# Start socket
systemctl --user start traefik-test.socket

# Start Traefik container
systemctl --user start traefik-test.service

# Start hello-world service
systemctl --user start hello-world-test.service

echo "Test environment deployed successfully!"
echo "Traefik dashboard should be available at: http://$(hostname):8080"
echo "Hello world service available at: http://hello.${APP_DOMAIN:-localhost}"

# Show status
systemctl --user --no-pager status traefik-test.service hello-world-test.service