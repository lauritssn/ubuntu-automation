#!/bin/bash

##########################################################################################
## Ubuntu Automation - Shared Helper Functions
## Common functions used across all scripts in the automation suite
##########################################################################################

##########################################################################################
## Global Variables and Constants
##########################################################################################

# Set default paths if not already set
export AUTOMATION_ROOT="${AUTOMATION_ROOT:-/srv/apps}"
export LOGDIR="${LOGDIR:-/srv/apps/logs}"
export BACKUPDIR="${BACKUPDIR:-/srv/apps/backups}"
export SCRIPTSDIR="${SCRIPTSDIR:-/srv/apps/scripts}"
export DATE="${DATE:-$(date +%Y-%m-%d_%H%M)}"
export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

# Default email settings
export EMAIL_DOMAIN="${EMAIL_DOMAIN:-example.com}"
export INFO_EMAIL="${INFO_EMAIL:-admin@example.com}"

# Default timezone
export TIMEZONE="${TIMEZONE:-UTC}"

##########################################################################################
## Core Utility Functions
##########################################################################################

# Check if script is running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        show_err "This script must be run as root (use sudo)"
    fi
}

# Create necessary directories
ensure_directories() {
    mkdir -p "$LOGDIR" "$BACKUPDIR" "$SCRIPTSDIR"
    chmod 755 "$LOGDIR" "$BACKUPDIR" "$SCRIPTSDIR"
}

# Generate secure password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-16
}

# Validate username format
validate_username() {
    local username="$1"

    # Check if username is provided
    if [ -z "$username" ]; then
        show_err "Username cannot be empty."
        return 1
    fi

    # Check username format (alphanumeric, dashes, underscores, 3-32 chars)
    if ! [[ "$username" =~ ^[a-zA-Z0-9_-]{3,32}$ ]]; then
        show_err "Username must be 3-32 characters and contain only letters, numbers, dashes, and underscores."
        return 1
    fi

    # Check if user already exists
    if id "$username" &>/dev/null; then
        show_err "User '$username' already exists."
        return 1
    fi

    return 0
}

##########################################################################################
## Color Output Functions
##########################################################################################

# Yellow/Blue (info messages)
show_yellow() {
    echo $(tput bold)$(tput setaf 4) $@ $(tput sgr 0)
}

# White/Normal (normal messages)
show_norm() {
    echo $(tput bold)$(tput setaf 7) $@ $(tput sgr 0)
}

# Blue (info messages - alias for show_yellow for consistency)
show_info() {
    echo $(tput bold)$(tput setaf 4) $@ $(tput sgr 0)
}

# Green (warning/success messages)
show_warn() {
    echo $(tput bold)$(tput setaf 2) $@ $(tput sgr 0)
}

# Red (error messages)
show_err() {
    echo $(tput bold)$(tput setaf 1) $@ $(tput sgr 0)
    exit 1
}

# Red error without exit (for cases where we want to continue)
show_error_no_exit() {
    echo $(tput bold)$(tput setaf 1) $@ $(tput sgr 0)
}

##########################################################################################
## Logging Functions (Enhanced for systemd integration)
##########################################################################################

# Initialize systemd journal logging (if available)
init_logging() {
    local script_name="$1"
    local install_id="${2:-$(date +%Y%m%d_%H%M%S)}"
    
    export JOURNAL_TAG="ubuntu-automation-${install_id}"
    export CURRENT_SCRIPT="$script_name"
    
    # Log to systemd journal if available
    if command -v systemd-cat >/dev/null 2>&1; then
        export SYSTEMD_LOGGING_AVAILABLE=true
    else
        export SYSTEMD_LOGGING_AVAILABLE=false
    fi
}

# Enhanced logging function that supports systemd journal
log_message() {
    local level="$1"
    local message="$2"
    local step="${3:-general}"

    # Log to systemd journal if available
    if [ "$SYSTEMD_LOGGING_AVAILABLE" = "true" ] && [ -n "$JOURNAL_TAG" ]; then
        echo "$message" | systemd-cat -t "$JOURNAL_TAG" -p "$level"
    fi

    # Also display to user with appropriate formatting
    case "$level" in
        "info")
            show_info "$message"
            ;;
        "warning")
            show_warn "$message"
            ;;
        "err"|"error")
            show_error_no_exit "$message"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Convenience logging functions
log_start() {
    log_message "info" "=== STARTING: $1 ===" "$1"
}

log_success() {
    log_message "info" "✅ SUCCESS: $1" "$1"
}

log_warning() {
    log_message "warning" "⚠️  WARNING: $1" "$1"
}

log_error() {
    log_message "err" "❌ ERROR: $1" "$1"
}

log_info() {
    log_message "info" "ℹ️  INFO: $1" "$1"
}

##########################################################################################
## Installation Status Tracking Functions
##########################################################################################

# Installation status log file
export INSTALL_STATUS_LOG="/srv/apps/scripts/installation_status.log"

# Initialize the installation status log
init_install_status_log() {
    ensure_directories
    
    if [ ! -f "$INSTALL_STATUS_LOG" ]; then
        cat >"$INSTALL_STATUS_LOG" <<EOF
# Ubuntu Automation Installation Status Log
# Format: MODULE_NAME=STATUS
# STATUS: SUCCESS, FAILED, SKIPPED
# Generated on: $(date)
EOF
        chmod 600 "$INSTALL_STATUS_LOG"
        log_info "Created new installation status log: $INSTALL_STATUS_LOG"
    else
        log_info "Using existing installation status log: $INSTALL_STATUS_LOG"
    fi
}

# Check if a module has been successfully installed
is_module_installed() {
    local module_name="$1"
    if [ -f "$INSTALL_STATUS_LOG" ]; then
        grep -q "^${module_name}=SUCCESS$" "$INSTALL_STATUS_LOG" 2>/dev/null
        return $?
    fi
    return 1 # Not installed
}

# Mark a module as successfully installed
mark_module_success() {
    local module_name="$1"
    local temp_file=$(mktemp)

    # Remove any existing entry for this module
    if [ -f "$INSTALL_STATUS_LOG" ]; then
        grep -v "^${module_name}=" "$INSTALL_STATUS_LOG" >"$temp_file" 2>/dev/null || touch "$temp_file"
    else
        touch "$temp_file"
    fi

    # Add new success entry
    echo "${module_name}=SUCCESS" >>"$temp_file"
    mv "$temp_file" "$INSTALL_STATUS_LOG"
    chmod 600 "$INSTALL_STATUS_LOG"

    log_info "Module '$module_name' marked as successfully installed"
}

# Mark a module as failed
mark_module_failed() {
    local module_name="$1"
    local temp_file=$(mktemp)

    # Remove any existing entry for this module
    if [ -f "$INSTALL_STATUS_LOG" ]; then
        grep -v "^${module_name}=" "$INSTALL_STATUS_LOG" >"$temp_file" 2>/dev/null || touch "$temp_file"
    else
        touch "$temp_file"
    fi

    # Add new failed entry
    echo "${module_name}=FAILED" >>"$temp_file"
    mv "$temp_file" "$INSTALL_STATUS_LOG"
    chmod 600 "$INSTALL_STATUS_LOG"

    log_error "Module '$module_name' marked as failed"
}

# Mark a module as skipped
mark_module_skipped() {
    local module_name="$1"
    local temp_file=$(mktemp)

    # Remove any existing entry for this module
    if [ -f "$INSTALL_STATUS_LOG" ]; then
        grep -v "^${module_name}=" "$INSTALL_STATUS_LOG" >"$temp_file" 2>/dev/null || touch "$temp_file"
    else
        touch "$temp_file"
    fi

    # Add new skipped entry
    echo "${module_name}=SKIPPED" >>"$temp_file"
    mv "$temp_file" "$INSTALL_STATUS_LOG"
    chmod 600 "$INSTALL_STATUS_LOG"

    log_info "Module '$module_name' marked as skipped"
}

##########################################################################################
## System Check Functions
##########################################################################################

# Check if 2FA is configured on the system
check_2fa_available() {
    if ! command -v google-authenticator >/dev/null 2>&1; then
        show_warn "Google Authenticator is not installed. 2FA setup will be skipped."
        return 1
    fi

    if ! grep -q "pam_google_authenticator.so" /etc/pam.d/sshd 2>/dev/null; then
        show_warn "SSH 2FA is not configured on this system. 2FA setup will be skipped."
        return 1
    fi

    return 0
}

# Check if WireGuard is available
check_wireguard_available() {
    if ! command -v wg >/dev/null 2>&1; then
        show_warn "WireGuard is not installed. VPN setup will be skipped."
        return 1
    fi

    if [ ! -f /etc/wireguard/wg0.conf ]; then
        show_warn "WireGuard server configuration not found. VPN setup will be skipped."
        return 1
    fi

    return 0
}

##########################################################################################
## Script Template Helper Functions
##########################################################################################

# Function to copy script template and replace variables
copy_and_configure_script() {
    local template_name="$1"
    local destination_path="$2"
    local script_name="$3"

    # Validate parameters
    if [ -z "$template_name" ] || [ -z "$destination_path" ]; then
        show_err "copy_and_configure_script requires template_name and destination_path"
        return 1
    fi

    local template_path="$BASEDIR/configs/script-templates/$template_name"

    # Check if template exists
    if [ ! -f "$template_path" ]; then
        show_err "Template $template_path not found"
        return 1
    fi

    show_yellow "Creating $script_name from template $template_name"

    # Copy template to destination
    cp "$template_path" "$destination_path"

    # Replace placeholder variables
    replace_script_variables "$destination_path"

    # Make script executable
    chmod +x "$destination_path"

    show_yellow "Script created and configured: $destination_path"
    return 0
}

# Function to replace placeholder variables in a script
replace_script_variables() {
    local script_path="$1"

    if [ ! -f "$script_path" ]; then
        show_err "Script file not found: $script_path"
        return 1
    fi

    # Replace common placeholder variables
    sed -i "s|{{SLACK_WEBHOOK_URL}}|${SLACK_WEBHOOK_URL:-}|g" "$script_path"
    sed -i "s|{{EMAIL_DOMAIN}}|${EMAIL_DOMAIN}|g" "$script_path"
    sed -i "s|{{INFO_EMAIL}}|${INFO_EMAIL}|g" "$script_path"
    sed -i "s|{{TIMEZONE}}|${TIMEZONE}|g" "$script_path"
    sed -i "s|{{SECURE_SUBNET}}|${SECURE_SUBNET:-}|g" "$script_path"
    sed -i "s|{{SECURE_SUBNET_DESC}}|${SECURE_SUBNET_DESC:-}|g" "$script_path"
    sed -i "s|{{LOGDIR}}|${LOGDIR}|g" "$script_path"
    sed -i "s|{{SCRIPTSDIR}}|${SCRIPTSDIR}|g" "$script_path"
    sed -i "s|{{BACKUPDIR}}|${BACKUPDIR}|g" "$script_path"

    return 0
}

##########################################################################################
## Module Execution Functions
##########################################################################################

# Execute a module with status tracking
execute_module() {
    local module_name="$1"
    local module_script="$2"
    local user_choice="$3"

    # Check if user chose to install this module (Y=Yes, M=Mandatory)
    if [[ ! $user_choice =~ [YyMm]$ ]]; then
        mark_module_skipped "$module_name"
        log_info "$module_name installation skipped by user choice"
        show_warn "$module_name will not be installed"
        return 0
    fi

    # Show different messages for mandatory vs optional installations
    if [[ $user_choice =~ [Mm]$ ]]; then
        log_info "$module_name is MANDATORY and will be installed automatically"
    fi

    # Check if module is already successfully installed
    if is_module_installed "$module_name"; then
        log_info "$module_name is already successfully installed, skipping..."
        show_warn "$module_name already installed successfully, skipping..."
        return 0
    fi

    # Execute the module
    log_start "$module_name"

    # Create a temporary error trap for this module
    set +e # Temporarily disable exit on error
    (
        set -e # Re-enable exit on error in subshell
        . "$module_script"
    )
    local exit_code=$?
    set -e # Re-enable exit on error

    if [ $exit_code -eq 0 ]; then
        mark_module_success "$module_name"
        log_success "$module_name"
        show_yellow "$module_name installation completed successfully"
    else
        mark_module_failed "$module_name"
        log_error "$module_name installation failed with exit code $exit_code"
        show_error_no_exit "$module_name installation failed. Check logs for details."
        echo "❌ $module_name failed. You can retry by running the script again."
        echo "   Only failed/new modules will be reinstalled."

        # Ask user if they want to continue or exit
        while true; do
            read -p "Do you want to continue with other modules (Y/N)? " yn
            case $yn in
            [Yy]*)
                log_info "User chose to continue after $module_name failure"
                return 0 # Return success to continue with next modules
                ;;
            [Nn]*)
                log_info "User chose to exit after $module_name failure"
                exit 1
                ;;
            *) echo "Please answer yes or no." ;;
            esac
        done
    fi

    return $exit_code
}

##########################################################################################
## User Choice Management Functions
##########################################################################################

# User choices persistence file
USER_CHOICES_FILE="/srv/apps/scripts/user_choices.conf"

# Save user choices to file
save_user_choices() {
    ensure_directories
    
    cat >"$USER_CHOICES_FILE" <<EOF
# Ubuntu Automation User Choices
# Generated on: $(date)
DO_SET_TIMEZONE=${DO_SET_TIMEZONE:-N}
DO_SYSTEM_UPDATE=${DO_SYSTEM_UPDATE:-M}
DO_GENERAL_SERVER_SETTINGS=${DO_GENERAL_SERVER_SETTINGS:-M}
DO_SSH_2FA=${DO_SSH_2FA:-Y}
DO_SWAP_INSTALL=${DO_SWAP_INSTALL:-M}
DO_LIGHTWEIGHT_MONITORING=${DO_LIGHTWEIGHT_MONITORING:-M}
ENABLE_SLACK_MONITORING=${ENABLE_SLACK_MONITORING:-N}
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
DO_NETDATA_INSTALL=${DO_NETDATA_INSTALL:-N}
DO_SYSTEMD_TIMERS=${DO_SYSTEMD_TIMERS:-M}
DO_DOCKER_INSTALL=${DO_DOCKER_INSTALL:-N}
DOCKER_ROOTLESS=${DOCKER_ROOTLESS:-N}
DOCKER_DATA_ROOT="${DOCKER_DATA_ROOT:-/var/lib/docker}"
DO_UFW_INSTALL=${DO_UFW_INSTALL:-M}
DO_DOKKU_INSTALL=${DO_DOKKU_INSTALL:-N}
DO_WIREGUARD_INSTALL=${DO_WIREGUARD_INSTALL:-N}
WIREGUARD_SUBNET="${WIREGUARD_SUBNET:-10.66.66.0/24}"
EOF
    chmod 600 "$USER_CHOICES_FILE"
    log_info "User choices saved to: $USER_CHOICES_FILE"
}

# Load user choices from file
load_user_choices() {
    if [ -f "$USER_CHOICES_FILE" ]; then
        source "$USER_CHOICES_FILE"
        log_info "User choices loaded from: $USER_CHOICES_FILE"
        return 0
    fi
    return 1
}

# Check if we're resuming (have failed modules)
is_resuming() {
    if [ -f "$INSTALL_STATUS_LOG" ]; then
        grep -q "=FAILED$" "$INSTALL_STATUS_LOG" 2>/dev/null
        return $?
    fi
    return 1
}

##########################################################################################
## Display Functions
##########################################################################################

# Display installation status summary
show_install_status() {
    if [ ! -f "$INSTALL_STATUS_LOG" ]; then
        echo "No installation status log found."
        return
    fi

    echo ""
    echo "📋 INSTALLATION STATUS SUMMARY:"
    echo "=================================="

    local success_count=0
    local failed_count=0
    local skipped_count=0

    while IFS='=' read -r module status; do
        # Skip comments and empty lines
        if [[ "$module" =~ ^#.*$ ]] || [[ -z "$module" ]]; then
            continue
        fi

        case "$status" in
        "SUCCESS")
            echo "✅ $module: Successfully installed"
            ((success_count++))
            ;;
        "FAILED")
            echo "❌ $module: Installation failed"
            ((failed_count++))
            ;;
        "SKIPPED")
            echo "⏭️  $module: Skipped by user"
            ((skipped_count++))
            ;;
        esac
    done <"$INSTALL_STATUS_LOG"

    echo "=================================="
    echo "📊 SUMMARY: $success_count successful, $failed_count failed, $skipped_count skipped"

    if [ $failed_count -gt 0 ]; then
        echo ""
        echo "⚠️  Some modules failed. You can re-run this script to retry failed modules."
        echo "   Successfully installed modules will be skipped automatically."
    fi
    echo ""
}

##########################################################################################
## Export all functions for use by other scripts
##########################################################################################

# Export utility functions
export -f check_root
export -f ensure_directories
export -f generate_password
export -f validate_username

# Export color output functions
export -f show_yellow
export -f show_norm
export -f show_info
export -f show_warn
export -f show_err
export -f show_error_no_exit

# Export logging functions
export -f init_logging
export -f log_message
export -f log_start
export -f log_success
export -f log_warning
export -f log_error
export -f log_info

# Export installation status functions
export -f init_install_status_log
export -f is_module_installed
export -f mark_module_success
export -f mark_module_failed
export -f mark_module_skipped

# Export system check functions
export -f check_2fa_available
export -f check_wireguard_available

# Export script template functions
export -f copy_and_configure_script
export -f replace_script_variables

# Export module execution functions
export -f execute_module

# Export user choice functions
export -f save_user_choices
export -f load_user_choices
export -f is_resuming

# Export display functions
export -f show_install_status

##########################################################################################
## Initialization
##########################################################################################

# Auto-create directories when this script is sourced
ensure_directories

# Set default script name if not provided
if [ -z "$CURRENT_SCRIPT" ]; then
    export CURRENT_SCRIPT="$(basename "${BASH_SOURCE[1]:-unknown}")"
fi 