#!/bin/bash

##########################################################################################
## Subscript Runner - Run individual subscripts with proper dependencies
##########################################################################################

##########################################################################################
## Source shared helper functions
##########################################################################################

# Set BASEDIR early for shared functions to use
export BASEDIR=$(pwd)

# Source the shared helper functions
if [ -f "$BASEDIR/utils/shared_functions.sh" ]; then
    source "$BASEDIR/utils/shared_functions.sh"
else
    echo "❌ ERROR: Shared functions script not found at $BASEDIR/utils/shared_functions.sh"
    exit 1
fi

# Check if running as root
check_root

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
## Set up additional environment variables for subscripts
##########################################################################################

# Default installation choices (can be overridden by environment)
export DO_SSH_2FA="${DO_SSH_2FA:-Y}"
export DO_WIREGUARD_INSTALL="${DO_WIREGUARD_INSTALL:-N}"
export DO_NETDATA_INSTALL="${DO_NETDATA_INSTALL:-N}"
export DO_DOCKER_INSTALL="${DO_DOCKER_INSTALL:-N}"

# Ensure directories are created (shared functions handles this)
ensure_directories

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
