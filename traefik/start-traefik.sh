#!/bin/bash

# Traefik Startup Script
# This script helps you set up and start Traefik reverse proxy

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
    echo -e "${BLUE}         Traefik Startup Script${NC}"
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

    if ! command -v docker &>/dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi

    print_info "All dependencies are available ✓"
}

check_environment_file() {
    print_step "Checking environment configuration..."

    if [[ ! -f "$ENV_FILE" ]]; then
        print_warning "Environment file not found!"
        echo ""
        read -p "Would you like to generate environment variables now? (y/n) [y]: " GENERATE_ENV
        GENERATE_ENV=${GENERATE_ENV:-y}

        if [[ "$GENERATE_ENV" == "y" || "$GENERATE_ENV" == "Y" ]]; then
            read -p "Use quick setup for development? (y/n) [y]: " USE_QUICK
            USE_QUICK=${USE_QUICK:-y}

            if [[ "$USE_QUICK" == "y" || "$USE_QUICK" == "Y" ]]; then
                ./generate-env-quick.sh
            else
                ./generate-env.sh
            fi
        else
            print_error "Environment file is required to start Traefik"
            exit 1
        fi
    else
        print_info "Environment file found ✓"
    fi
}

create_directories() {
    print_step "Creating required directories..."

    mkdir -p "${SCRIPT_DIR}/data"
    mkdir -p "${SCRIPT_DIR}/logs"

    # Set proper permissions for ACME file
    if [[ ! -f "${SCRIPT_DIR}/data/acme.json" ]]; then
        touch "${SCRIPT_DIR}/data/acme.json"
        chmod 600 "${SCRIPT_DIR}/data/acme.json"
        print_info "Created ACME file with secure permissions ✓"
    fi

    print_info "Directory structure created ✓"
}

choose_environment() {
    print_step "Environment Selection"
    echo ""

    # Check if environment is already specified in .env
    if grep -q "Environment: dev" "$ENV_FILE" 2>/dev/null; then
        ENV_TYPE="dev"
        print_info "Development environment detected"
    elif grep -q "Environment: prod" "$ENV_FILE" 2>/dev/null; then
        ENV_TYPE="prod"
        print_info "Production environment detected"
    else
        read -p "Choose environment (dev/prod) [dev]: " ENV_TYPE
        ENV_TYPE=${ENV_TYPE:-dev}
    fi
}

create_traefik_network() {
    print_step "Setting up Docker network..."

    if ! docker network ls | grep -q "traefik"; then
        docker network create traefik
        print_info "Traefik network created ✓"
    else
        print_info "Traefik network already exists ✓"
    fi
}

start_traefik() {
    print_step "Starting Traefik services..."

    cd "${SCRIPT_DIR}"

    # Choose the appropriate compose file
    if [[ "$ENV_TYPE" == "prod" ]]; then
        COMPOSE_FILE="docker-compose.prod.yml"
    else
        COMPOSE_FILE="docker-compose.dev.yml"
    fi

    if [[ ! -f "$COMPOSE_FILE" ]]; then
        print_error "Docker Compose file not found: $COMPOSE_FILE"
        exit 1
    fi

    # Start services
    if command -v docker-compose &>/dev/null; then
        docker-compose -f "$COMPOSE_FILE" up -d
    else
        docker compose -f "$COMPOSE_FILE" up -d
    fi

    print_info "Traefik started ✓"
}

check_traefik_health() {
    print_step "Checking Traefik health..."

    # Wait for Traefik to be ready
    echo "Waiting for Traefik to be ready..."
    sleep 10

    # Check if Traefik container is running
    if docker ps | grep -q "traefik-${ENV_TYPE}"; then
        print_info "Traefik container is running ✓"
    else
        print_warning "Traefik container might not be running properly"
    fi

    # Try to access Traefik API
    if [[ "$ENV_TYPE" == "dev" ]]; then
        if curl -s http://localhost:8080/api/version >/dev/null 2>&1; then
            print_info "Traefik API is accessible ✓"
        else
            print_warning "Traefik API might not be ready yet"
        fi
    fi
}

display_access_info() {
    echo ""
    print_step "Access Information"
    echo ""

    # Load environment variables
    if [[ -f "$ENV_FILE" ]]; then
        source "$ENV_FILE"
    fi

    if [[ "$ENV_TYPE" == "dev" ]]; then
        echo -e "${BLUE}Dashboard:${NC} http://localhost:8080"
        echo -e "${BLUE}Dashboard (domain):${NC} http://${TRAEFIK_DASHBOARD_DOMAIN:-traefik.localhost}:8080"
        echo -e "${BLUE}HTTP:${NC} http://localhost"
        echo -e "${BLUE}HTTPS:${NC} https://localhost"
    else
        echo -e "${BLUE}Dashboard:${NC} https://${TRAEFIK_DASHBOARD_DOMAIN}"
        echo -e "${BLUE}HTTP:${NC} http://your-domain.com (redirects to HTTPS)"
        echo -e "${BLUE}HTTPS:${NC} https://your-domain.com"
    fi

    if [[ -n "${TRAEFIK_DASHBOARD_USERS}" ]]; then
        echo -e "${BLUE}Dashboard Auth:${NC} Required (check .env file for credentials)"
    fi

    echo ""
    echo -e "${GREEN}✓ Traefik is running successfully!${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "• Add Traefik labels to your application services"
    echo "• Configure DNS records for your domains (production)"
    echo "• Monitor logs: docker logs traefik-${ENV_TYPE}"
    echo ""
}

display_troubleshooting() {
    echo -e "${BLUE}Troubleshooting:${NC}"
    echo "• Check logs: docker logs traefik-${ENV_TYPE}"
    echo "• Restart: docker restart traefik-${ENV_TYPE}"
    echo "• Stop: docker-compose -f docker-compose.${ENV_TYPE}.yml down"
    echo ""
}

# Main execution
main() {
    print_header
    check_dependencies
    check_environment_file
    create_directories
    choose_environment
    create_traefik_network
    start_traefik
    check_traefik_health
    display_access_info
    display_troubleshooting
}

# Run main function
main "$@"
