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