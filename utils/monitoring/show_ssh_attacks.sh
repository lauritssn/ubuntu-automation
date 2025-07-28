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