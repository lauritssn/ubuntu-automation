#!/bin/bash

##########################################################################################
## Subscript Runner - Run individual subscripts with proper dependencies
##########################################################################################

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Check if subscript argument provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <subscript_name>"
    echo "Example: $0 maldet_install.sh"
    echo ""
    echo "Available subscripts:"
    ls -1 subscripts/*.sh | sed 's/subscripts\//  /'
    exit 1
fi

SUBSCRIPT="$1"

# Check if subscript exists
if [ ! -f "subscripts/$SUBSCRIPT" ]; then
    echo "Error: subscript 'subscripts/$SUBSCRIPT' not found"
    exit 1
fi

##########################################################################################
## Set up environment variables (from install.sh)
##########################################################################################

# Basic paths and variables
export BASEDIR=$(pwd)
export LOGDIR="/srv/apps/logs"
export BACKUPDIR="/srv/apps/backups"
export SCRIPTSDIR="/srv/apps/scripts"
export DATE=$(date +%Y-%m-%d_%H%M)
export DEBIAN_FRONTEND=noninteractive

# Create necessary directories
mkdir -p "$LOGDIR" "$BACKUPDIR" "$SCRIPTSDIR"

# Default email settings (you can override these)
export EMAIL_DOMAIN="${EMAIL_DOMAIN:-example.com}"
export INFO_EMAIL="${INFO_EMAIL:-admin@example.com}"

# Default timezone
export TIMEZONE="${TIMEZONE:-UTC}"

# Default installation choices (set to Y to enable features)
export DO_SSH_2FA="${DO_SSH_2FA:-Y}"
export DO_WIREGUARD_INSTALL="${DO_WIREGUARD_INSTALL:-N}"
export DO_NETDATA_INSTALL="${DO_NETDATA_INSTALL:-N}"
export DO_DOCKER_INSTALL="${DO_DOCKER_INSTALL:-N}"

##########################################################################################
## Define helper functions (from install.sh)
##########################################################################################

# Yellow
show_yellow() {
    echo $(tput bold)$(tput setaf 3) $@ $(tput sgr 0)
}

# White
show_norm() {
    echo $(tput bold)$(tput setaf 7) $@ $(tput sgr 0)
}

# Blue
show_info() {
    echo $(tput bold)$(tput setaf 4) $@ $(tput sgr 0)
}

# Green
show_warn() {
    echo $(tput bold)$(tput setaf 2) $@ $(tput sgr 0)
}

# Red
show_err() {
    echo $(tput bold)$(tput setaf 1) $@ $(tput sgr 0)
    exit 1
}

##########################################################################################
## Export functions so subscripts can use them
##########################################################################################

export -f show_yellow
export -f show_norm
export -f show_info
export -f show_warn
export -f show_err

##########################################################################################
## Run the subscript
##########################################################################################

echo "=========================================="
show_info "Running subscript: $SUBSCRIPT"
show_info "Log directory: $LOGDIR"
show_info "Email: $INFO_EMAIL"
echo "=========================================="
echo ""

# Make the subscript executable
chmod +x "subscripts/$SUBSCRIPT"

# Run the subscript
. "subscripts/$SUBSCRIPT"

echo ""
echo "=========================================="
show_info "Subscript completed: $SUBSCRIPT"
echo "=========================================="
