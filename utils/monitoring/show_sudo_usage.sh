#!/bin/bash

# Show recent sudo usage for auditing

echo "=== Recent Sudo Usage ==="
echo

if [ -f /var/log/sudo.log ]; then
    echo "Recent sudo commands (last 20):"
    tail -20 /var/log/sudo.log
else
    echo "Sudo log file not found. Checking syslog..."
    journalctl --since "24 hours ago" | grep sudo | tail -10
fi

echo
echo "Sudo I/O logs location: /var/log/sudo-io/"
echo "To view detailed command logs: sudo cat /var/log/sudo-io/*/log" 