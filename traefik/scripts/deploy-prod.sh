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
cp quadlets/hello-world-prod.container "$QUADLET_DIR/"

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

# Enable and start hello-world service
systemctl --user enable hello-world-prod.service
systemctl --user start hello-world-prod.service

echo "Production environment deployed successfully!"
echo "Traefik dashboard should be available at: https://${TRAEFIK_DASHBOARD_DOMAIN:-traefik.${APP_DOMAIN}}"
echo "Hello world service available at: https://hello.${APP_DOMAIN}"

# Show status
systemctl --user --no-pager status traefik-prod.service hello-world-prod.service