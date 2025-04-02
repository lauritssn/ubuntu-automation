#!/bin/bash

# Dokku installation script
# This script installs Dokku on Ubuntu 20.04

show_info "Installing Dokku..."

# Download and install Dokku bootstrap script
wget -NP . https://dokku.com/install/v0.35.16/bootstrap.sh
DOKKU_TAG=v0.35.16 bash bootstrap.sh

# Check if installation was successful
if [ $? -eq 0 ]; then
    show_warn "Dokku installation completed successfully"
else
    show_err "Dokku installation failed"
    exit 1
fi

show_info "Dokku installation completed"
