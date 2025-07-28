#!/bin/bash

# Reset account lockout for a specific user

if [ $# -eq 0 ]; then
    echo "Usage: $0 <username>"
    echo "Example: $0 john"
    exit 1
fi

USERNAME="$1"

# Check if user exists
if ! id "$USERNAME" &>/dev/null; then
    echo "Error: User '$USERNAME' does not exist"
    exit 1
fi

# Reset the lockout counter using faillock (Ubuntu 24.04+)
faillock --user="$USERNAME" --reset

if [ $? -eq 0 ]; then
    echo "Account lockout reset for user: $USERNAME"
    echo "The user can now attempt to login again."
else
    echo "Failed to reset account lockout for user: $USERNAME"
    exit 1
fi 