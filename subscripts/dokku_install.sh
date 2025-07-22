#!/bin/bash

# Dokku installation script
# This script installs Dokku on Ubuntu 24.04

# Source helper functions if available
if [ -f "$BASEDIR/configs/script-templates/script_helper_functions.sh" ]; then
    source "$BASEDIR/configs/script-templates/script_helper_functions.sh"
fi

# Fallback function definitions if not sourced
if ! command -v show_info &>/dev/null; then
    show_info() { echo "INFO: $1"; }
    show_warn() { echo "WARN: $1"; }
    show_err() { echo "ERROR: $1"; }
fi

show_info "Installing Dokku..."

# Fix GPG key permissions issue first
show_info "Fixing GPG key permissions for Dokku repository..."
sudo mkdir -p /etc/apt/trusted.gpg.d
sudo chmod 755 /etc/apt/trusted.gpg.d

# Add the GPG key properly
curl -fsSL https://packagecloud.io/dokku/dokku/gpgkey | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/dokku.gpg
sudo chmod 644 /etc/apt/trusted.gpg.d/dokku.gpg

# Add the repository
echo "deb https://packagecloud.io/dokku/dokku/ubuntu/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/dokku.list

# Update package list
sudo apt-get update

# Install Dokku with specific version
show_info "Installing Dokku version v0.35.20..."
sudo apt-get install -y dokku=0.35.20-1

# Check if installation was successful
if [ $? -eq 0 ]; then
    show_warn "Dokku installation completed successfully"

    # Configure server domain if EMAIL_DOMAIN is available
    if [ -n "$EMAIL_DOMAIN" ]; then
        show_info "Configuring Dokku global domain to: $EMAIL_DOMAIN"
        sudo dokku domains:set-global "$EMAIL_DOMAIN"
    else
        show_info "Configuring Dokku global domain to default: dokku.me"
        sudo dokku domains:set-global dokku.me
    fi

    # Enable and start Dokku services
    sudo systemctl enable dokku-installer
    sudo systemctl start dokku-installer

    show_info "Dokku web installer is available at: http://$(hostname -I | awk '{print $1}')"
    show_info "Complete the setup through the web interface or use 'dokku' commands directly"
else
    show_err "Dokku installation failed"
    exit 1
fi

show_info "Dokku installation completed"
