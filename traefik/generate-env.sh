#!/bin/bash

# Traefik Environment Variables Generator
# This script generates all required environment variables for Traefik
# with secure defaults and prompts for user-specific configuration

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

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}      Traefik Environment Generator${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    print_step "Checking dependencies..."

    if ! command -v htpasswd &>/dev/null; then
        print_warning "htpasswd not found. Installing..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if command -v brew &>/dev/null; then
                brew install httpd
            else
                print_error "Please install Homebrew or htpasswd manually"
                exit 1
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command -v apt-get &>/dev/null; then
                sudo apt-get update && sudo apt-get install -y apache2-utils
            elif command -v yum &>/dev/null; then
                sudo yum install -y httpd-tools
            else
                print_error "Please install htpasswd manually"
                exit 1
            fi
        fi
    fi

    print_info "All dependencies are available ✓"
}

prompt_for_environment() {
    echo ""
    print_step "Environment Configuration"
    echo ""

    # Environment type
    read -p "Choose environment type (dev/prod) [dev]: " ENV_TYPE
    ENV_TYPE=${ENV_TYPE:-dev}

    if [[ "$ENV_TYPE" == "prod" ]]; then
        LOG_LEVEL="WARN"
        API_INSECURE="false"
    else
        LOG_LEVEL="INFO"
        API_INSECURE="true"
    fi
}

prompt_for_domains() {
    echo ""
    print_step "Domain Configuration"
    echo ""

    if [[ "$ENV_TYPE" == "prod" ]]; then
        read -p "Enter your main domain (e.g., yourdomain.com): " MAIN_DOMAIN
        if [[ -z "$MAIN_DOMAIN" ]]; then
            print_error "Domain is required for production environment"
            exit 1
        fi

        read -p "Enter Traefik dashboard subdomain [traefik]: " DASHBOARD_SUBDOMAIN
        DASHBOARD_SUBDOMAIN=${DASHBOARD_SUBDOMAIN:-traefik}
        DASHBOARD_DOMAIN="${DASHBOARD_SUBDOMAIN}.${MAIN_DOMAIN}"

        read -p "Enter metrics subdomain [metrics]: " METRICS_SUBDOMAIN
        METRICS_SUBDOMAIN=${METRICS_SUBDOMAIN:-metrics}
        METRICS_DOMAIN="${METRICS_SUBDOMAIN}.${MAIN_DOMAIN}"

        ALLOWED_ORIGINS="https://${MAIN_DOMAIN},https://www.${MAIN_DOMAIN}"
    else
        MAIN_DOMAIN="localhost"
        DASHBOARD_DOMAIN="traefik.localhost"
        METRICS_DOMAIN="metrics.localhost"
        ALLOWED_ORIGINS="http://localhost,https://localhost"
    fi
}

prompt_for_email() {
    echo ""
    print_step "Let's Encrypt Configuration"
    echo ""

    if [[ "$ENV_TYPE" == "prod" ]]; then
        read -p "Enter your email for Let's Encrypt certificates: " LETSENCRYPT_EMAIL
        if [[ -z "$LETSENCRYPT_EMAIL" ]]; then
            print_error "Email is required for Let's Encrypt certificates"
            exit 1
        fi

        # Validate email format
        if [[ ! "$LETSENCRYPT_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            print_error "Invalid email format"
            exit 1
        fi
    else
        LETSENCRYPT_EMAIL="dev@localhost"
        print_info "Using development email: $LETSENCRYPT_EMAIL"
    fi
}

generate_dashboard_auth() {
    print_step "Generating dashboard authentication..."

    read -p "Enter username for Traefik dashboard [admin]: " DASHBOARD_USERNAME
    DASHBOARD_USERNAME=${DASHBOARD_USERNAME:-admin}

    read -s -p "Enter password for Traefik dashboard: " DASHBOARD_PASSWORD
    echo ""

    if [[ -z "$DASHBOARD_PASSWORD" ]]; then
        print_error "Password cannot be empty"
        exit 1
    fi

    # Generate htpasswd hash
    DASHBOARD_USERS=$(htpasswd -nb "$DASHBOARD_USERNAME" "$DASHBOARD_PASSWORD")

    # Escape special characters for docker-compose
    DASHBOARD_USERS=$(echo "$DASHBOARD_USERS" | sed 's/\$/\$\$/g')

    print_info "Generated dashboard authentication ✓"
}

prompt_for_monitoring() {
    echo ""
    print_step "Monitoring Configuration"
    echo ""

    read -p "Enable Prometheus metrics? (y/n) [y]: " ENABLE_PROMETHEUS
    ENABLE_PROMETHEUS=${ENABLE_PROMETHEUS:-y}

    read -p "Enable access logs? (y/n) [y]: " ENABLE_ACCESS_LOG
    ENABLE_ACCESS_LOG=${ENABLE_ACCESS_LOG:-y}

    if [[ "$ENABLE_PROMETHEUS" == "y" || "$ENABLE_PROMETHEUS" == "Y" ]]; then
        PROMETHEUS_ENABLED="true"
    else
        PROMETHEUS_ENABLED="false"
    fi

    if [[ "$ENABLE_ACCESS_LOG" == "y" || "$ENABLE_ACCESS_LOG" == "Y" ]]; then
        ACCESS_LOG_ENABLED="true"
    else
        ACCESS_LOG_ENABLED="false"
    fi
}

create_env_file() {
    print_step "Creating .env file..."

    # Backup existing .env if it exists
    if [[ -f "$ENV_FILE" ]]; then
        cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        print_warning "Existing .env file backed up"
    fi

    # Create new .env file
    cat >"$ENV_FILE" <<EOF
# Traefik Configuration
# Generated on $(date)
# Environment: $ENV_TYPE

# Basic Configuration
TRAEFIK_LOG_LEVEL=$LOG_LEVEL
TRAEFIK_API_DASHBOARD=true
TRAEFIK_API_INSECURE=$API_INSECURE

# Let's Encrypt Configuration
LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL

# Domain Configuration
TRAEFIK_DASHBOARD_DOMAIN=$DASHBOARD_DOMAIN
TRAEFIK_METRICS_DOMAIN=$METRICS_DOMAIN

# Dashboard Authentication
TRAEFIK_DASHBOARD_USERS=$DASHBOARD_USERS

# CORS Configuration
ALLOWED_ORIGINS=$ALLOWED_ORIGINS

# Network Configuration
TRAEFIK_NETWORK=traefik

# Monitoring Configuration
PROMETHEUS_ENABLED=$PROMETHEUS_ENABLED
ACCESS_LOG_ENABLED=$ACCESS_LOG_ENABLED

# Rate Limiting Defaults
DEFAULT_RATE_LIMIT_BURST=100
DEFAULT_RATE_LIMIT_AVERAGE=50

# Security Headers
SECURITY_FRAME_DENY=true
SECURITY_CONTENT_TYPE_NOSNIFF=true
SECURITY_BROWSER_XSS_FILTER=true
SECURITY_FORCE_STS_HEADER=true
SECURITY_STS_SECONDS=31536000

EOF

    print_info "Environment file created: $ENV_FILE ✓"
}

create_traefik_network() {
    print_step "Creating Traefik network..."

    if ! docker network ls | grep -q "traefik"; then
        docker network create traefik
        print_info "Traefik network created ✓"
    else
        print_info "Traefik network already exists ✓"
    fi
}

display_summary() {
    echo ""
    print_step "Configuration Summary"
    echo ""
    echo -e "${BLUE}Environment Type:${NC} $ENV_TYPE"
    echo -e "${BLUE}Dashboard Domain:${NC} $DASHBOARD_DOMAIN"
    echo -e "${BLUE}Metrics Domain:${NC} $METRICS_DOMAIN"
    echo -e "${BLUE}Let's Encrypt Email:${NC} $LETSENCRYPT_EMAIL"
    echo -e "${BLUE}Dashboard User:${NC} $DASHBOARD_USERNAME"
    echo -e "${BLUE}Prometheus Enabled:${NC} $PROMETHEUS_ENABLED"
    echo -e "${BLUE}Access Logs Enabled:${NC} $ACCESS_LOG_ENABLED"
    echo ""
    echo -e "${GREEN}✓ All environment variables generated successfully!${NC}"
    echo ""
    echo -e "${YELLOW}Important Security Notes:${NC}"
    echo "• Keep your .env file secure and never commit it to version control"
    echo "• The dashboard password is hashed using bcrypt"
    echo "• SSL certificates will be automatically generated in production"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Review the generated .env file: $ENV_FILE"
    echo "2. Start Traefik using: docker-compose -f docker-compose.${ENV_TYPE}.yml up -d"
    echo "3. Access dashboard at: https://$DASHBOARD_DOMAIN"
    echo ""
}

# Main execution
main() {
    print_header
    check_dependencies
    prompt_for_environment
    prompt_for_domains
    prompt_for_email
    generate_dashboard_auth
    prompt_for_monitoring
    create_env_file
    create_traefik_network
    display_summary
}

# Run main function
main "$@"
