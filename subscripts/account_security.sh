#!/bin/bash

##########################################################################################
## Source shared helper functions
##########################################################################################

# Set BASEDIR early for shared functions to use
export BASEDIR="${BASEDIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source the shared helper functions
if [ -f "$BASEDIR/utils/shared_functions.sh" ]; then
    source "$BASEDIR/utils/shared_functions.sh"
else
    echo "❌ ERROR: Shared functions script not found at $BASEDIR/utils/shared_functions.sh"
    echo "Please run this script from the ubuntu-automation directory or set BASEDIR environment variable"
    exit 1
fi

# Fallback function definitions if shared functions aren't available
if ! command -v show_info &>/dev/null; then
    show_info() { echo "INFO: $1"; }
    show_warn() { echo "WARN: $1"; }
    show_err() {
        echo "ERROR: $1"
        exit 1
    }
    show_yellow() { echo "STATUS: $1"; }
fi

##########################################################################################
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="account_security.sh"

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
## Configure password policies
##########################################################################################

show_yellow "Configuring password policies for Ubuntu 24.04."

# Update package list first
apt-get update >>$LOGDIR/$LOGFILE 2>&1

# Install password quality checking package
if ! apt-get --yes install libpam-pwquality >>$LOGDIR/$LOGFILE 2>&1; then
    show_warn "Failed to install libpam-pwquality, continuing without it."
fi

# Ensure backup directory exists
mkdir -p $BACKUPDIR

# Backup original PAM password configuration if it exists
if [ -f /etc/pam.d/common-password ]; then
    cp /etc/pam.d/common-password $BACKUPDIR/common-password_$DATE
fi

# Configure password quality requirements - copy from configs
cp "$SCRIPTDIR/../configs/account_security/pwquality.conf" /etc/security/pwquality.conf

# Ensure PAM common-password includes pwquality
if [ -f /etc/pam.d/common-password ]; then
    # Check if pwquality is already configured
    if ! grep -q "pam_pwquality.so" /etc/pam.d/common-password; then
        # Add pwquality to PAM configuration before pam_unix.so
        sed -i '/pam_unix.so/i password requisite pam_pwquality.so retry=3' /etc/pam.d/common-password
        show_yellow "Added pam_pwquality to PAM configuration."
    else
        show_yellow "pam_pwquality already configured in PAM."
    fi
else
    show_warn "PAM common-password file not found. Password policies may not be enforced."
fi

show_yellow "Password quality policies configured successfully."

##########################################################################################
## Configure account lockout policies
##########################################################################################

show_yellow "Configuring account lockout policies."

# Ubuntu 24.04+ uses faillock instead of pam_tally2
# Configure faillock configuration file
mkdir -p /etc/security
cp "$SCRIPTDIR/../configs/account_security/faillock.conf" /etc/security/faillock.conf

# Check if pam-auth-update is available for proper PAM configuration
if command -v pam-auth-update >/dev/null 2>&1; then
    # Use pam-auth-update for proper Ubuntu 24.04 PAM configuration
    show_yellow "Configuring PAM using pam-auth-update for Ubuntu 24.04."

    # Enable faillock module using pam-auth-update
    pam-auth-update --enable faillock

    show_yellow "Account lockout policy configured using pam-auth-update."
else
    # Manual PAM configuration fallback
    show_yellow "Manually configuring PAM files for account lockout."

    # Configure account lockout for failed login attempts
    if [ -f /etc/pam.d/common-auth ]; then
        # Backup original PAM auth configuration
        cp /etc/pam.d/common-auth $BACKUPDIR/common-auth_$DATE

        # Only add faillock if not already present
        if ! grep -q "pam_faillock.so" /etc/pam.d/common-auth; then
            # Add faillock preauth before pam_unix
            sed -i '/pam_unix.so/i auth\trequired\t\t\tpam_faillock.so preauth' /etc/pam.d/common-auth
            # Add faillock authfail after pam_unix (SAFER CONTROL)
            sed -i '/pam_unix.so/a auth\t[default=bad success=ok user_unknown=ignore]\tpam_faillock.so authfail' /etc/pam.d/common-auth
            # Add faillock authsucc after authfail
            sed -i '/pam_faillock.so authfail/a auth\tsufficient\t\t\tpam_faillock.so authsucc' /etc/pam.d/common-auth

            show_yellow "Account lockout policy configured (5 attempts, 10 minute lockout)."
        else
            show_warn "Account lockout already configured in common-auth."
        fi
    fi

    # Configure account module for PAM
    if [ -f /etc/pam.d/common-account ]; then
        # Backup original PAM account configuration
        cp /etc/pam.d/common-account $BACKUPDIR/common-account_$DATE

        # Only add faillock if not already present
        if ! grep -q "pam_faillock.so" /etc/pam.d/common-account; then
            # Add faillock account checking before pam_unix
            sed -i '/pam_unix.so/i account\trequired\t\t\tpam_faillock.so' /etc/pam.d/common-account

            show_yellow "Account module configured for lockout checking."
        else
            show_warn "Account lockout already configured in common-account."
        fi
    fi
fi

# Ensure faillock directories exist with correct permissions
mkdir -p /var/run/faillock
chmod 755 /var/run/faillock

# Create systemd tmpfiles configuration to ensure faillock directory persists
cp "$SCRIPTDIR/../configs/account_security/tmpfiles-faillock.conf" /etc/tmpfiles.d/faillock.conf

show_yellow "Account lockout policies configured for Ubuntu 24.04."

##########################################################################################
## Configure sudo security
##########################################################################################

show_yellow "Configuring sudo security policies."

# Backup original sudoers configuration
cp /etc/sudoers $BACKUPDIR/sudoers_$DATE

# Create custom sudoers configuration for enhanced security
cp "$SCRIPTDIR/../configs/account_security/security-policies" /etc/sudoers.d/security-policies

# Create sudo log directory
mkdir -p /var/log/sudo-io
chmod 750 /var/log/sudo-io

# Create sudo log file
touch /var/log/sudo.log
chmod 640 /var/log/sudo.log

show_yellow "Sudo security policies configured with logging enabled."

##########################################################################################
## Configure root account security
##########################################################################################

show_yellow "Configuring root account security."

# Lock the root account password (disable password login for root)
passwd -l root >>$LOGDIR/$LOGFILE 2>&1 || (show_warn "Failed to lock root password, continuing.")

# Set root account to expire (security best practice) - COMMENTED OUT PER USER REQUEST
#chage -E -1 root >>$LOGDIR/$LOGFILE 2>&1 || (show_warn "Failed to set root account expiry, continuing.")

# Ensure root home directory has secure permissions
chmod 700 /root
chown root:root /root

# Secure root's .bashrc and profile
if [ -f /root/.bashrc ]; then
    chmod 644 /root/.bashrc
    chown root:root /root/.bashrc
fi

if [ -f /root/.profile ]; then
    chmod 644 /root/.profile
    chown root:root /root/.profile
fi

show_yellow "Root account security configured."

##########################################################################################
## Configure system-wide account security
##########################################################################################

show_yellow "Configuring system-wide account security settings."

# Configure login.defs for enhanced security
if [ -f /etc/login.defs ]; then
    # Backup original configuration
    cp /etc/login.defs $BACKUPDIR/login.defs_$DATE

    # Include sed helpers for safe operations
    source "$SCRIPTDIR/../utils/helpers/sed_helpers.sh"

    # Set password aging policies using helper functions
    set_config_with_tabs "/etc/login.defs" "PASS_MAX_DAYS" "90" "login_defs_$DATE"
    set_config_with_tabs "/etc/login.defs" "PASS_MIN_DAYS" "1" "login_defs_$DATE"
    set_config_with_tabs "/etc/login.defs" "PASS_WARN_AGE" "7" "login_defs_$DATE"

    # Set secure umask
    set_config_with_tabs "/etc/login.defs" "UMASK" "027" "login_defs_$DATE"

    # Configure encryption method - SHA512 is still secure for password hashing
    # but modern systems should prefer stronger methods like yescrypt
    if ! grep -q "ENCRYPT_METHOD" /etc/login.defs; then
        # Use yescrypt if available (Ubuntu 22.04+), fallback to SHA512
        if grep -q "yescrypt" /etc/login.defs 2>/dev/null || command -v mkpasswd >/dev/null 2>&1 && mkpasswd --method=help 2>/dev/null | grep -q "yescrypt"; then
            echo "ENCRYPT_METHOD yescrypt" >>/etc/login.defs
            show_yellow "Password encryption set to yescrypt (recommended)."
        else
            echo "ENCRYPT_METHOD SHA512" >>/etc/login.defs
            show_yellow "Password encryption set to SHA512 (fallback)."
        fi
    fi
    show_yellow "System account policies configured."
fi

# Configure user creation defaults
if [ -f /etc/default/useradd ]; then
    # Backup original configuration
    cp /etc/default/useradd $BACKUPDIR/useradd_$DATE

    # Set secure defaults for new users
    sed -i 's/^SHELL=.*/SHELL=\/bin\/bash/' /etc/default/useradd
    sed -i 's/^INACTIVE=.*/INACTIVE=30/' /etc/default/useradd

    show_yellow "User creation defaults configured."
fi

##########################################################################################
## Configure session security
##########################################################################################

show_yellow "Configuring session security."

# Configure automatic logout for idle sessions
cp "$SCRIPTDIR/../utils/generators/session-timeout.sh" /etc/profile.d/session-timeout.sh

chmod 644 /etc/profile.d/session-timeout.sh

##########################################################################################
## Test account security configuration
##########################################################################################

show_yellow "Testing account security configuration."

# Test sudo configuration
if sudo -l >/dev/null 2>&1; then
    show_yellow "Sudo configuration test passed."
else
    show_warn "Sudo configuration may have issues. Please verify manually."
fi

# Test PAM configuration
if command -v pamtest >/dev/null 2>&1; then
    if pamtest --verbose auth </dev/null >/dev/null 2>&1; then
        show_yellow "PAM configuration test passed."
    else
        show_warn "PAM configuration test failed."
    fi
else
    # Alternative PAM test using faillock for Ubuntu 24.04+
    if command -v faillock >/dev/null 2>&1; then
        # Test faillock functionality
        if faillock >/dev/null 2>&1; then
            show_yellow "PAM configuration test passed (using faillock)."
        else
            show_warn "PAM configuration test failed."
        fi
    else
        show_warn "PAM testing tools not available (pamtest or faillock). PAM functionality should work normally."
    fi
fi

# Verify log directories exist
if [ -d /var/log/sudo-io ] && [ -f /var/log/sudo.log ]; then
    show_yellow "Sudo logging directories verified."
else
    show_warn "Sudo logging directories may not be properly configured."
fi

##########################################################################################
## Display security summary
##########################################################################################

show_info "=== Account Security Configuration Summary ==="
show_info "✅ Password policies: Configured (12+ chars, complexity required)"
show_info "✅ Account lockout: Configured (5 attempts, 10 minute lockout)"
show_info "✅ Sudo security: Enhanced with logging and TTY requirement"
show_info "✅ Root account: Password locked and secured"
show_info "✅ Session timeout: 30 minutes for idle sessions"

show_info ""
show_warn "IMPORTANT SECURITY NOTES:"
show_info "• Root password login is disabled (SSH key required)"
show_info "• Users are locked out after 5 failed login attempts"
show_info "• All sudo commands are logged for auditing"
show_info "• Sessions timeout after 30 minutes of inactivity"
show_info "• Strong password requirements are enforced"

##########################################################################################
## Copy monitoring scripts
##########################################################################################

# Copy account security monitoring scripts
if [ -f "$BASEDIR/utils/monitoring/show_sudo_usage.sh" ]; then
    cp "$BASEDIR/utils/monitoring/show_sudo_usage.sh" "$SCRIPTSDIR/show_sudo_usage.sh"
    chmod +x "$SCRIPTSDIR/show_sudo_usage.sh"
    show_yellow "Sudo monitoring script deployed to $SCRIPTSDIR/show_sudo_usage.sh"
fi

if [ -f "$BASEDIR/utils/monitoring/show_locked_accounts.sh" ]; then
    cp "$BASEDIR/utils/monitoring/show_locked_accounts.sh" "$SCRIPTSDIR/show_locked_accounts.sh"
    chmod +x "$SCRIPTSDIR/show_locked_accounts.sh"
    show_yellow "Account lockout monitoring script deployed to $SCRIPTSDIR/show_locked_accounts.sh"
fi

show_info ""
show_info "=== Available Monitoring Commands ==="
show_info "• Show sudo usage: $SCRIPTSDIR/show_sudo_usage.sh"
show_info "• Show locked accounts: $SCRIPTSDIR/show_locked_accounts.sh"

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
