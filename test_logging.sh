#!/bin/bash

echo "=== TESTING LOGGING FUNCTIONS ==="

# Copy the exact logging functions from install.sh
INSTALL_ID=$(date +%Y%m%d_%H%M%S)
JOURNAL_TAG="ubuntu-automation-${INSTALL_ID}"

# Function to log to both stdout and systemd journal
log_install() {
    local level="$1"
    local message="$2"
    local step="$3"
    
    echo "DEBUG: log_install called with level='$level' message='$message' step='$step'"
    
    # Log to systemd journal with structured data (if systemd-cat is available)
    if command -v systemd-cat >/dev/null 2>&1; then
        echo "DEBUG: About to call systemd-cat"
        echo "$message" | systemd-cat -t "$JOURNAL_TAG" -p "$level" \
            INSTALL_STEP="$step" \
            INSTALL_ID="$INSTALL_ID" \
            INSTALL_PHASE="main"
        echo "DEBUG: systemd-cat completed"
    fi
    
    # Also display to user
    echo "$message"
}

log_start() {
    echo "DEBUG: log_start called with: '$1'"
    log_install "info" "=== STARTING: $1 ===" "$1"
}

echo "Testing log_start function:"
log_start "Ubuntu 24.04 Automation Installation"

echo "=== LOGGING TEST COMPLETE ===" 