#!/bin/bash

# Dokku installation script
# This script installs Dokku on Ubuntu 24.04

show_info "Installing Dokku..."

# Download the installation script
wget -NP . https://dokku.com/bootstrap.sh

# Run the installer
sudo DOKKU_TAG=v0.35.20 bash bootstrap.sh

# Check if installation was successful
if [ $? -eq 0 ]; then
    show_warn "Dokku installation completed successfully"

    # Configure server domain if EMAIL_DOMAIN is available
    if [ -n "$EMAIL_DOMAIN" ]; then
        show_info "Configuring Dokku global domain to: $EMAIL_DOMAIN"
        dokku domains:set-global "$EMAIL_DOMAIN"
    else
        show_info "Configuring Dokku global domain to default: dokku.me"
        dokku domains:set-global dokku.me
    fi
else
    show_err "Dokku installation failed"
    exit 1
fi

show_info "Dokku installation completed"
