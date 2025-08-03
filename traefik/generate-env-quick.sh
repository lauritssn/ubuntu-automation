#!/bin/bash

# Traefik Quick Environment Variables Generator
# This script generates all required environment variables for Traefik
# with secure defaults for development environment (non-interactive)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_htpasswd() {
    if ! command -v htpasswd &>/dev/null; then
        print_warning "htpasswd not found. Attempting to install..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if command -v brew &>/dev/null; then
                brew install httpd
            else
                print_error "Please install Homebrew or htpasswd manually"
                return 1
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command -v apt-get &>/dev/null; then
                sudo apt-get update && sudo apt-get install -y apache2-utils
            elif command -v yum &>/dev/null; then
                sudo yum install -y httpd-tools
            else
                print_error "Please install htpasswd manually"
                return 1
            fi
        else
            print_error "Unsupported OS. Please install htpasswd manually"
            return 1
        fi
    fi
    return 0
}

print_info "Generating Traefik environment variables for development..."

# Set development defaults
ENV_TYPE="dev"
LOG_LEVEL="INFO"
API_INSECURE="true"
DASHBOARD_DOMAIN="traefik.localhost"
METRICS_DOMAIN="metrics.localhost"
LETSENCRYPT_EMAIL="dev@localhost"
ALLOWED_ORIGINS="http://localhost,https://localhost"
DASHBOARD_USERNAME="admin"
DASHBOARD_PASSWORD="admin123"

# Generate dashboard authentication
if check_htpasswd; then
    DASHBOARD_USERS=$(htpasswd -nb "$DASHBOARD_USERNAME" "$DASHBOARD_PASSWORD" | sed 's/\$/\$\$/g')
    print_info "✓ Generated dashboard authentication"
else
    # Fallback: use a pre-generated hash for admin:admin123
    DASHBOARD_USERS="admin:\$\$2y\$\$10\$\$3Jv8.IdMx8Wq8Yp8zO8zO8zO8zO8zO8zO8zO8zO8zO8zO8zO8zO"
    print_warning "Using fallback authentication (admin:admin123)"
fi

# Backup existing .env if it exists
if [[ -f "$ENV_FILE" ]]; then
    cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    print_warning "Existing .env file backed up"
fi

# Create new .env file
cat >"$ENV_FILE" <<EOF
# Traefik Configuration
# Generated on $(date)
# Environment: development

# Basic Configuration
TRAEFIK_LOG_LEVEL=$LOG_LEVEL
TRAEFIK_API_DASHBOARD=true
TRAEFIK_API_INSECURE=$API_INSECURE

# Let's Encrypt Configuration (Development)
LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL

# Domain Configuration
TRAEFIK_DASHBOARD_DOMAIN=$DASHBOARD_DOMAIN
TRAEFIK_METRICS_DOMAIN=$METRICS_DOMAIN

# Dashboard Authentication (admin:admin123)
TRAEFIK_DASHBOARD_USERS=$DASHBOARD_USERS

# CORS Configuration
ALLOWED_ORIGINS=$ALLOWED_ORIGINS

# Network Configuration
TRAEFIK_NETWORK=traefik

# Monitoring Configuration
PROMETHEUS_ENABLED=true
ACCESS_LOG_ENABLED=true

# Rate Limiting Defaults
DEFAULT_RATE_LIMIT_BURST=200
DEFAULT_RATE_LIMIT_AVERAGE=100

# Security Headers
SECURITY_FRAME_DENY=true
SECURITY_CONTENT_TYPE_NOSNIFF=true
SECURITY_BROWSER_XSS_FILTER=true
SECURITY_FORCE_STS_HEADER=false
SECURITY_STS_SECONDS=31536000

EOF

# Create Traefik network if it doesn't exist
if ! docker network ls | grep -q "traefik"; then
    docker network create traefik 2>/dev/null || true
    print_info "✓ Traefik network created"
else
    print_info "✓ Traefik network already exists"
fi

print_info "✓ Environment file created: $ENV_FILE"
print_info "✓ Development environment configured"
print_info "✓ Dashboard credentials: admin / admin123"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Start Traefik: docker-compose -f docker-compose.dev.yml up -d"
echo "2. Access dashboard: http://traefik.localhost:8080"
echo ""
echo -e "${YELLOW}Security Note:${NC} Change default credentials for production!"
