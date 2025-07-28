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