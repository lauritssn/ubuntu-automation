#!/bin/bash
set -euo pipefail

# Deploy Traefik Development Environment using Docker Compose
echo "Deploying Traefik Development Environment with Docker Compose..."

# Ensure we're in the right directory
cd "$(dirname "$0")/.."

# Create logs directory
mkdir -p logs
chmod 755 logs

# Ensure data directory exists with correct permissions
mkdir -p data
touch data/acme.json
chmod 600 data/acme.json

# Create network if it doesn't exist
docker network create traefik 2>/dev/null || true

# Load environment variables if .env exists
if [[ -f .env ]]; then
    echo "Loading environment from .env file..."
    set -a
    source .env
    set +a
fi

# Start the development stack
echo "Starting development stack..."
docker-compose -f docker-compose.dev.yml up -d

echo "Development environment deployed successfully!"
echo "Traefik dashboard available at: http://localhost:${TRAEFIK_DASHBOARD_PORT:-8080}"
echo "Alternative dashboard at: http://${TRAEFIK_DASHBOARD_DOMAIN:-traefik.localhost}"
echo "Hello world service available at: http://${HELLO_WORLD_DOMAIN:-hello.localhost}"

# Show status
docker-compose -f docker-compose.dev.yml ps