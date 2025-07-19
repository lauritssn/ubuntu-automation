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
    LOGDIR=/tmp
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
## Create sudo user if requested
##########################################################################################

if [[ "$DO_CREATE_SUDO_USER" =~ [Yy]$ ]] && [ -n "$SUDO_USERNAME" ] && [ -n "$SUDO_PASSWORD" ]; then
    show_yellow "Creating sudo user: $SUDO_USERNAME"
    
    # Create the user
    useradd -m -s /bin/bash "$SUDO_USERNAME" >>$LOGDIR/$LOGFILE 2>&1
    if [ $? -eq 0 ]; then
        show_yellow "User $SUDO_USERNAME created successfully."
        
        # Set password
        echo "$SUDO_USERNAME:$SUDO_PASSWORD" | chpasswd
        if [ $? -eq 0 ]; then
            show_yellow "Password set for user $SUDO_USERNAME."
        else
            show_err "Failed to set password for user $SUDO_USERNAME."
        fi
        
        # Add user to sudo group
        usermod -aG sudo "$SUDO_USERNAME" >>$LOGDIR/$LOGFILE 2>&1
        if [ $? -eq 0 ]; then
            show_yellow "User $SUDO_USERNAME added to sudo group."
        else
            show_err "Failed to add user $SUDO_USERNAME to sudo group."
        fi
        
        # Create .ssh directory and set proper permissions
        USER_HOME="/home/$SUDO_USERNAME"
        USER_SSH_DIR="$USER_HOME/.ssh"
        
        mkdir -p "$USER_SSH_DIR"
        chown "$SUDO_USERNAME:$SUDO_USERNAME" "$USER_SSH_DIR"
        chmod 700 "$USER_SSH_DIR"
        
        # Create authorized_keys file
        touch "$USER_SSH_DIR/authorized_keys"
        chown "$SUDO_USERNAME:$SUDO_USERNAME" "$USER_SSH_DIR/authorized_keys"
        chmod 600 "$USER_SSH_DIR/authorized_keys"
        
        show_yellow "SSH directory created for user $SUDO_USERNAME."
        show_info "Add your public key to: $USER_SSH_DIR/authorized_keys"
        
    else
        show_err "Failed to create user $SUDO_USERNAME."
    fi
fi

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
## Configure SSH daemon for 2FA
##########################################################################################

show_yellow "Configuring SSH daemon for 2FA."

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

# Disable root login if sudo user was created
if [[ "$DO_CREATE_SUDO_USER" =~ [Yy]$ ]] && [ -n "$SUDO_USERNAME" ]; then
    show_yellow "Disabling root SSH login since sudo user $SUDO_USERNAME was created."
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' $CONF_SSH_ORG
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' $CONF_SSH_ORG
    show_warn "ROOT SSH LOGIN HAS BEEN DISABLED"
    show_info "Use sudo user '$SUDO_USERNAME' for SSH access and 'sudo su -' for root privileges"
fi

show_yellow "SSH daemon configured for 2FA authentication."

##########################################################################################
## Create 2FA setup script for root user
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

# Check if user exists
if ! id "$USERNAME" &>/dev/null; then
    echo "Error: User '$USERNAME' does not exist"
    exit 1
fi

echo "Setting up Authenticator 2FA for user: $USERNAME"
echo "======================================================="

# Switch to the user and run google-authenticator
sudo -u "$USERNAME" -H bash << 'USER_SCRIPT'
cd ~
echo "Running Authenticator setup..."
echo "Please answer the following questions:"
echo "1. Do you want authentication tokens to be time-based? (y/n) -> y"
echo "2. Do you want me to update your ~/.google_authenticator file? (y/n) -> y"
echo "3. Do you want to disallow multiple uses of the same authentication token? (y/n) -> y"
echo "4. By default, tokens are good for 30 seconds. Do you want to increase time skew? (y/n) -> n"
echo "5. Do you want to enable rate-limiting? (y/n) -> y"
echo ""
echo "Setting up Authenticator..."
google-authenticator -t -d -f -r 3 -R 30 -W

if [ $? -eq 0 ]; then
    echo ""
    echo "Authenticator setup completed successfully!"
    echo "Your secret key and QR code have been displayed above."
    echo "Please scan the QR code with your Authenticator app (Google Authenticator, Authy, etc.)."
    echo ""
    echo "IMPORTANT: Save your emergency scratch codes in a safe place!"
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
## Setup 2FA for root user (only if no sudo user created)
##########################################################################################

if [[ "$DO_CREATE_SUDO_USER" =~ [Yy]$ ]] && [ -n "$SUDO_USERNAME" ]; then
    show_yellow "Skipping root 2FA setup since sudo user $SUDO_USERNAME was created."
    show_info "Root SSH login is disabled. Configure 2FA for sudo user instead."
else
    show_yellow "Setting up 2FA for root user."
    
    # Generate 2FA for root user non-interactively
    if [ ! -f /root/.google_authenticator ]; then
        google-authenticator -t -d -f -r 3 -R 30 -W -q
        
        if [ $? -eq 0 ]; then
            show_yellow "Authenticator configured for root user."
            show_info "QR code and secret key saved to /root/.google_authenticator"
            show_warn "IMPORTANT: You must scan the QR code with your Authenticator app!"
            
            # Display QR code if qrencode is available
            if command -v qrencode >/dev/null 2>&1; then
                echo ""
                show_info "QR Code for root user:"
                SECRET=$(head -1 /root/.google_authenticator)
                HOSTNAME=$(hostname)
                qrencode -t ANSIUTF8 "otpauth://totp/root@${HOSTNAME}?secret=${SECRET}&issuer=SSH2FA"
                echo ""
            fi
            
            show_warn "Emergency scratch codes:"
            tail -n 5 /root/.google_authenticator
            echo ""
            show_warn "SAVE THESE EMERGENCY CODES IN A SAFE PLACE!"
            echo ""
        else
            show_err "Failed to configure Authenticator for root user."
        fi
    else
        show_warn "Authenticator already configured for root user."
    fi
fi

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

GOOGLE_AUTH_FILE="/home/$USERNAME/.google_authenticator"
if [ "$USERNAME" = "root" ]; then
    GOOGLE_AUTH_FILE="/root/.google_authenticator"
fi

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

GOOGLE_AUTH_FILE="/home/$USERNAME/.google_authenticator"
if [ "$USERNAME" = "root" ]; then
    GOOGLE_AUTH_FILE="/root/.google_authenticator"
fi

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

if [[ "$DO_CREATE_SUDO_USER" =~ [Yy]$ ]] && [ -n "$SUDO_USERNAME" ]; then
    show_warn "IMPORTANT SETUP STEPS (with sudo user):"
    show_info "1. Sudo user '$SUDO_USERNAME' has been created"
    show_info "2. Root SSH login has been DISABLED for security"
    show_info "3. Add your public key to: /home/$SUDO_USERNAME/.ssh/authorized_keys"
    show_info "4. Install an Authenticator app on your mobile device (Google Authenticator, Authy, etc.)"
    show_info "5. Setup 2FA for sudo user: $SCRIPTSDIR/setup_user_2fa.sh $SUDO_USERNAME"
    show_info "6. Test SSH login with sudo user in a NEW terminal session before closing this one"
    show_info "7. Use 'sudo su -' to become root after logging in as $SUDO_USERNAME"
    show_info ""
    show_warn "LOGIN INSTRUCTIONS:"
    show_info "• SSH as: ssh -i ~/.ssh/your_key $SUDO_USERNAME@server"
    show_info "• Enter your 2FA code when prompted"
    show_info "• Use 'sudo su -' for root access"
    show_info ""
    show_warn "NOTE: Root 2FA was NOT configured since root SSH login is disabled"
else
    show_warn "IMPORTANT SETUP STEPS (root user):"
    show_info "1. Root user 2FA is already configured"
    show_info "2. Install an Authenticator app on your mobile device (Google Authenticator, Authy, etc.)"
    show_info "3. Scan the QR code displayed above for root user"
    show_info "4. Test SSH login in a NEW terminal session before closing this one"
fi

show_info "5. For additional users, run: $SCRIPTSDIR/setup_user_2fa.sh <username>"
show_info ""
show_warn "SECURITY NOTES:"
show_info "• SSH now requires BOTH public key AND 2FA code"
show_info "• Save emergency scratch codes in a secure location"
show_info "• Test login before closing current session"
show_info "• Use 'show_2fa_qr.sh' to redisplay QR codes"
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