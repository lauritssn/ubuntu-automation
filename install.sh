#!/bin/bash

printf "############################################\n"
printf "# Ubuntu 24.04 Install Automation #\n"
printf "############################################\n\n"

##########################################################################################
## Set bash options and logging
##########################################################################################
set -e # Exit on error
#set -x # Enable debugging

# Enhanced error handling
set -o pipefail # Exit on pipe failures
trap 'handle_error ${LINENO}' ERR

handle_error() {
    local line_no=$1
    echo "❌ ERROR: Script failed at line $line_no"
    echo "❌ ERROR: Last command: $BASH_COMMAND"
    echo "❌ ERROR: Exit code: $?"
    echo "❌ ERROR: Working directory: $(pwd)"
    echo "❌ ERROR: Environment variables:"
    echo "   BASEDIR: $BASEDIR"
    echo "   SCRIPTSDIR: $SCRIPTSDIR"
    echo "   LOGDIR: $LOGDIR"
    exit 1
}

# Initialize systemd journal logging for installation tracking
INSTALL_ID=$(date +%Y%m%d_%H%M%S)
JOURNAL_TAG="install-${INSTALL_ID}"

# Function to log to both stdout and systemd journal
log_install() {
    local level="$1"
    local message="$2"
    local step="$3"
    
    # Log to systemd journal with structured data (if systemd-cat is available)
    if command -v systemd-cat >/dev/null 2>&1; then
        echo "$message" | systemd-cat -t "$JOURNAL_TAG" -p "$level"
    fi
    
    # Also display to user
    echo "$message"
}

# Enhanced logging functions that integrate with systemd
log_start() {
    log_install "info" "=== STARTING: $1 ===" "$1"
}

log_success() {
    log_install "info" "✅ SUCCESS: $1" "$1"
}

log_warning() {
    log_install "warning" "⚠️  WARNING: $1" "$1"
}

log_error() {
    log_install "err" "❌ ERROR: $1" "$1"
}

log_info() {
    log_install "info" "ℹ️  INFO: $1" "$1"
}

##########################################################################################
## Installation Status Tracking System
##########################################################################################

# Installation status log file
export INSTALL_STATUS_LOG="/srv/apps/scripts/installation_status.log"

# Initialize the installation status log
init_install_status_log() {
    # Create scripts directory if it doesn't exist
    if [ ! -d "/srv/apps/scripts" ]; then
        mkdir -p "/srv/apps/scripts"
    fi
    
    # Create the status log if it doesn't exist
    if [ ! -f "$INSTALL_STATUS_LOG" ]; then
        cat > "$INSTALL_STATUS_LOG" << EOF
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
    return 1  # Not installed
}

# Mark a module as successfully installed
mark_module_success() {
    local module_name="$1"
    local temp_file=$(mktemp)
    
    # Remove any existing entry for this module
    if [ -f "$INSTALL_STATUS_LOG" ]; then
        grep -v "^${module_name}=" "$INSTALL_STATUS_LOG" > "$temp_file" 2>/dev/null || touch "$temp_file"
    else
        touch "$temp_file"
    fi
    
    # Add new success entry
    echo "${module_name}=SUCCESS" >> "$temp_file"
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
        grep -v "^${module_name}=" "$INSTALL_STATUS_LOG" > "$temp_file" 2>/dev/null || touch "$temp_file"
    else
        touch "$temp_file"
    fi
    
    # Add new failed entry
    echo "${module_name}=FAILED" >> "$temp_file"
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
        grep -v "^${module_name}=" "$INSTALL_STATUS_LOG" > "$temp_file" 2>/dev/null || touch "$temp_file"
    else
        touch "$temp_file"
    fi
    
    # Add new skipped entry
    echo "${module_name}=SKIPPED" >> "$temp_file"
    mv "$temp_file" "$INSTALL_STATUS_LOG"
    chmod 600 "$INSTALL_STATUS_LOG"
    
    log_info "Module '$module_name' marked as skipped"
}

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
    set +e  # Temporarily disable exit on error
    (
        set -e  # Re-enable exit on error in subshell
        . "$module_script"
    )
    local exit_code=$?
    set -e  # Re-enable exit on error
    
    if [ $exit_code -eq 0 ]; then
        mark_module_success "$module_name"
        log_success "$module_name"
        show_yellow "$module_name installation completed successfully"
    else
        mark_module_failed "$module_name"
        log_error "$module_name installation failed with exit code $exit_code"
        show_err "$module_name installation failed. Check logs for details."
        echo "❌ $module_name failed. You can retry by running the script again."
        echo "   Only failed/new modules will be reinstalled."
        
        # Ask user if they want to continue or exit
        while true; do
            read -p "Do you want to continue with other modules (Y/N)? " yn
            case $yn in
                [Yy]*)
                    log_info "User chose to continue after $module_name failure"
                    return 0  # Return success to continue with next modules
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
    done < "$INSTALL_STATUS_LOG"
    
    echo "=================================="
    echo "📊 SUMMARY: $success_count successful, $failed_count failed, $skipped_count skipped"
    
    if [ $failed_count -gt 0 ]; then
        echo ""
        echo "⚠️  Some modules failed. You can re-run this script to retry failed modules."
        echo "   Successfully installed modules will be skipped automatically."
    fi
    echo ""
}

# User choices persistence
USER_CHOICES_FILE="/srv/apps/scripts/user_choices.conf"

# Save user choices to file
save_user_choices() {
    cat > "$USER_CHOICES_FILE" << EOF
# Ubuntu Automation User Choices
# Generated on: $(date)
DO_SET_TIMEZONE=$DO_SET_TIMEZONE
DO_SYSTEM_UPDATE=$DO_SYSTEM_UPDATE
DO_GENERAL_SERVER_SETTINGS=$DO_GENERAL_SERVER_SETTINGS
DO_SSH_2FA=$DO_SSH_2FA
DO_SWAP_INSTALL=$DO_SWAP_INSTALL
DO_LIGHTWEIGHT_MONITORING=$DO_LIGHTWEIGHT_MONITORING
ENABLE_SLACK_MONITORING=$ENABLE_SLACK_MONITORING
SLACK_WEBHOOK_URL="$SLACK_WEBHOOK_URL"
DO_NETDATA_INSTALL=$DO_NETDATA_INSTALL
DO_SYSTEMD_TIMERS=$DO_SYSTEMD_TIMERS
DO_DOCKER_INSTALL=$DO_DOCKER_INSTALL
DOCKER_ROOTLESS=$DOCKER_ROOTLESS
DOCKER_DATA_ROOT="$DOCKER_DATA_ROOT"
DO_UFW_INSTALL=$DO_UFW_INSTALL
DO_DOKKU_INSTALL=$DO_DOKKU_INSTALL
DO_WIREGUARD_INSTALL=$DO_WIREGUARD_INSTALL
WIREGUARD_SUBNET="$WIREGUARD_SUBNET"
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

# Export the functions so they're available in subscripts
export -f is_module_installed
export -f mark_module_success
export -f mark_module_failed
export -f mark_module_skipped
export -f execute_module

##########################################################################################
## Define helper functions
##########################################################################################

##########################################################################################
## Define variables with default variables
##########################################################################################

# Standardized application paths - no more company placeholders
export AUTOMATION_ROOT="/srv/apps"
export BASEDIR=$(pwd)
export LOGDIR='/srv/apps/logs'
export DATE=$(date +%Y-%m-%d_%H%M)
export DEBIAN_FRONTEND=noninteractive # Make apt-get install non-interactive

export DO_CHANGE_TIMEZONE=N
export DO_SYSTEM_UPDATE=M     # MANDATORY
export DO_SWAPFILE_INSTALL=M  # MANDATORY
export DO_EXTRAS_INSTALL=M    # MANDATORY
export DO_GENERAL_SERVER_SETTINGS=M  # MANDATORY
export DO_LIGHTWEIGHT_MONITORING=M   # MANDATORY
export DO_NETDATA_INSTALL=N
export DO_SYSTEMD_TIMERS=M    # MANDATORY
export DO_DOCKER_INSTALL=N
export DO_UFW_INSTALL=M  # MANDATORY
export DO_SWAP_INSTALL=M  # MANDATORY
export DO_DOKKU_INSTALL=N
export DO_WIREGUARD_INSTALL=N

export ENABLE_SLACK_MONITORING=N
export SLACK_WEBHOOK_URL=""

export DOCKER_ROOTLESS=N
export DOCKER_DATA_ROOT="/var/lib/docker"
export WIREGUARD_SUBNET="10.66.66.0/24"

# @TODO - INSTALL RSYSLOG + POSTGRES DUMPER

export UFW_ALLOW_PUBLIC_HTTP=Y
export UFW_ALLOW_PUBLIC_HTTPS=Y
export UFW_ALLOW_NETDATA=Y

export TIMEZONE="Europe/Copenhagen"
export NTP="dk.pool.ntp.org"
export NTP_FALLBACK="pool.ntp.org"

export EMAIL_DOMAIN="mydomain.com"
export INFO_EMAIL="my.server.email@${EMAIL_DOMAIN}"

export SECURE_SUBNET="MYIPRANGE/32"
export SECURE_SUBNET_DESC="MY subnet"

##########################################################################################
## Message/logging functions
##########################################################################################

# Yellow
show_yellow() {
    echo $(tput bold)$(tput setaf 4) $@ $(tput sgr 0)
}
# White
show_norm() {
    echo $(tput bold)$(tput setaf 9) $@ $(tput sgr 0)
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
}

# Export functions so they're available in sourced subscripts
export -f show_yellow
export -f show_norm
export -f show_info
export -f show_warn
export -f show_err

##########################################################################################
## Check if we're are root
##########################################################################################

if [[ $EUID -ne 0 ]]; then
    show_err "Script must be run as root. Please check logfile and fix error manually."
    exit 1
fi

##########################################################################################
## Set standardized directory structure (no company name needed)
##########################################################################################

export SCRIPTSDIR="/srv/apps/scripts"
export DEPLOYDIR="/srv/apps"
export BACKUPDIR="/srv/apps/backups"

##########################################################################################
## Check if scripts folder exists and create it if it doesn't
##########################################################################################

if [ ! -d $SCRIPTSDIR ]; then
    mkdir -p $SCRIPTSDIR
fi

##########################################################################################
## Get input
##########################################################################################

# Create scripts directory if it doesn't exist
if [ ! -d $SCRIPTSDIR ]; then
    mkdir -p $SCRIPTSDIR
fi

# Create automation-backup dir if it doesn't exist - also creates ($DEPLOYDIR)
if [ ! -d $BACKUPDIR ]; then
    mkdir -p $BACKUPDIR
fi

# Create logs directory if it doesn't exist
if [ ! -d $LOGDIR ]; then
    mkdir -p $LOGDIR
    chmod 755 $LOGDIR
    log_info "Created logs directory: $LOGDIR"
fi

##########################################################################################
## Get input
##########################################################################################

# Change timezone?
while true; do
    read -p "Do You want to change timezone (default: $TIMEZONE) (Y/N)? " yn
    case $yn in
    [Yy]*)
        DO_CHANGE_TIMEZONE=Y && read -p "Enter timezone (i.e. 'Europe/Copenhagen'): " TIMEZONE
        break
        ;;
    [Nn]*)
        DO_CHANGE_TIMEZONE=N
        break
        ;;
    *) echo "Please answer yes or no." ;;
    esac
done

echo "DO_CHANGE_TIMEZONE: "$DO_CHANGE_TIMEZONE
echo "TIMEZONE: "$TIMEZONE

# Change NTP?
while true; do
    read -p "Do You want to change NTP server (default: $NTP) (Y/N)? " yn
    case $yn in
    [Yy]*)
        DO_CHANGE_NTP=Y && read -p "Enter NTP server fallback (i.e. 'dk.pool.ntp.org'): " NTP
        break
        ;;
    [Nn]*)
        DO_CHANGE_NTP=N
        break
        ;;
    *) echo "Please answer yes or no." ;;
    esac
done

echo "DO_CHANGE_NTP: "$DO_CHANGE_NTP
echo "NTP: "$NTP

# Change NTP FALLBACK?
while true; do
    read -p "Do You want to change NTP server fallback (default: $NTP_FALLBACK) (Y/N)? " yn
    case $yn in
    [Yy]*)
        DO_CHANGE_NTP=Y && read -p "Enter NTP server fallback (i.e. 'pool.ntp.org'): " NTP_FALLBACK
        break
        ;;
    [Nn]*)
        DO_CHANGE_NTP=N
        break
        ;;
    *) echo "Please answer yes or no." ;;
    esac
done

echo "DO_CHANGE_NTP_FALLBACK: "$DO_CHANGE_NTP_NTP_FALLBACK
echo "NTP_FALLBACK: "$NTP_FALLBACK

# Email domain configuration
read -p "Email domain (press Enter to keep '$EMAIL_DOMAIN'): " input_email_domain
if [[ -n "$input_email_domain" ]]; then
    EMAIL_DOMAIN="$input_email_domain"
    SET_EMAIL_DOMAIN=Y
else
    SET_EMAIL_DOMAIN=N
fi

echo "EMAIL_DOMAIN: "$EMAIL_DOMAIN

# Email address configuration
read -p "Email address prefix before @ (press Enter to keep 'my.server.email'): " input_email_prefix
if [[ -n "$input_email_prefix" ]]; then
    INFO_EMAIL="${input_email_prefix}@${EMAIL_DOMAIN}"
    SET_EMAIL_ADDRESS=Y
else
    INFO_EMAIL="my.server.email@${EMAIL_DOMAIN}"
    SET_EMAIL_ADDRESS=N
fi

echo "INFO_EMAIL: "$INFO_EMAIL

# Secure subnet configuration for SSH access
read -p "Secure subnet for SSH access (press Enter to keep '$SECURE_SUBNET'): " input_secure_subnet
if [[ -n "$input_secure_subnet" ]]; then
    SECURE_SUBNET="$input_secure_subnet"
    read -p "Description for this subnet (e.g., 'Home network' or 'Office'): " SECURE_SUBNET_DESC
    SET_SECURE_SUBNET=Y
else
    SET_SECURE_SUBNET=N
fi

echo "SECURE_SUBNET: "$SECURE_SUBNET
echo "SECURE_SUBNET_DESC: "$SECURE_SUBNET_DESC

##########################################################################################
## Display mandatory components that will be installed
##########################################################################################

echo ""
echo "=================================================================="
echo "🔒 MANDATORY SECURITY COMPONENTS (will be installed automatically)"
echo "=================================================================="
echo "✅ System Updates: Critical security patches and updates"
echo "✅ Essential Packages: Core system utilities and development tools"
echo "✅ Network Security: Comprehensive network hardening and sysctl tuning"
echo "✅ Account Security: Password policies, sudo security, and account lockouts"
echo "✅ SSH Security: Complete SSH hardening with modern algorithms"
echo "✅ Security Tools: Malware detection (ClamAV, Maldet, RKHunter) and intrusion prevention (Fail2Ban)"
echo "✅ Secure Swap: Encrypted swap file for memory protection"
echo "✅ System Monitoring: Essential monitoring tools (htop, iotop, sysstat)"
echo "✅ Automated Scanning: Systemd timers for automated security scans"
echo "✅ Firewall Protection: UFW firewall with intelligent rule generation"
echo "✅ Mail Server: Postfix for system notifications and alerts"
echo ""
echo "These components are required for a secure Ubuntu 24.04 server and cannot be skipped."
echo "=================================================================="
echo ""
# Check if we're resuming from a previous failed installation
if is_resuming && load_user_choices; then
    echo "🔄 RESUMING INSTALLATION with previous choices:"
    echo "=================================="
    echo "• DO_SYSTEM_UPDATE: $DO_SYSTEM_UPDATE (Mandatory)"
    echo "• DO_GENERAL_SERVER_SETTINGS: $DO_GENERAL_SERVER_SETTINGS (Mandatory)" 
    echo "• DO_SSH_2FA: $DO_SSH_2FA"
    echo "• DO_SWAP_INSTALL: $DO_SWAP_INSTALL (Mandatory)"
    echo "• DO_LIGHTWEIGHT_MONITORING: $DO_LIGHTWEIGHT_MONITORING (Mandatory)"
    echo "• ENABLE_SLACK_MONITORING: $ENABLE_SLACK_MONITORING"
    echo "• DO_NETDATA_INSTALL: $DO_NETDATA_INSTALL"
    echo "• DO_SYSTEMD_TIMERS: $DO_SYSTEMD_TIMERS (Mandatory)"
    echo "• DO_DOCKER_INSTALL: $DO_DOCKER_INSTALL"
    if [[ $DO_DOCKER_INSTALL =~ [Yy]$ ]]; then
        echo "• DOCKER_ROOTLESS: $DOCKER_ROOTLESS"
        echo "• DOCKER_DATA_ROOT: $DOCKER_DATA_ROOT"
    fi
    echo "• DO_UFW_INSTALL: $DO_UFW_INSTALL (Mandatory)"
    echo "• DO_DOKKU_INSTALL: $DO_DOKKU_INSTALL"
    echo "• DO_WIREGUARD_INSTALL: $DO_WIREGUARD_INSTALL"
    if [[ $DO_WIREGUARD_INSTALL =~ [Yy]$ ]]; then
        echo "• WIREGUARD_SUBNET: $WIREGUARD_SUBNET"
    fi
    echo "=================================="
    echo "ℹ️  Using saved configuration from previous run."
    echo "ℹ️  Only failed/new modules will be installed."
    echo ""
else
    echo "📋 Configuration Status:"
    echo "• DO_SYSTEM_UPDATE: $DO_SYSTEM_UPDATE (Mandatory)"
    echo "• DO_GENERAL_SERVER_SETTINGS: $DO_GENERAL_SERVER_SETTINGS (Mandatory)" 
    echo "• DO_SWAP_INSTALL: $DO_SWAP_INSTALL (Mandatory)"
    echo "• DO_LIGHTWEIGHT_MONITORING: $DO_LIGHTWEIGHT_MONITORING (Mandatory)"
    echo "• DO_SYSTEMD_TIMERS: $DO_SYSTEMD_TIMERS (Mandatory)"
    echo "• DO_UFW_INSTALL: $DO_UFW_INSTALL (Mandatory)"
    echo ""

    # System update and General server settings are MANDATORY (M) - no user prompts needed

    # SSH 2FA with Google Authenticator
    if [[ $DO_GENERAL_SERVER_SETTINGS =~ [YyMm]$ ]]; then
    while true; do
        read -p "Do You want to enable SSH 2FA with Google Authenticator (Y/N)? " yn
        case $yn in
        [Yy]*)
            DO_SSH_2FA=Y
            break
            ;;
        [Nn]*)
            DO_SSH_2FA=N
            break
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
else
    DO_SSH_2FA=N
fi

echo "DO_SSH_2FA: "$DO_SSH_2FA

# Note: User creation is now handled by separate add_user.sh script
# This keeps the installation focused on system setup

# Swap install and Lightweight monitoring are MANDATORY (M) - no user prompts needed

# Slack webhook for disk monitoring
if [[ $DO_LIGHTWEIGHT_MONITORING =~ [YyMm]$ ]]; then
    while true; do
        read -p "Do You want to enable Slack notifications for disk space monitoring (Y/N)? " yn
        case $yn in
        [Yy]*)
            ENABLE_SLACK_MONITORING=Y
            read -p "Enter Slack webhook URL for notifications: " SLACK_WEBHOOK_URL
            break
            ;;
        [Nn]*)
            ENABLE_SLACK_MONITORING=N
            break
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
    
    echo "ENABLE_SLACK_MONITORING: "$ENABLE_SLACK_MONITORING
    if [[ $ENABLE_SLACK_MONITORING =~ [Yy]$ ]]; then
        echo "SLACK_WEBHOOK_URL: "$SLACK_WEBHOOK_URL
    fi
fi

# Netdata install
while true; do
    read -p "Do You want to install Netdata (Y/N)? " yn
    case $yn in
    [Yy]*)
        DO_NETDATA_INSTALL=Y
        break
        ;;
    [Nn]*)
        DO_NETDATA_INSTALL=N
        break
        ;;
    *) echo "Please answer yes or no." ;;
    esac
done

echo "DO_NETDATA_INSTALL: "$DO_NETDATA_INSTALL

# Systemd timers install is MANDATORY (M) - no user prompts needed

# Docker install
while true; do
    read -p "Do You want to install Docker (Y/N)? " yn
    case $yn in
    [Yy]*)
        DO_DOCKER_INSTALL=Y
        break
        ;;
    [Nn]*)
        DO_DOCKER_INSTALL=N
        break
        ;;
    *) echo "Please answer yes or no." ;;
    esac
done

if [[ $DO_DOCKER_INSTALL =~ [Yy]$ ]]; then
    # Docker rootless mode
    while true; do
        read -p "Do You want to install Docker in rootless mode (Y/N)? " yn
        case $yn in
        [Yy]*)
            DOCKER_ROOTLESS=Y
            break
            ;;
        [Nn]*)
            DOCKER_ROOTLESS=N
            break
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done

    # Docker data directory
    while true; do
        read -p "Do You want to change Docker data directory (default: $DOCKER_DATA_ROOT) (Y/N)? " yn
        case $yn in
        [Yy]*)
            read -p "Enter Docker data directory (e.g., '/mnt/docker'): " DOCKER_DATA_ROOT
            break
            ;;
        [Nn]*)
            break
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
    
    echo "DOCKER_ROOTLESS: "$DOCKER_ROOTLESS
    echo "DOCKER_DATA_ROOT: "$DOCKER_DATA_ROOT
fi

echo "DO_DOCKER_INSTALL: "$DO_DOCKER_INSTALL

# UFW install is MANDATORY (M) - no user prompts needed

# Dokku install
while true; do
    read -p "Do You want to install Dokku (Y/N)? " yn
    case $yn in
    [Yy]*)
        DO_DOKKU_INSTALL=Y
        break
        ;;
    [Nn]*)
        DO_DOKKU_INSTALL=N
        break
        ;;
    *) echo "Please answer yes or no." ;;
    esac
done

# Wireguard install
while true; do
    read -p "Do You want to install Wireguard VPN (Y/N)? " yn
    case $yn in
    [Yy]*)
        DO_WIREGUARD_INSTALL=Y
        break
        ;;
    [Nn]*)
        DO_WIREGUARD_INSTALL=N
        break
        ;;
    *) echo "Please answer yes or no." ;;
    esac
done

if [[ $DO_WIREGUARD_INSTALL =~ [Yy]$ ]]; then
    # Wireguard subnet configuration
    while true; do
        read -p "Do You want to change Wireguard VPN subnet (default: $WIREGUARD_SUBNET) (Y/N)? " yn
        case $yn in
        [Yy]*)
            read -p "Enter Wireguard VPN subnet (e.g., '10.66.66.0/24'): " WIREGUARD_SUBNET
            break
            ;;
        [Nn]*)
            break
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
    
    echo "WIREGUARD_SUBNET: "$WIREGUARD_SUBNET
fi

echo "DO_UFW_INSTALL: "$DO_UFW_INSTALL
echo "DO_WIREGUARD_INSTALL: "$DO_WIREGUARD_INSTALL

    # Save user choices for potential resume scenarios
    save_user_choices
fi

## Ask for UFW port openings
#if [[ $DO_UFW_INSTALL =~ [Yy]$ ]]
#   then
#      read -p "Do You want to allow port 80 (http) to World (Y/N)?" -n 1 UFW_ALLOW_PUBLIC_HTTP; echo
#      read -p "Do You want to allow port 443 (https) to World (Y/N)?" -n 1 UFW_ALLOW_PUBLIC_HTTPS; echo
#      read -p "Do You want to allow port 8081 (Monitorix) to World (Y/N)?" -n 1 UFW_ALLOW_MONITORIX; echo
#      read -p "Do You want to allow port 19999 (Netdata) to World (Y/N)?" -n 1 UFW_ALLOW_NETDATA; echo
#fi

##########################################################################################
## UFW configuration now handled by ufw_install.sh script
##########################################################################################

# UFW rules are now generated dynamically by the ufw_install.sh script
# based on the services being installed (Dokku, WireGuard, Netdata, etc.)
# This provides better organization and security-focused rule generation

##########################################################################################
## Execute subscripts
##########################################################################################

printf "\n-----------------------------------------------------------\n"
printf "\nWill now execute subscripts based on Your previous choices.\n"

# Initialize installation status log
init_install_status_log

# Show current installation status if log exists
if [ -f "$INSTALL_STATUS_LOG" ] && [ -s "$INSTALL_STATUS_LOG" ]; then
    show_install_status
    echo ""
    echo "⚡ Modules marked as SUCCESS will be skipped."
    echo "⚡ Failed or new modules will be installed/retried."
    echo ""
fi

read -p "Do You want to continue (Y/N)?" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    printf "\n\n--------------------\n"
    show_norm "Executing subscripts"
    printf "\n--------------------\n"
else
    printf "\n\n------------------\n"
    show_warn "Exiting gracefully"
    printf "\n------------------\n"
    log_info "Installation cancelled by user"
    exit 0
fi

# Start timer and log installation start
START_TIME=$(date +%s)
log_start "Ubuntu 24.04 Automation Installation"
log_info "Installation ID: $INSTALL_ID"
log_info "Scripts directory: $SCRIPTSDIR"
log_info "Email: $INFO_EMAIL"
log_info "Timezone: $TIMEZONE"

# Ensure all subscripts have execute permissions
chmod +x $BASEDIR/subscripts/*.sh
log_info "Subscript permissions updated"

# Set timezone
if [[ $DO_SET_TIMEZONE =~ [Yy]$ ]]; then
    cp -p /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    echo "${TIMEZONE}" >/etc/timezone
    show_yellow "Timezone set to $TIMEZONE"
fi

printf "\n--------------------\n"

# System update
execute_module "System_Update" "$BASEDIR/subscripts/system_update.sh" "$DO_SYSTEM_UPDATE"

printf "\n--------------------\n"

# Common packages installation (foundational - needed by all other modules)
execute_module "Packages_Installation" "$BASEDIR/subscripts/packages_install.sh" "Y"

printf "\n--------------------\n"

# Network security configuration (must be early in process)
execute_module "Network_Security" "$BASEDIR/subscripts/network_security.sh" "Y"

printf "\n--------------------\n"

# Account security configuration (must be before SSH configuration)
execute_module "Account_Security" "$BASEDIR/subscripts/account_security.sh" "Y"

printf "\n--------------------\n"

# SSH security configuration (replaces old SSH 2FA and general SSH hardening)
execute_module "SSH_Security" "$BASEDIR/subscripts/ssh_security.sh" "$DO_SSH_2FA"

printf "\n--------------------\n"

# Security and system hardening tools
if [[ $DO_GENERAL_SERVER_SETTINGS =~ [YyMm]$ ]]; then
    # Check if the entire security suite is already complete
    if is_module_installed "Secure_Shared_Memory" && \
       is_module_installed "Maldet_Installation" && \
       is_module_installed "RKHunter_Installation" && \
       is_module_installed "ClamAV_Installation" && \
       is_module_installed "Fail2Ban_Installation" && \
       is_module_installed "Postfix_Installation"; then
        log_info "All security hardening modules already installed successfully, skipping..."
        show_warn "All security hardening modules already installed successfully, skipping..."
    else
        execute_module "Secure_Shared_Memory" "$BASEDIR/subscripts/secure_shared_memory_install.sh" "Y"
        printf "\n--------------------\n"
        execute_module "Maldet_Installation" "$BASEDIR/subscripts/maldet_install.sh" "Y"
        printf "\n--------------------\n"
        execute_module "RKHunter_Installation" "$BASEDIR/subscripts/rkhunter_install.sh" "Y"
        printf "\n--------------------\n"
        execute_module "ClamAV_Installation" "$BASEDIR/subscripts/clamav_install.sh" "Y"
        printf "\n--------------------\n"
        execute_module "Fail2Ban_Installation" "$BASEDIR/subscripts/fail2ban_install.sh" "Y"
        printf "\n--------------------\n"
        execute_module "Postfix_Installation" "$BASEDIR/subscripts/postfix_install.sh" "Y"
    fi
else
    mark_module_skipped "Secure_Shared_Memory"
    mark_module_skipped "Maldet_Installation"
    mark_module_skipped "RKHunter_Installation"
    mark_module_skipped "ClamAV_Installation"
    mark_module_skipped "Fail2Ban_Installation"
    mark_module_skipped "Postfix_Installation"
    log_info "Security hardening tools skipped by user choice"
    show_warn "Security hardening tools will not be installed"
fi

printf "\n--------------------\n"

# Swap install
execute_module "Swap_Installation" "$BASEDIR/subscripts/swap_install.sh" "$DO_SWAP_INSTALL"

printf "\n--------------------\n"

# Docker install
execute_module "Docker_Installation" "$BASEDIR/subscripts/docker_install.sh" "$DO_DOCKER_INSTALL"

printf "\n--------------------\n"

# Lightweight monitoring install
execute_module "Lightweight_Monitoring" "$BASEDIR/subscripts/lightweight_monitoring_install.sh" "$DO_LIGHTWEIGHT_MONITORING"

printf "\n--------------------\n"

# Netdata install
execute_module "Netdata_Installation" "$BASEDIR/subscripts/netdata_install.sh" "$DO_NETDATA_INSTALL"

printf "\n--------------------\n"

# Wireguard install
execute_module "Wireguard_VPN" "$BASEDIR/subscripts/wireguard_install.sh" "$DO_WIREGUARD_INSTALL"

printf "\n--------------------\n"

# Systemd timers install (after security tools are configured)
execute_module "Systemd_Timers" "$BASEDIR/subscripts/systemd_timers_install.sh" "$DO_SYSTEMD_TIMERS"

printf "\n--------------------\n"

# UFW script install / MUST BE DONE LAST DUE TO UFW BEING ALTERED ACCORDING TO INSTALLATION
if [[ $DO_UFW_INSTALL =~ [YyMm]$ ]]; then
    # UFW needs special handling to backup existing configuration
    if ! is_module_installed "UFW_Firewall"; then
        ufw status numbered >>$BACKUPDIR/ufw 2>/dev/null || true
    fi
fi
execute_module "UFW_Firewall" "$BASEDIR/subscripts/ufw_install.sh" "$DO_UFW_INSTALL"

printf "\n--------------------\n"

# Dokku install
execute_module "Dokku_Installation" "$BASEDIR/subscripts/dokku_install.sh" "$DO_DOKKU_INSTALL"

printf "\n--------------------\n"

# End timer and log completion
END_TIME=$(date +%s)
DURATION=$(expr $END_TIME - $START_TIME)

# Display final installation status
show_install_status

# Log installation completion with summary
log_success "Ubuntu 24.04 Automation Installation Complete"
log_info "Total installation time: ${DURATION} seconds"
log_info "Installation completed at: $(date)"

# Log final summary to journal (if systemd-cat is available)
if command -v systemd-cat >/dev/null 2>&1; then
    echo "=== INSTALLATION SUMMARY ===" | systemd-cat -t "$JOURNAL_TAG" -p "info"
fi

# Say bye
show_norm "Installation done (took $DURATION seconds). Have a nice day."
show_info ""
show_info "📋 To view complete installation log, run:"
show_info "   journalctl -t ubuntu-automation-${INSTALL_ID} --no-pager"
show_info ""
show_info "📊 To view installation summary:"
show_info "   journalctl -t ubuntu-automation-${INSTALL_ID} INSTALL_STEP=summary --no-pager"
show_info ""
show_info "🔍 To view specific installation steps:"
show_info "   journalctl -t ubuntu-automation-${INSTALL_ID} INSTALL_PHASE=main --no-pager"
show_info ""
show_info "📝 Installation status log location:"
show_info "   $INSTALL_STATUS_LOG"
show_info ""
show_info "👤 USER MANAGEMENT:"
show_info "   • Root SSH login is DISABLED for security"
show_info "   • Add new users: $SCRIPTSDIR/add_user.sh --interactive"
show_info "   • Quick user creation: $SCRIPTSDIR/add_user.sh -u username"
show_info "   • All users get sudo access, SSH 2FA, and WireGuard VPN (if available)"
show_info "   • Use 'sudo su -' to become root after logging in as a regular user"
show_info ""
if [[ $DO_GENERAL_SERVER_SETTINGS =~ [Yy]$ ]]; then
    show_info "🛡️ SECURITY SCANNING INFORMATION:"
    show_info "   • ClamAV/Maldet: Configured with false positive reduction"
    show_info "   • Exclusions: Applied for common system files and applications"
    show_info "   • Helper script: Run 'clamav-exclude-helper.sh' to optimize for your software stack"
    show_info "   • Scan logs: Available in /var/log/clamav/manual_clamscan.log"
    show_info "   • Manual scan: Run '/usr/local/bin/clamav-scan.sh' to test configuration"
    show_info ""
fi
