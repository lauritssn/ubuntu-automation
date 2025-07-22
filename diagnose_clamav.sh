#!/bin/bash

# ClamAV Diagnostic Script
# Helps troubleshoot ClamAV daemon startup issues

echo "=== ClamAV Diagnostic Report ==="
echo "Generated: $(date)"
echo "Hostname: $(hostname)"
echo "====================================="
echo

# 1. Service Status
echo "1. SERVICE STATUS:"
echo "   clamav-daemon.service:"
systemctl status clamav-daemon.service 2>/dev/null || echo "   Service not found or failed"
echo
echo "   clamav-freshclam.service:"
systemctl status clamav-freshclam.service 2>/dev/null || echo "   Service not found or failed"
echo

# 2. Database Files
echo "2. DATABASE FILES:"
echo "   Contents of /var/lib/clamav/:"
if [ -d "/var/lib/clamav" ]; then
    ls -la /var/lib/clamav/ 2>/dev/null || echo "   Cannot list directory"
    echo
    echo "   File sizes and dates:"
    find /var/lib/clamav -type f -exec ls -lh {} \; 2>/dev/null || echo "   No files found"
else
    echo "   Directory /var/lib/clamav does not exist"
fi
echo

# 3. Broken Symlinks
echo "3. BROKEN SYMBOLIC LINKS:"
if find /var/lib/clamav -type l ! -e 2>/dev/null | grep -q .; then
    echo "   Found broken symlinks:"
    find /var/lib/clamav -type l ! -e -ls 2>/dev/null
else
    echo "   No broken symlinks found"
fi
echo

# 4. Configuration Files
echo "4. CONFIGURATION:"
echo "   Key clamd.conf settings:"
if [ -f "/etc/clamav/clamd.conf" ]; then
    grep -E "^(DatabaseDirectory|LocalSocket|User|LogFile)" /etc/clamav/clamd.conf 2>/dev/null || echo "   Cannot read clamd.conf"
else
    echo "   clamd.conf not found"
fi
echo

# 5. Permissions
echo "5. PERMISSIONS:"
echo "   ClamAV directories:"
ls -ld /var/lib/clamav /var/log/clamav /var/run/clamav 2>/dev/null || echo "   Some directories missing"
echo

# 6. Recent Logs
echo "6. RECENT LOGS:"
echo "   Last 10 clamav-daemon journal entries:"
journalctl -u clamav-daemon.service --no-pager -n 10 2>/dev/null || echo "   No journal entries found"
echo

# 7. Process Check
echo "7. RUNNING PROCESSES:"
echo "   ClamAV processes:"
ps aux | grep -E "(clam|maldet)" | grep -v grep || echo "   No ClamAV processes running"
echo

# 8. Maldet Status
echo "8. MALDET STATUS:"
if command -v maldet >/dev/null 2>&1; then
    echo "   Maldet is installed (independent scanning with optional ClamAV engine)"
    echo "   Maldet signature directory:"
    ls -la /usr/local/maldetect/sigs/ 2>/dev/null | head -5 || echo "   Cannot list Maldet signatures"
    sig_count=$(find /usr/local/maldetect/sigs -name "*.ndb" -o -name "*.hdb" -o -name "*.ldb" 2>/dev/null | wc -l)
    echo "   Signature files: $sig_count"
else
    echo "   Maldet is not installed"
fi
echo

echo "=== TROUBLESHOOTING STEPS ==="
echo "If ClamAV daemon won't start:"
echo "1. Ensure basic databases exist: ls -la /var/lib/clamav/*.cvd /var/lib/clamav/*.cld"
echo "2. Check file ownership: chown -R clamav:clamav /var/lib/clamav"
echo "3. Run freshclam manually: freshclam --log=/tmp/freshclam.log"
echo "4. Try starting manually: systemctl start clamav-daemon.service"
echo "5. View detailed logs: journalctl -u clamav-daemon.service -f"
echo

echo "=== Quick Fix Commands ==="
echo "# Fix ownership and restart:"
echo "sudo chown -R clamav:clamav /var/lib/clamav"
echo "sudo systemctl restart clamav-daemon.service"
echo
echo "# Download fresh ClamAV databases:"
echo "sudo systemctl stop clamav-daemon.service"
echo "sudo freshclam"
echo "sudo systemctl start clamav-daemon.service"
