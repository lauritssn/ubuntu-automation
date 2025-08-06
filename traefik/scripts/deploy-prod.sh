#!/bin/bash
set -euo pipefail

# Deploy Traefik Production Environment using Quadlets
echo "Deploying Traefik Production Environment with Quadlets..."

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

# Copy Quadlet files to user systemd directory
QUADLET_DIR="$HOME/.config/containers/systemd"
mkdir -p "$QUADLET_DIR"

echo "Copying Quadlet files..."
cp quadlets/traefik.network "$QUADLET_DIR/"
cp quadlets/traefik-prod.socket "$QUADLET_DIR/"
cp quadlets/traefik-prod.container "$QUADLET_DIR/"
cp quadlets/whoami-prod.container "$QUADLET_DIR/"

# Create logs directory
mkdir -p logs
chmod 755 logs

# Ensure data directory exists with correct permissions
mkdir -p data
touch data/acme.json
chmod 600 data/acme.json

# Reload systemd to pick up new Quadlet files
systemctl --user daemon-reload

# Enable and start network first
systemctl --user enable traefik.service
systemctl --user start traefik.service

# Enable and start socket
systemctl --user enable traefik-prod.socket
systemctl --user start traefik-prod.socket

# Enable and start Traefik container
systemctl --user enable traefik-prod.service
systemctl --user start traefik-prod.service

# Enable and start whoami service
systemctl --user enable whoami-prod.service
systemctl --user start whoami-prod.service

# Wait for services to be ready
sleep 5
echo "Whoami service available at: https://whoami.${APP_DOMAIN}"

echo "Deployment complete! Checking service status..."
systemctl --user --no-pager status traefik-prod.service whoami-prod.service