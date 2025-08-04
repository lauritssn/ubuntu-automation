#!/bin/bash
set -euo pipefail

# Cleanup Traefik Test Environment
echo "Cleaning up Traefik Test Environment..."

# Stop and disable services
systemctl --user stop hello-world-test.service 2>/dev/null || true
systemctl --user stop traefik-test.service 2>/dev/null || true
systemctl --user stop traefik-test.socket 2>/dev/null || true
systemctl --user stop traefik.service 2>/dev/null || true

systemctl --user disable hello-world-test.service 2>/dev/null || true
systemctl --user disable traefik-test.service 2>/dev/null || true
systemctl --user disable traefik-test.socket 2>/dev/null || true
systemctl --user disable traefik.service 2>/dev/null || true

# Remove Quadlet files
QUADLET_DIR="$HOME/.config/containers/systemd"
rm -f "$QUADLET_DIR/hello-world-test.container"
rm -f "$QUADLET_DIR/traefik-test.container"
rm -f "$QUADLET_DIR/traefik-test.socket"
rm -f "$QUADLET_DIR/traefik.network"

# Reload systemd
systemctl --user daemon-reload

# Remove containers if they exist
podman rm -f hello-world-test traefik-test 2>/dev/null || true

echo "Test environment cleanup completed!"