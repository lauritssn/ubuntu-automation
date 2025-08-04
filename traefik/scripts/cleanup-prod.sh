#!/bin/bash
set -euo pipefail

# Cleanup Traefik Production Environment
echo "Cleaning up Traefik Production Environment..."

# Stop and disable services
systemctl --user stop hello-world-prod.service 2>/dev/null || true
systemctl --user stop traefik-prod.service 2>/dev/null || true
systemctl --user stop traefik-prod.socket 2>/dev/null || true
systemctl --user stop traefik.service 2>/dev/null || true

systemctl --user disable hello-world-prod.service 2>/dev/null || true
systemctl --user disable traefik-prod.service 2>/dev/null || true
systemctl --user disable traefik-prod.socket 2>/dev/null || true
systemctl --user disable traefik.service 2>/dev/null || true

# Remove Quadlet files
QUADLET_DIR="$HOME/.config/containers/systemd"
rm -f "$QUADLET_DIR/hello-world-prod.container"
rm -f "$QUADLET_DIR/traefik-prod.container"
rm -f "$QUADLET_DIR/traefik-prod.socket"
rm -f "$QUADLET_DIR/traefik.network"

# Reload systemd
systemctl --user daemon-reload

# Remove containers if they exist
podman rm -f hello-world-prod traefik-prod 2>/dev/null || true

echo "Production environment cleanup completed!"