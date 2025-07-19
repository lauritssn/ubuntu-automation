#!/bin/bash

##########################################################################################
## Account Security Debug Script
##########################################################################################

echo "=== Account Security Debug Information ==="
echo "Timestamp: $(date)"
echo "Current user: $(whoami)"
echo "Current UID: $(id -u)"
echo

##########################################################################################
## Debug Sudo Configuration Issue
##########################################################################################

echo "1. Debugging Sudo Configuration:"
echo

echo "   a) Test sudo -l command (what the script runs):"
if sudo -l >/dev/null 2>&1; then
    echo "   ✅ sudo -l test: PASSED"
    echo "   Sudo privileges for current user:"
    sudo -l 2>/dev/null | head -10
else
    echo "   ❌ sudo -l test: FAILED"
    echo "   Error output:"
    sudo -l 2>&1 | head -5
fi

echo
echo "   b) Check sudo configuration files:"
if [ -f /etc/sudoers ]; then
    echo "   ✅ Main sudoers file exists"
    echo "   Sudoers file permissions: $(ls -la /etc/sudoers | awk '{print $1, $3, $4}')"
else
    echo "   ❌ Main sudoers file missing"
fi

if [ -f /etc/sudoers.d/security-policies ]; then
    echo "   ✅ Security policies file exists"
    echo "   Content preview:"
    head -10 /etc/sudoers.d/security-policies
else
    echo "   ❌ Security policies file missing: /etc/sudoers.d/security-policies"
fi

echo
echo "   c) Test sudo configuration syntax:"
if visudo -c >/dev/null 2>&1; then
    echo "   ✅ Sudo configuration syntax is valid"
else
    echo "   ❌ Sudo configuration syntax errors:"
    visudo -c 2>&1
fi

echo
echo "   d) Check sudo logging setup:"
if [ -d /var/log/sudo-io ]; then
    echo "   ✅ Sudo I/O log directory exists"
    echo "   Permissions: $(ls -ld /var/log/sudo-io | awk '{print $1, $3, $4}')"
else
    echo "   ❌ Sudo I/O log directory missing"
fi

if [ -f /var/log/sudo.log ]; then
    echo "   ✅ Sudo log file exists"
    echo "   Permissions: $(ls -l /var/log/sudo.log | awk '{print $1, $3, $4}')"
    echo "   Recent entries:"
    tail -5 /var/log/sudo.log 2>/dev/null || echo "   No recent entries"
else
    echo "   ❌ Sudo log file missing"
fi

##########################################################################################
## Debug PAM Configuration Issue
##########################################################################################

echo
echo "2. Debugging PAM Configuration:"
echo

echo "   a) Check if pamtest is available:"
if command -v pamtest >/dev/null 2>&1; then
    echo "   ✅ pamtest command found: $(which pamtest)"
    echo "   pamtest version: $(pamtest --version 2>/dev/null || echo 'Version unknown')"
else
    echo "   ❌ pamtest command not found"
    echo "   Available PAM-related commands:"
    ls /usr/bin/*pam* 2>/dev/null || echo "   No PAM commands found"
fi

echo
echo "   b) Check PAM authentication configuration:"
if [ -f /etc/pam.d/common-auth ]; then
    echo "   ✅ PAM common-auth file exists"
    echo "   Configuration:"
    cat /etc/pam.d/common-auth | grep -v "^#" | grep -v "^$"
else
    echo "   ❌ PAM common-auth file missing"
fi

echo
echo "   c) Check PAM account configuration:"
if [ -f /etc/pam.d/common-account ]; then
    echo "   ✅ PAM common-account file exists"
    echo "   Configuration:"
    cat /etc/pam.d/common-account | grep -v "^#" | grep -v "^$"
else
    echo "   ❌ PAM common-account file missing"
fi

echo
echo "   d) Check pam_tally2 configuration:"
echo "   pam_tally2 status:"
if command -v pam_tally2 >/dev/null 2>&1; then
    echo "   ✅ pam_tally2 command available"
    echo "   Current lockout status:"
    pam_tally2 --user=root 2>/dev/null || echo "   Cannot check root status"
else
    echo "   ❌ pam_tally2 command not found"
    echo "   Checking for faillock (newer alternative):"
    command -v faillock >/dev/null 2>&1 && echo "   ✅ faillock available" || echo "   ❌ faillock not available"
fi

echo
echo "   e) Test PAM manually (alternative to pamtest):"
echo "   Checking PAM modules load status:"
ldd /lib/x86_64-linux-gnu/security/pam_tally2.so 2>/dev/null && echo "   ✅ pam_tally2 module loads" || echo "   ❌ pam_tally2 module issue"

echo
echo "   f) Check for PAM errors in system logs:"
echo "   Recent PAM authentication errors:"
journalctl --since "1 hour ago" | grep -i "pam\|authentication" | tail -10 || echo "   No recent PAM errors"

##########################################################################################
## Check System Dependencies
##########################################################################################

echo
echo "3. System Dependencies Check:"
echo

echo "   a) Required packages for account security:"
for package in libpam-pwquality libpam-google-authenticator sudo; do
    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
        echo "   ✅ $package: installed"
    else
        echo "   ❌ $package: NOT installed"
    fi
done

echo
echo "   b) Check if we're running in a container or special environment:"
echo "   Virtualization: $(systemd-detect-virt 2>/dev/null || echo 'Unknown')"
echo "   Container: $(grep -q container /proc/1/cgroup 2>/dev/null && echo 'Yes' || echo 'No')"

echo
echo "=== Account Security Debug Complete ===" 