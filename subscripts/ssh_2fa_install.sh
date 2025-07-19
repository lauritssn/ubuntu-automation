#!/bin/bash

##########################################################################################
## SSH 2FA with Authenticator Installation
##########################################################################################

##########################################################################################
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="ssh_2fa_install.sh"

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
## Install Authenticator PAM module
##########################################################################################

show_yellow "Installing Authenticator PAM module for SSH 2FA."

# Install required packages
apt-get --yes install libpam-google-authenticator qrencode >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Installation of Authenticator failed. Please check logfile and fix error manually.")

show_yellow "Authenticator PAM module installed successfully."

##########################################################################################
## Configure PAM for SSH 2FA
##########################################################################################

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
## Configure SSH daemon for 2FA and security
##########################################################################################

show_yellow "Configuring SSH daemon for 2FA and security."

# Backup SSH configuration (already done in general_system_settings.sh, but double-check)
CONF_SSH_ORG=/etc/ssh/sshd_config
CONF_SSH_BACK=$BACKUPDIR/$(basename $CONF_SSH_ORG)_2fa_$DATE

if [ -a $CONF_SSH_ORG ]; then
    cp -p $CONF_SSH_ORG $CONF_SSH_BACK && show_yellow "SSH conf file $CONF_SSH_ORG backed up to $CONF_SSH_BACK."
fi

# Enable challenge-response authentication
sed -i 's/^#ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' $CONF_SSH_ORG
sed -i 's/^ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/' $CONF_SSH_ORG

# Enable keyboard-interactive authentication
sed -i 's/^#KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/' $CONF_SSH_ORG
sed -i 's/^KbdInteractiveAuthentication no/KbdInteractiveAuthentication yes/' $CONF_SSH_ORG

# Configure authentication methods (publickey + keyboard-interactive for 2FA)
if ! grep -q "AuthenticationMethods" $CONF_SSH_ORG; then
    echo "" >> $CONF_SSH_ORG
    echo "# SSH 2FA Configuration" >> $CONF_SSH_ORG
    echo "AuthenticationMethods publickey,keyboard-interactive" >> $CONF_SSH_ORG
    show_yellow "SSH 2FA authentication methods configured."
else
    sed -i 's/^#AuthenticationMethods.*/AuthenticationMethods publickey,keyboard-interactive/' $CONF_SSH_ORG
    sed -i 's/^AuthenticationMethods.*/AuthenticationMethods publickey,keyboard-interactive/' $CONF_SSH_ORG
    show_yellow "SSH 2FA authentication methods updated."
fi

# Disable root SSH login for security
show_yellow "Disabling root SSH login for security."
sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' $CONF_SSH_ORG
sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' $CONF_SSH_ORG
show_warn "ROOT SSH LOGIN HAS BEEN DISABLED"
show_info "Use regular user accounts created with add_user.sh for SSH access"

show_yellow "SSH daemon configured for 2FA authentication with root login disabled."

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

##########################################################################################
## Test SSH configuration
##########################################################################################

show_yellow "Testing SSH configuration."

# Test SSH configuration
sshd -t 2>>$LOGDIR/$LOGFILE
if [ $? -eq 0 ]; then
    show_yellow "SSH configuration test passed."
else
    show_err "SSH configuration test failed. Check logfile: $LOGDIR/$LOGFILE"
    show_warn "2FA may not work correctly. Please review SSH configuration."
fi

##########################################################################################
## Display important information
##########################################################################################

show_info "=== SSH 2FA Installation Complete ==="

show_warn "IMPORTANT SETUP STEPS:"
show_info "1. SSH 2FA is configured for non-root users only"
show_info "2. Root SSH login has been DISABLED for security"
show_info "3. Create users with: $SCRIPTSDIR/add_user.sh --interactive"
show_info "4. All new users will get sudo access, 2FA, and VPN configuration"
show_info "5. Use 'sudo su -' to become root after logging in as a regular user"
show_info ""
show_warn "SECURITY NOTES:"
show_info "• SSH now requires BOTH public key AND 2FA code for user accounts"
show_info "• Root SSH access is completely disabled"
show_info "• Only users created with add_user.sh can access the system via SSH"
show_info "• All users get sudo privileges and can become root with 'sudo su -'"
show_info "• Test user access before closing current session"
show_info ""
show_warn "NEXT STEPS:"
show_info "1. Create at least one user account: $SCRIPTSDIR/add_user.sh --interactive"
show_info "2. Add the user's SSH public key to their authorized_keys file"
show_info "3. Test SSH login with the new user in a NEW terminal session"
show_info "4. Verify sudo access works: sudo su -"
show_info ""
show_warn "SSH will be restarted to apply 2FA configuration..."

# Restart SSH service to apply configuration
systemctl restart ssh >>$LOGDIR/$LOGFILE 2>&1
if [ $? -eq 0 ]; then
    show_yellow "SSH service restarted successfully."
else
    show_err "Failed to restart SSH service. Check logfile: $LOGDIR/$LOGFILE"
fi

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done." 