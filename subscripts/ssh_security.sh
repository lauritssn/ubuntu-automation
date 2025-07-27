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
SUBSCRIPT="ssh_security.sh"

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
## Disable message of the day
##########################################################################################
show_yellow "Disable message of the day."
systemctl disable motd-news.service >$LOGDIR/$LOGFILE 2>&1 || (show_err "Stop message of the day service failed. Please check logfile and fix error manually.")
sed -i 's/^ENABLED=.*/ENABLED=0/' /etc/default/motd-news >$LOGDIR/$LOGFILE 2>&1 || (show_err "Disable message of the day service failed. Please check logfile and fix error manually.")
show_yellow "Message of the day disabled."

##########################################################################################
## Configure SSH daemon security hardening
##########################################################################################

show_yellow "Configuring SSH daemon security hardening for Ubuntu 24.04."

# Create SSH privilege separation directory
show_yellow "Creating SSH privilege separation directory."
mkdir -p /run/sshd
chmod 755 /run/sshd
chown root:root /run/sshd
show_yellow "SSH privilege separation directory /run/sshd created."

# Backup SSH configuration
CONF_SSH_ORG=/etc/ssh/sshd_config
CONF_SSH_BACK=$BACKUPDIR/$(basename $CONF_SSH_ORG)_ssh_security_$DATE

if [ -a $CONF_SSH_ORG ]; then
    cp -p $CONF_SSH_ORG $CONF_SSH_BACK && show_yellow "SSH conf file $CONF_SSH_ORG backed up to $CONF_SSH_BACK."
fi

# Create comprehensive SSH security configuration
cat >/etc/ssh/sshd_config <<'EOF'
# SSH Security Configuration for Ubuntu 24.04
# Comprehensive security hardening

##########################################################################################
## Basic SSH Configuration
##########################################################################################

# SSH Protocol and Port
Protocol 2
Port 22

# Listening addresses
#ListenAddress 0.0.0.0
#ListenAddress ::

##########################################################################################
## Authentication Security
##########################################################################################

# Root login security
PermitRootLogin no

# Public key authentication (required for security)
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Password authentication (disabled for security)
PasswordAuthentication no
PermitEmptyPasswords no

# Challenge response for 2FA
ChallengeResponseAuthentication yes
KbdInteractiveAuthentication yes

# Authentication methods (require public key + 2FA)
AuthenticationMethods publickey,keyboard-interactive

##########################################################################################
## Connection Security
##########################################################################################

# Maximum authentication attempts
MaxAuthTries 5

# Login grace time (time to complete authentication)
LoginGraceTime 2m

# Client connection settings
ClientAliveInterval 300
ClientAliveCountMax 2

# Maximum concurrent sessions per connection
MaxSessions 2

# Maximum concurrent connections
MaxStartups 10:30:60

##########################################################################################
## Security Features
##########################################################################################

# Disable potentially dangerous features
AllowAgentForwarding no
AllowTcpForwarding no
PermitTunnel no
X11Forwarding no
X11DisplayOffset 10
X11UseLocalhost yes

# Disable user environment processing
PermitUserEnvironment no

# Compression (disabled for security)
Compression no

##########################################################################################
## Logging and Monitoring
##########################################################################################

# Logging configuration
SyslogFacility AUTH
LogLevel INFO

# Log all connections
PrintMotd no
PrintLastLog yes

##########################################################################################
## Crypto and Protocol Security
##########################################################################################

# Host key algorithms (secure options only)
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256

# Key exchange algorithms (secure options only)
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512

# Ciphers (secure options only)
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

# Message authentication codes (secure options only)
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512

##########################################################################################
## User and Group Restrictions
##########################################################################################

# User and group access control
# DenyUsers baduser1 baduser2
# AllowUsers gooduser1 gooduser2
# DenyGroups badgroup1 badgroup2
# AllowGroups ssh-users sudo

##########################################################################################
## Banner and Information
##########################################################################################

# Banner file (optional)
#Banner /etc/issue.net

# Version information
DebianBanner no

##########################################################################################
## Subsystem Configuration
##########################################################################################

# SFTP subsystem (secure file transfer)
Subsystem sftp /usr/lib/openssh/sftp-server

EOF

show_yellow "SSH daemon security configuration applied."

##########################################################################################
## Configure SSH 2FA if requested
##########################################################################################

if [[ "$DO_SSH_2FA" =~ [Yy]$ ]]; then
    show_yellow "Configuring SSH 2FA with Google Authenticator."

    # Configure PAM for SSH 2FA
    show_yellow "Configuring PAM for SSH 2FA."

    # Backup original PAM SSH configuration
    CONF_PAM_SSH_ORG=/etc/pam.d/sshd
    CONF_PAM_SSH_BACK=$BACKUPDIR/$(basename $CONF_PAM_SSH_ORG)_$DATE

    if [ -a $CONF_PAM_SSH_ORG ]; then
        cp -p $CONF_PAM_SSH_ORG $CONF_PAM_SSH_BACK && show_yellow "PAM SSH conf file $CONF_PAM_SSH_ORG backed up to $CONF_PAM_SSH_BACK."
    fi

    # Add Authenticator to PAM configuration
    if ! grep -q "auth required pam_google_authenticator.so" $CONF_PAM_SSH_ORG; then
        # Add Authenticator as required authentication
        echo "# Authenticator 2FA" >>$CONF_PAM_SSH_ORG
        echo "auth required pam_google_authenticator.so" >>$CONF_PAM_SSH_ORG
        show_yellow "Authenticator added to PAM SSH configuration."
    else
        show_warn "Authenticator already configured in PAM SSH."
    fi

    ##########################################################################################
    ## Create 2FA setup script for users
    ##########################################################################################

    show_yellow "Creating 2FA setup script for users."

    # Create script to setup 2FA for a user
    cp utils/ssh/setup_user_2fa.sh $SCRIPTSDIR/setup_user_2fa.sh

    chmod +x $SCRIPTSDIR/setup_user_2fa.sh
    show_yellow "2FA setup script created at $SCRIPTSDIR/setup_user_2fa.sh"

    ##########################################################################################
    ## Create 2FA management scripts
    ##########################################################################################

    show_yellow "Creating 2FA management scripts."

    # Create script to show 2FA QR codes
    cp utils/ssh/show_2fa_qr.sh $SCRIPTSDIR/show_2fa_qr.sh

    chmod +x $SCRIPTSDIR/show_2fa_qr.sh
    show_yellow "2FA QR display script created at $SCRIPTSDIR/show_2fa_qr.sh"

    # Create script to disable 2FA for a user
    cp utils/ssh/disable_user_2fa.sh $SCRIPTSDIR/disable_user_2fa.sh

    chmod +x $SCRIPTSDIR/disable_user_2fa.sh
    show_yellow "2FA disable script created at $SCRIPTSDIR/disable_user_2fa.sh"

else
    show_yellow "SSH 2FA not requested, skipping 2FA configuration."
fi

##########################################################################################
## Create SSH security monitoring utilities
##########################################################################################

show_yellow "Creating SSH security monitoring utilities."

# Create script to show SSH security status
cp utils/monitoring/show_ssh_security.sh $SCRIPTSDIR/show_ssh_security.sh

chmod +x $SCRIPTSDIR/show_ssh_security.sh

# Create script to test SSH configuration
cp utils/monitoring/test_ssh_security.sh $SCRIPTSDIR/test_ssh_security.sh

chmod +x $SCRIPTSDIR/test_ssh_security.sh

# Create script to show failed SSH attempts
cp utils/monitoring/show_ssh_attacks.sh $SCRIPTSDIR/show_ssh_attacks.sh

chmod +x $SCRIPTSDIR/show_ssh_attacks.sh

show_yellow "SSH security monitoring utilities created."

##########################################################################################
## Test SSH configuration
##########################################################################################

show_yellow "Testing SSH configuration."

# Test SSH configuration syntax
sshd -t 2>>$LOGDIR/$LOGFILE
if [ $? -eq 0 ]; then
    show_yellow "SSH configuration test passed."
else
    show_err "SSH configuration test failed. Check logfile: $LOGDIR/$LOGFILE"
    show_warn "SSH may not work correctly. Please review SSH configuration."
fi

# Verify critical settings
if grep -q "^PermitRootLogin no" $CONF_SSH_ORG; then
    show_yellow "Root login is properly disabled."
else
    show_warn "Root login may not be properly disabled."
fi

if grep -q "^PasswordAuthentication no" $CONF_SSH_ORG; then
    show_yellow "Password authentication is properly disabled."
else
    show_warn "Password authentication may not be properly disabled."
fi

##########################################################################################
## Restart SSH service
##########################################################################################

show_yellow "Restarting SSH service to apply security configuration."

systemctl restart ssh >>$LOGDIR/$LOGFILE 2>&1
if [ $? -eq 0 ]; then
    show_yellow "SSH service restarted successfully."
else
    show_err "Failed to restart SSH service. Check logfile: $LOGDIR/$LOGFILE"
fi

# Verify SSH service is running
if systemctl is-active ssh >/dev/null 2>&1; then
    show_yellow "SSH service is active and running."
else
    show_err "SSH service is not running properly."
fi

##########################################################################################
## Display SSH security summary
##########################################################################################

show_info "=== SSH Security Configuration Summary ==="
show_info "✅ Root login: DISABLED for security"
show_info "✅ Password authentication: DISABLED (key-only access)"
show_info "✅ Public key authentication: ENABLED"
show_info "✅ Connection limits: Configured (max 5 attempts, 2 min grace time)"
show_info "✅ Dangerous features: DISABLED (X11, TCP forwarding, tunneling)"
show_info "✅ Cryptography: Modern secure algorithms only"
show_info "✅ Logging: Enhanced for security monitoring"

if [[ "$DO_SSH_2FA" =~ [Yy]$ ]]; then
    show_info "✅ 2FA: CONFIGURED with Google Authenticator"
    show_info "✅ 2FA Management: Scripts created for user management"
else
    show_warn "⚠️  2FA: NOT CONFIGURED (consider enabling for enhanced security)"
fi

show_info ""
show_warn "CRITICAL SSH SECURITY NOTES:"
show_info "• Root SSH login is COMPLETELY DISABLED"
show_info "• Only SSH key authentication is allowed (no passwords)"
show_info "• Users must have valid SSH keys to access the system"

if [[ "$DO_SSH_2FA" =~ [Yy]$ ]]; then
    show_info "• SSH requires BOTH SSH key AND 2FA code"
    show_info "• Users need authenticator app (Google Authenticator, Authy, etc.)"
fi

show_info "• All SSH access is logged for security auditing"
show_info "• Failed attempts are monitored and can trigger blocks"
show_info ""
show_warn "NEXT STEPS:"
show_info "1. Create user accounts: $SCRIPTSDIR/add_user.sh --interactive"
show_info "2. Add SSH public keys to user ~/.ssh/authorized_keys files"

if [[ "$DO_SSH_2FA" =~ [Yy]$ ]]; then
    show_info "3. Setup 2FA for users: $SCRIPTSDIR/setup_user_2fa.sh <username>"
    show_info "4. Test 2FA login in a NEW terminal session"
else
    show_info "3. Test SSH key login in a NEW terminal session"
fi

show_info ""
show_info "SSH monitoring commands:"
show_info "• Show SSH status: $SCRIPTSDIR/show_ssh_security.sh"
show_info "• Test configuration: $SCRIPTSDIR/test_ssh_security.sh"
show_info "• Show attacks: $SCRIPTSDIR/show_ssh_attacks.sh"

if [[ "$DO_SSH_2FA" =~ [Yy]$ ]]; then
    show_info "• Show 2FA QR code: $SCRIPTSDIR/show_2fa_qr.sh <username>"
fi

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
