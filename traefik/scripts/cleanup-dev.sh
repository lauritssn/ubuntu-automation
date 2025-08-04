#!/bin/bash
set -euo pipefail

# Cleanup Traefik Development Environment
echo "Cleaning up Traefik Development Environment..."

# Ensure we're in the right directory
cd "$(dirname "$0")/.."

# Stop and remove containers
docker-compose -f docker-compose.dev.yml down

# Remove network (only if no other containers are using it)
docker network rm traefik 2>/dev/null || echo "Network 'traefik' not removed (may be in use by other containers)"

echo "Development environment cleanup completed!"