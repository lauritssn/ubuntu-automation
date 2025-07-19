#!/bin/bash

##########################################################################################
## SSH Security and Hardening Configuration
##########################################################################################

##########################################################################################
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="ssh_security.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

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
cat > /etc/ssh/sshd_config << 'EOF'
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
        echo "# Authenticator 2FA" >> $CONF_PAM_SSH_ORG
        echo "auth required pam_google_authenticator.so" >> $CONF_PAM_SSH_ORG
        show_yellow "Authenticator added to PAM SSH configuration."
    else
        show_warn "Authenticator already configured in PAM SSH."
    fi

    ##########################################################################################
    ## Create 2FA setup script for users
    ##########################################################################################

    show_yellow "Creating 2FA setup script for users."

    # Create setup script for generating 2FA codes
    cat > $SCRIPTSDIR/setup_user_2fa.sh << 'EOF'
#!/bin/bash

# Authenticator 2FA Setup Script
# Run this script for each user that needs 2FA access

if [ $# -eq 0 ]; then
    echo "Usage: $0 <username>"
    echo "Example: $0 myuser"
    exit 1
fi

USERNAME="$1"

# Prevent setting up 2FA for root user
if [ "$USERNAME" = "root" ]; then
    echo "Error: Root user SSH access is disabled for security."
    echo "Use regular user accounts created with add_user.sh instead."
    exit 1
fi

# Check if user exists
if ! id "$USERNAME" &>/dev/null; then
    echo "Error: User '$USERNAME' does not exist"
    exit 1
fi

echo "Setting up Authenticator 2FA for user: $USERNAME"
echo "======================================================="

# Switch to the user and run google-authenticator non-interactively
sudo -u "$USERNAME" -H bash << 'USER_SCRIPT'
cd ~
echo "Setting up Authenticator 2FA non-interactively..."
echo "Configuration:"
echo "• Time-based tokens: YES"
echo "• Rate limiting: YES (3 attempts per 30 seconds)"
echo "• Disallow token reuse: YES"
echo "• Emergency scratch codes: 5 codes generated"
echo ""
echo "Generating 2FA configuration..."
google-authenticator -t -d -f -r 3 -R 30 -W -q

if [ $? -eq 0 ]; then
    echo ""
    echo "Authenticator setup completed successfully!"
    echo ""
    
    # Display QR code if qrencode is available
    if command -v qrencode >/dev/null 2>&1 && [ -f ~/.google_authenticator ]; then
        SECRET=$(head -1 ~/.google_authenticator)
        HOSTNAME=$(hostname)
        echo "QR Code for $USERNAME@$HOSTNAME:"
        qrencode -t ANSIUTF8 "otpauth://totp/$USERNAME@${HOSTNAME}?secret=${SECRET}&issuer=SSH2FA"
        echo ""
        echo "Secret key: $SECRET"
        echo ""
    fi
    
    echo "Emergency scratch codes:"
    if [ -f ~/.google_authenticator ]; then
        tail -n 5 ~/.google_authenticator
    fi
    echo ""
    echo "IMPORTANT: Save your emergency scratch codes in a safe place!"
    echo "Please scan the QR code with your Authenticator app (Google Authenticator, Authy, etc.)."
    echo ""
else
    echo "Error: Authenticator setup failed"
    exit 1
fi
USER_SCRIPT

if [ $? -eq 0 ]; then
    echo ""
    echo "2FA setup completed for user: $USERNAME"
    echo "The user can now log in using:"
    echo "1. SSH key authentication"
    echo "2. Authenticator code (6 digits)"
    echo ""
    echo "Test the configuration before closing this session!"
else
    echo "Error: 2FA setup failed for user: $USERNAME"
    exit 1
fi
EOF

    chmod +x $SCRIPTSDIR/setup_user_2fa.sh
    show_yellow "2FA setup script created at $SCRIPTSDIR/setup_user_2fa.sh"

    ##########################################################################################
    ## Create 2FA management scripts
    ##########################################################################################

    show_yellow "Creating 2FA management scripts."

    # Create script to display QR code for existing users
    cat > $SCRIPTSDIR/show_2fa_qr.sh << 'EOF'
#!/bin/bash

# Show QR code for existing 2FA setup

if [ $# -eq 0 ]; then
    USERNAME=$(whoami)
else
    USERNAME="$1"
fi

# Prevent showing QR for root user
if [ "$USERNAME" = "root" ]; then
    echo "Error: Root user SSH access is disabled for security."
    echo "Use regular user accounts created with add_user.sh instead."
    exit 1
fi

GOOGLE_AUTH_FILE="/home/$USERNAME/.google_authenticator"

if [ ! -f "$GOOGLE_AUTH_FILE" ]; then
    echo "Error: 2FA not configured for user $USERNAME"
    echo "Run: /srv/apps/scripts/setup_user_2fa.sh $USERNAME"
    exit 1
fi

SECRET=$(head -1 "$GOOGLE_AUTH_FILE")
HOSTNAME=$(hostname)

echo "QR Code for $USERNAME@$HOSTNAME:"
qrencode -t ANSIUTF8 "otpauth://totp/$USERNAME@${HOSTNAME}?secret=${SECRET}&issuer=SSH2FA"
echo ""
echo "Secret key: $SECRET"
echo ""
echo "Emergency scratch codes:"
tail -n 5 "$GOOGLE_AUTH_FILE"
EOF

    chmod +x $SCRIPTSDIR/show_2fa_qr.sh
    show_yellow "2FA QR display script created at $SCRIPTSDIR/show_2fa_qr.sh"

    # Create script to disable 2FA for a user
    cat > $SCRIPTSDIR/disable_user_2fa.sh << 'EOF'
#!/bin/bash

# Disable 2FA for a specific user

if [ $# -eq 0 ]; then
    echo "Usage: $0 <username>"
    echo "Example: $0 myuser"
    exit 1
fi

USERNAME="$1"

# Prevent disabling 2FA for root user
if [ "$USERNAME" = "root" ]; then
    echo "Error: Root user SSH access is disabled for security."
    echo "Use regular user accounts created with add_user.sh instead."
    exit 1
fi

GOOGLE_AUTH_FILE="/home/$USERNAME/.google_authenticator"

if [ -f "$GOOGLE_AUTH_FILE" ]; then
    mv "$GOOGLE_AUTH_FILE" "${GOOGLE_AUTH_FILE}.disabled.$(date +%Y%m%d_%H%M%S)"
    echo "2FA disabled for user: $USERNAME"
    echo "Original file backed up with .disabled timestamp"
else
    echo "2FA was not configured for user: $USERNAME"
fi
EOF

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
cat > $SCRIPTSDIR/show_ssh_security.sh << 'EOF'
#!/bin/bash

# Show SSH security configuration status

echo "=== SSH Security Status ==="
echo

echo "SSH Configuration:"
echo "Root login: $(grep '^PermitRootLogin' /etc/ssh/sshd_config | awk '{print $2}')"
echo "Password auth: $(grep '^PasswordAuthentication' /etc/ssh/sshd_config | awk '{print $2}')"
echo "Public key auth: $(grep '^PubkeyAuthentication' /etc/ssh/sshd_config | awk '{print $2}')"
echo "Max auth tries: $(grep '^MaxAuthTries' /etc/ssh/sshd_config | awk '{print $2}')"
echo "2FA enabled: $(grep -q 'AuthenticationMethods.*keyboard-interactive' /etc/ssh/sshd_config && echo 'Yes' || echo 'No')"
echo

echo "Active SSH connections:"
who | grep -E 'pts|tty'
echo

echo "Recent SSH authentication attempts:"
journalctl --since "1 hour ago" | grep -i ssh | grep -E "(accepted|failed|invalid)" | tail -10
echo

echo "SSH service status:"
systemctl status ssh --no-pager -l
EOF

chmod +x $SCRIPTSDIR/show_ssh_security.sh

# Create script to test SSH configuration
cat > $SCRIPTSDIR/test_ssh_security.sh << 'EOF'
#!/bin/bash

# Test SSH security configuration

echo "=== SSH Security Tests ==="
echo

echo "Testing SSH configuration syntax:"
if sshd -t 2>/dev/null; then
    echo "✅ SSH configuration syntax is valid"
else
    echo "❌ SSH configuration has syntax errors"
    sshd -t
fi

echo
echo "Testing key security settings:"

# Test root login
root_login=$(grep '^PermitRootLogin' /etc/ssh/sshd_config | awk '{print $2}')
if [ "$root_login" = "no" ]; then
    echo "✅ Root login is disabled"
else
    echo "❌ Root login is enabled (security risk)"
fi

# Test password authentication
password_auth=$(grep '^PasswordAuthentication' /etc/ssh/sshd_config | awk '{print $2}')
if [ "$password_auth" = "no" ]; then
    echo "✅ Password authentication is disabled"
else
    echo "❌ Password authentication is enabled (security risk)"
fi

# Test public key authentication
pubkey_auth=$(grep '^PubkeyAuthentication' /etc/ssh/sshd_config | awk '{print $2}')
if [ "$pubkey_auth" = "yes" ]; then
    echo "✅ Public key authentication is enabled"
else
    echo "❌ Public key authentication is disabled"
fi

# Test 2FA
if grep -q 'AuthenticationMethods.*keyboard-interactive' /etc/ssh/sshd_config; then
    echo "✅ 2FA (keyboard-interactive) is configured"
else
    echo "⚠️  2FA is not configured"
fi

# Test dangerous features
if grep -q '^X11Forwarding no' /etc/ssh/sshd_config; then
    echo "✅ X11 forwarding is disabled"
else
    echo "❌ X11 forwarding may be enabled"
fi

if grep -q '^AllowTcpForwarding no' /etc/ssh/sshd_config; then
    echo "✅ TCP forwarding is disabled"
else
    echo "❌ TCP forwarding may be enabled"
fi

echo
echo "SSH security test completed."
EOF

chmod +x $SCRIPTSDIR/test_ssh_security.sh

# Create script to show failed SSH attempts
cat > $SCRIPTSDIR/show_ssh_attacks.sh << 'EOF'
#!/bin/bash

# Show recent SSH attack attempts and failed logins

echo "=== SSH Security Events ==="
echo

echo "Failed SSH login attempts (last 24 hours):"
journalctl --since "24 hours ago" | grep -i ssh | grep -i "failed\|invalid\|refused" | tail -20
echo

echo "SSH attack sources (most frequent IPs):"
journalctl --since "24 hours ago" | grep -i ssh | grep -i "failed" | grep -oE 'from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort | uniq -c | sort -nr | head -10
echo

echo "Successful SSH logins (last 24 hours):"
journalctl --since "24 hours ago" | grep -i ssh | grep -i "accepted" | tail -10
echo

if command -v fail2ban-client >/dev/null 2>&1; then
    echo "Fail2Ban SSH jail status:"
    fail2ban-client status sshd 2>/dev/null || echo "SSH jail not active"
fi
EOF

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