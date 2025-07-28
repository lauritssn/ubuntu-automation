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