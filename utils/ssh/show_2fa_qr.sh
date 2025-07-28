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