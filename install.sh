#!/bin/bash

printf "############################################\n"
printf "# Ubuntu 24.04 Install Automation #\n"
printf "############################################\n\n"

##########################################################################################
## Set bash options and logging
##########################################################################################
set -e # Exit on error
#set -x # Enable debugging

# Initialize systemd journal logging for installation tracking
INSTALL_ID=$(date +%Y%m%d_%H%M%S)
JOURNAL_TAG="ubuntu-automation-${INSTALL_ID}"

# Function to log to both stdout and systemd journal
log_install() {
    local level="$1"
    local message="$2"
    local step="$3"
    
    # Log to systemd journal with structured data
    echo "$message" | systemd-cat -t "$JOURNAL_TAG" -p "$level" \
        INSTALL_STEP="$step" \
        INSTALL_ID="$INSTALL_ID" \
        INSTALL_PHASE="main"
    
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
## Define helper functions
##########################################################################################

##########################################################################################
## Define variables with default variables
##########################################################################################

# Standardized application paths - no more company placeholders
export AUTOMATION_ROOT="/srv/apps"
export BASEDIR=$(pwd)
export LOGDIR='/tmp'
export DATE=$(date +%Y-%m-%d_%H%M)
export DEBIAN_FRONTEND=noninteractive # Make apt-get install non-interactive

export DO_CHANGE_TIMEZONE=N
export DO_SYSTEM_UPDATE=N
export DO_SWAPFILE_INSTALL=N
export DO_EXTRAS_INSTALL=N
export DO_GENERAL_SERVER_SETTINGS=N
export DO_LIGHTWEIGHT_MONITORING=N
export DO_NETDATA_INSTALL=N
export DO_SYSTEMD_TIMERS=N
export DO_DOCKER_INSTALL=N
export DO_UFW_INSTALL=N
export DO_SWAP_INSTALL=N
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
export UFW_ALLOW_POSTHOG=Y
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

# Write to secret file
echo $DATE >>$SCRIPTSDIR/pswd

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

# Change e-mail domain
while true; do
    read -p "Do You want to change e-mail domain? (default is $EMAIL_DOMAIN) (Y/N)? " yn
    case $yn in
    [Yy]*)
        SET_EMAIL_DOMAIN=Y && read -p "Enter e-mail domain (only domain part of e-mail address): " EMAIL_DOMAIN
        break
        ;;
    [Nn]*)
        SET_EMAIL_DOMAIN=N
        break
        ;;
    *) echo "Please answer yes or no." ;;
    esac
done

echo "SET_EMAIL_DOMAIN: "$SET_EMAIL_DOMAIN
echo "EMAIL_DOMAIN: "$EMAIL_DOMAIN

# Change e-mail alias
while true; do
    read -p "Do You want to change e-mail address? (default is $INFO_EMAIL) (Y/N)? " yn
    case $yn in
    [Yy]*)
        SET_EMAIL_DOMAIN=Y && read -p "Enter the xxx part before @ in the e-mail address (xxx@domain.com): " INFO_EMAIL
        break
        ;;
    [Nn]*)
        SET_EMAIL_DOMAIN=N
        break
        ;;
    *) echo "Please answer yes or no." ;;
    esac
done

echo "SET_EMAIL_ADDRESS: "$SET_EMAIL_ADDRESS
echo "INFO_EMAIL: "$INFO_EMAIL

# System update
while true; do
    read -p "Do You want to update system (Y/N)? " yn
    case $yn in
    [Yy]*)
        DO_SYSTEM_UPDATE=Y
        break
        ;;
    [Nn]*)
        DO_SYSTEM_UPDATE=N
        break
        ;;
    *) echo "Please answer yes or no." ;;
    esac
done

echo "DO_SYSTEM_UPDATE: "$DO_SYSTEM_UPDATE

# General server settings install
while true; do
    read -p "Do You want to install general server settings (Y/N)? " yn
    case $yn in
    [Yy]*)
        DO_GENERAL_SERVER_SETTINGS=Y
        break
        ;;
    [Nn]*)
        DO_GENERAL_SERVER_SETTINGS=N
        break
        ;;
    *) echo "Please answer yes or no." ;;
    esac
done

echo "DO_GENERAL_SERVER_SETTINGS: "$DO_GENERAL_SERVER_SETTINGS

# Swap install
while true; do
    read -p "Do you want to install secure swap file (Y/N)? " yn
    case $yn in
    [Yy]*)
        DO_SWAP_INSTALL=Y
        break
        ;;
    [Nn]*)
        DO_SWAP_INSTALL=N
        break
        ;;
    *) echo "Please answer yes or no." ;;
    esac
done

echo "DO_SWAP_INSTALL: "$DO_SWAP_INSTALL

# Lightweight monitoring install
while true; do
    read -p "Do You want to install lightweight monitoring tools (htop, iotop, sysstat) (Y/N)? " yn
    case $yn in
    [Yy]*)
        DO_LIGHTWEIGHT_MONITORING=Y
        break
        ;;
    [Nn]*)
        DO_LIGHTWEIGHT_MONITORING=N
        break
        ;;
    *) echo "Please answer yes or no." ;;
    esac
done

echo "DO_LIGHTWEIGHT_MONITORING: "$DO_LIGHTWEIGHT_MONITORING

# Slack webhook for disk monitoring
if [[ $DO_LIGHTWEIGHT_MONITORING =~ [Yy]$ ]]; then
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

# Systemd timers install
while true; do
    read -p "Do You want to install systemd timers for security scanning (Y/N)? " yn
    case $yn in
    [Yy]*)
        DO_SYSTEMD_TIMERS=Y
        break
        ;;
    [Nn]*)
        DO_SYSTEMD_TIMERS=N
        break
        ;;
    *) echo "Please answer yes or no." ;;
    esac
done

echo "DO_SYSTEMD_TIMERS: "$DO_SYSTEMD_TIMERS

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

# UFW install
while true; do
    read -p "Do You want to install UFW (Y/N)? " yn
    case $yn in
    [Yy]*)
        DO_UFW_INSTALL=Y
        break
        ;;
    [Nn]*)
        DO_UFW_INSTALL=N
        break
        ;;
    *) echo "Please answer yes or no." ;;
    esac
done

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

## Ask for UFW port openings
#if [[ $DO_UFW_INSTALL =~ [Yy]$ ]]
#   then
#      read -p "Do You want to allow port 80 (http) to World (Y/N)?" -n 1 UFW_ALLOW_PUBLIC_HTTP; echo
#      read -p "Do You want to allow port 443 (https) to World (Y/N)?" -n 1 UFW_ALLOW_PUBLIC_HTTPS; echo
#      read -p "Do You want to allow port 8081 (Monitorix) to World (Y/N)?" -n 1 UFW_ALLOW_MONITORIX; echo
#      read -p "Do You want to allow port 19999 (Netdata) to World (Y/N)?" -n 1 UFW_ALLOW_NETDATA; echo
#fi

##########################################################################################
## Prepare ufw.sh
##########################################################################################

# Build UFW_HEADER
UFW_HEADER="#!/bin/bash
# UFW Ubuntu 24.04 Configuration Script
# UFW_HEADER START
ufw --force reset

# Configure defaults for Ubuntu 24.04
ufw default deny incoming
ufw default allow outgoing

# Enable IPv6 support (Ubuntu 24.04 best practice)
sed -i 's/IPV6=no/IPV6=yes/' /etc/default/ufw 2>/dev/null || true

# Enable logging
ufw logging on

# Allow HTTP and HTTPS to everyone
ufw allow 80/tcp # HTTP
ufw allow 443/tcp # HTTPS

# Allow SSH only from secure subnet - REPLACE THESE VALUES
ufw allow proto tcp from $SECURE_SUBNET to any port 22 # $SECURE_SUBNET_DESC to SSH"

# Add Wireguard port if Wireguard is being installed
if [[ $DO_WIREGUARD_INSTALL =~ [Yy]$ ]]; then
    UFW_HEADER="${UFW_HEADER}

# Allow Wireguard VPN port
ufw allow 51820/udp # WIREGUARD VPN

# Allow VPN subnet full access to all services
ufw allow from ${WIREGUARD_SUBNET%/*}.0/24 # Full VPN access"
fi

UFW_HEADER="${UFW_HEADER}

# Enable UFW with force to avoid prompts
ufw --force enable

# UFW_HEADER END
"

if [[ $DO_UFW_INSTALL =~ [Yy]$ ]]; then
    echo "$UFW_HEADER" >$SCRIPTSDIR/ufw.sh
fi

##########################################################################################
## Execute subscripts
##########################################################################################

printf "\n-----------------------------------------------------------\n"
printf "\nWill now execute subscripts based on Your previous choices.\n"

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

# Set timezone
if [[ $DO_SET_TIMEZONE =~ [Yy]$ ]]; then
    cp -p /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    echo "${TIMEZONE}" >/etc/timezone
    show_yellow "Timezone set to $TIMEZONE"
fi

printf "\n--------------------\n"

# System update
if [[ $DO_SYSTEM_UPDATE =~ [Yy]$ ]]; then
    log_start "System Update"
    source $BASEDIR/subscripts/system_update.sh
    log_success "System Update"
else
    log_info "System update skipped by user choice"
    show_warn "System update will not be performed"
fi

printf "\n--------------------\n"

# General server settings install
if [[ $DO_GENERAL_SERVER_SETTINGS =~ [Yy]$ ]]; then
    log_start "General Server Settings"
    source $BASEDIR/subscripts/general_system_settings.sh
    log_success "General System Settings"
    printf "\n--------------------\n"
    log_start "Secure Shared Memory"
    source $BASEDIR/subscripts/secure_shared_memory_install.sh
    log_success "Secure Shared Memory"
    printf "\n--------------------\n"
    log_start "Sysctl Configuration"
    source $BASEDIR/subscripts/sysctl_install.sh
    log_success "Sysctl Configuration"
    printf "\n--------------------\n"
    log_start "Maldet Installation"
    source $BASEDIR/subscripts/maldet_install.sh
    log_success "Maldet Installation"
    printf "\n--------------------\n"
    log_start "RKHunter Installation"
    source $BASEDIR/subscripts/rkhunter_install.sh
    log_success "RKHunter Installation"
    printf "\n--------------------\n"
    log_start "ClamAV Installation"
    source $BASEDIR/subscripts/clamav_install.sh
    log_success "ClamAV Installation"
    printf "\n--------------------\n"
    log_start "Fail2Ban Installation"
    source $BASEDIR/subscripts/fail2ban_install.sh
    log_success "Fail2Ban Installation"
    printf "\n--------------------\n"
    log_start "Postfix Installation"
    source $BASEDIR/subscripts/postfix_install.sh
    log_success "Postfix Installation"
else
    log_info "General server settings skipped by user choice"
    show_warn "General server settings will not be installed"
fi

printf "\n--------------------\n"

# Swap install
if [[ $DO_SWAP_INSTALL =~ [Yy]$ ]]; then
    log_start "Swap Installation"
    source $BASEDIR/subscripts/swap_install.sh
    log_success "Swap Installation"
else
    log_info "Swap installation skipped by user choice"
    show_warn "Swap not selected."
fi

printf "\n--------------------\n"

# Docker install
if [[ $DO_DOCKER_INSTALL =~ [Yy]$ ]]; then
    log_start "Docker Installation"
    source $BASEDIR/subscripts/docker_install.sh
    log_success "Docker Installation"
else
    log_info "Docker installation skipped by user choice"
    show_warn "Docker will not be installed"
fi

printf "\n--------------------\n"

# Lightweight monitoring install
if [[ $DO_LIGHTWEIGHT_MONITORING =~ [Yy]$ ]]; then
    log_start "Lightweight Monitoring Tools"
    source $BASEDIR/subscripts/lightweight_monitoring_install.sh
    log_success "Lightweight Monitoring Tools"
else
    log_info "Lightweight monitoring skipped by user choice"
    show_warn "Lightweight monitoring tools will not be installed"
fi

printf "\n--------------------\n"

# Netdata install
if [[ $DO_NETDATA_INSTALL =~ [Yy]$ ]]; then
    log_start "Netdata Installation"
    source $BASEDIR/subscripts/netdata_install.sh
    log_success "Netdata Installation"
else
    log_info "Netdata installation skipped by user choice"
    show_warn "Netdata will not be installed"
fi

printf "\n--------------------\n"

# Wireguard install
if [[ $DO_WIREGUARD_INSTALL =~ [Yy]$ ]]; then
    log_start "Wireguard VPN Installation"
    source $BASEDIR/subscripts/wireguard_install.sh
    log_success "Wireguard VPN Installation"
else
    log_info "Wireguard VPN installation skipped by user choice"
    show_warn "Wireguard VPN will not be installed"
fi

printf "\n--------------------\n"

# Systemd timers install (after security tools are configured)
if [[ $DO_SYSTEMD_TIMERS =~ [Yy]$ ]]; then
    log_start "Systemd Timers Installation"
    source $BASEDIR/subscripts/systemd_timers_install.sh
    log_success "Systemd Timers Installation"
else
    log_info "Systemd timers installation skipped by user choice"
    show_warn "Systemd timers will not be installed"
fi

printf "\n--------------------\n"

# UFW script install / MUST BE DONE LAST DUE TO UFW BEING ALTERED ACCORDING TO INSTALLATION
if [[ $DO_UFW_INSTALL =~ [Yy]$ ]]; then
    log_start "UFW Firewall Installation"
    ufw status numbered >>$BACKUPDIR/ufw

    source $BASEDIR/subscripts/ufw_install.sh
    log_success "UFW Firewall Installation"
else
    log_info "UFW firewall installation skipped by user choice"
    show_warn "UFW script will not be installed"
fi

printf "\n--------------------\n"

# Dokku install
if [[ $DO_DOKKU_INSTALL =~ [Yy]$ ]]; then
    log_start "Dokku Installation"
    source $BASEDIR/subscripts/dokku_install.sh
    log_success "Dokku Installation"
else
    log_info "Dokku installation skipped by user choice"
    show_warn "Dokku will not be installed"
fi

printf "\n--------------------\n"

# Write to pswd and secure file
echo "" >>$SCRIPTSDIR/pswd
chmod 0600 $SCRIPTSDIR/pswd

# End timer and log completion
END_TIME=$(date +%s)
DURATION=$(expr $END_TIME - $START_TIME)

# Log installation completion with summary
log_success "Ubuntu 24.04 Automation Installation Complete"
log_info "Total installation time: ${DURATION} seconds"
log_info "Installation completed at: $(date)"

# Log final summary to journal
echo "=== INSTALLATION SUMMARY ===" | systemd-cat -t "$JOURNAL_TAG" -p "info" \
    INSTALL_STEP="summary" \
    INSTALL_ID="$INSTALL_ID" \
    INSTALL_PHASE="complete" \
    INSTALL_DURATION="$DURATION"

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
