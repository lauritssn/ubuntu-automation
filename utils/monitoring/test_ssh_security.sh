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