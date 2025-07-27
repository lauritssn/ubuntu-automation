#!/bin/bash

##########################################################################################
## Common Packages Installation
##########################################################################################
##
## Description:
##   Installs essential system packages, security tools, and optional services for Ubuntu 24.04.
##   This script handles package installation and verification but does NOT modify any
##   Ubuntu configuration files directly.
##
## Ubuntu Configuration Files Modified:
##   - NONE - This script only installs packages via apt-get
##   - Package configurations are handled by their respective installation scripts
##   - Postfix mail server is pre-configured via debconf to avoid interactive prompts
##
## Packages Installed:
##   Essential: curl, wget, git, unzip, tar, gzip, gcc, build-essential, htop, etc.
##   Security: ufw, fail2ban, clamav, libpam-google-authenticator, qrencode
##   Optional: wireguard, netdata, postfix (based on user selections)
##
## Note: Individual service configurations are handled by dedicated scripts:
##   - SSH security: ssh_security.sh
##   - Firewall: ufw_install.sh
##   - Fail2Ban: fail2ban_install.sh
##   - ClamAV: clamav_install.sh
##   - etc.
##
##########################################################################################

##########################################################################################
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="packages_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/srv/apps/logs
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Update package lists
##########################################################################################

show_yellow "Updating package lists for Ubuntu 24.04."

# Update package lists with retry logic
for i in {1..3}; do
    if apt-get --yes update >>$LOGDIR/$LOGFILE 2>&1; then
        show_yellow "Package lists updated successfully."
        break
    else
        show_yellow "Package update attempt $i failed, retrying..."
        apt-get clean >>$LOGDIR/$LOGFILE 2>&1
        if [ $i -eq 3 ]; then
            show_err "Failed to update package lists after 3 attempts. Please check logfile and fix error manually."
            exit 100
        fi
        sleep 2
    fi
done

##########################################################################################
## Install essential system packages
##########################################################################################

show_yellow "Installing essential system packages."

# Core system utilities
ESSENTIAL_PACKAGES="curl wget git unzip tar gzip"

# Build and development tools
BUILD_PACKAGES="gcc build-essential libc6-dev dkms linux-headers-generic"

# System monitoring and management
MONITORING_PACKAGES="htop iotop sysstat acct atop"

# Security and encryption
SECURITY_PACKAGES="openssl sqlite3 libsqlite3-dev"

# Perl and network utilities (needed for various security tools)
PERL_PACKAGES="perl libnet-ssleay-perl libauthen-pam-perl libpam-runtime libio-pty-perl"

# Text processing and utilities
TEXT_PACKAGES="dos2unix"

# Combine all packages
ALL_PACKAGES="$ESSENTIAL_PACKAGES $BUILD_PACKAGES $MONITORING_PACKAGES $SECURITY_PACKAGES $PERL_PACKAGES $TEXT_PACKAGES"

# Install packages
if ! apt-get --yes install $ALL_PACKAGES >>$LOGDIR/$LOGFILE 2>&1; then
    show_err "Installation of essential packages failed. Please check logfile and fix error manually."
    exit 1
fi

show_yellow "Essential system packages installed successfully."

##########################################################################################
## Install security-specific packages
##########################################################################################

show_yellow "Installing security packages."

# SSH and authentication packages
SSH_PACKAGES="libpam-google-authenticator pamtester"

# QR code generation (used by SSH 2FA and WireGuard)
QR_PACKAGES="qrencode"

# Network security
NETWORK_PACKAGES="ufw fail2ban"

# Antivirus and malware detection
ANTIVIRUS_PACKAGES="clamav clamav-daemon clamav-freshclam"

# Install security packages
SECURITY_ALL="$SSH_PACKAGES $QR_PACKAGES $NETWORK_PACKAGES $ANTIVIRUS_PACKAGES"

if ! apt-get --yes install $SECURITY_ALL >>$LOGDIR/$LOGFILE 2>&1; then
    show_err "Installation of security packages failed. Please check logfile and fix error manually."
    exit 1
fi

show_yellow "Security packages installed successfully."

##########################################################################################
## Install optional service packages (based on user choices)
##########################################################################################

# WireGuard VPN (if selected)
if [[ "$DO_WIREGUARD_INSTALL" =~ [Yy]$ ]]; then
    show_yellow "Installing WireGuard packages."
    if ! apt-get --yes install wireguard wireguard-tools >>$LOGDIR/$LOGFILE 2>&1; then
        show_err "Installation of WireGuard failed. Please check logfile and fix error manually."
        exit 1
    fi
    show_yellow "WireGuard packages installed successfully."
fi

# Netdata monitoring (if selected)
if [[ "$DO_NETDATA_INSTALL" =~ [Yy]$ ]]; then
    show_yellow "Installing Netdata packages."
    if ! apt-get --yes install netdata >>$LOGDIR/$LOGFILE 2>&1; then
        show_err "Installation of Netdata failed. Please check logfile and fix error manually."
        exit 1
    fi
    show_yellow "Netdata packages installed successfully."
fi

# Postfix mail server (if general server settings selected)
if [[ "$DO_GENERAL_SERVER_SETTINGS" =~ [Yy]$ ]]; then
    show_yellow "Installing mail server packages."

    # Pre-configure postfix to avoid interactive prompts
    echo "postfix postfix/mailname string $(hostname -f)" | debconf-set-selections
    echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections

    if ! apt-get --yes install postfix mailutils >>$LOGDIR/$LOGFILE 2>&1; then
        show_err "Installation of mail packages failed. Please check logfile and fix error manually."
        exit 1
    fi
    show_yellow "Mail server packages installed successfully."
fi

##########################################################################################
## Verify critical packages
##########################################################################################

show_yellow "Verifying critical package installations."

# Function to check if a package is installed
check_package() {
    local package="$1"
    local description="$2"

    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
        show_yellow "$description ($package) is installed."
        return 0
    else
        show_err "$description ($package) is NOT installed."
        return 1
    fi
}

# Check critical packages
VERIFICATION_FAILED=0

check_package "curl" "Curl" || VERIFICATION_FAILED=1
check_package "git" "Git" || VERIFICATION_FAILED=1
check_package "htop" "Htop" || VERIFICATION_FAILED=1
check_package "ufw" "UFW Firewall" || VERIFICATION_FAILED=1
check_package "fail2ban" "Fail2Ban" || VERIFICATION_FAILED=1
check_package "clamav" "ClamAV" || VERIFICATION_FAILED=1
check_package "libpam-google-authenticator" "Google Authenticator" || VERIFICATION_FAILED=1
check_package "qrencode" "QR Code Generator" || VERIFICATION_FAILED=1

if [[ "$DO_WIREGUARD_INSTALL" =~ [Yy]$ ]]; then
    check_package "wireguard" "WireGuard" || VERIFICATION_FAILED=1
fi

if [[ "$DO_NETDATA_INSTALL" =~ [Yy]$ ]]; then
    check_package "netdata" "Netdata" || VERIFICATION_FAILED=1
fi

if [ $VERIFICATION_FAILED -eq 1 ]; then
    show_err "Some critical packages failed verification. Please check the installation."
    exit 1
fi

##########################################################################################
## Clean up package cache
##########################################################################################

show_yellow "Cleaning up package cache."

apt-get autoremove --yes >>$LOGDIR/$LOGFILE 2>&1
apt-get autoclean >>$LOGDIR/$LOGFILE 2>&1

show_yellow "Package cache cleaned up."

##########################################################################################
## Package installation summary
##########################################################################################

show_info "=== Package Installation Summary ==="
show_info "✅ Essential system packages: Installed"
show_info "✅ Security packages: Installed"
show_info "✅ SSH/2FA packages: Installed"
show_info "✅ Firewall packages: Installed"
show_info "✅ Antivirus packages: Installed"

if [[ "$DO_WIREGUARD_INSTALL" =~ [Yy]$ ]]; then
    show_info "✅ WireGuard VPN packages: Installed"
fi

if [[ "$DO_NETDATA_INSTALL" =~ [Yy]$ ]]; then
    show_info "✅ Netdata monitoring packages: Installed"
fi

if [[ "$DO_GENERAL_SERVER_SETTINGS" =~ [Yy]$ ]]; then
    show_info "✅ Mail server packages: Installed"
fi

show_info ""
show_info "All required packages have been installed and verified."
show_info "Individual service configuration will be handled by their respective scripts."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
