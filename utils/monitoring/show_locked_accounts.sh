#!/bin/bash

# Show locked accounts and failed login attempts

echo "=== Account Lockout Status ==="
echo

echo "Locked user accounts (using faillock for Ubuntu 24.04+):"
if command -v faillock >/dev/null 2>&1; then
    # Show faillock status for all users
    for user in $(getent passwd | cut -d: -f1); do
        failed_attempts=$(faillock --user "$user" 2>/dev/null | grep -c "When")
        if [ "$failed_attempts" -gt 0 ]; then
            echo "$user - Failed attempts: $failed_attempts"
        fi
    done
else
    echo "faillock command not available"
fi

echo
echo "Recent failed login attempts:"
journalctl --since "24 hours ago" | grep "authentication failure" | tail -10

echo
echo "To unlock an account, use: faillock --user=<username> --reset" 