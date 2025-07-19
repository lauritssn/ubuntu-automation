#!/bin/bash

##########################################################################################
## Master Debug Script for Ubuntu Automation Issues
##########################################################################################

echo "========================================================================"
echo "Ubuntu Automation - Master Debug Script"
echo "========================================================================"
echo "Timestamp: $(date)"
echo "System: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Uptime: $(uptime | cut -d, -f1)"
echo

##########################################################################################
## Run Network Security Debug
##########################################################################################

echo "========================================================================"
echo "1. NETWORK SECURITY DEBUGGING"
echo "========================================================================"

# Test sysctl TCP SYN cookies specifically
echo "Testing TCP SYN cookies setting:"
echo "   Current value: $(cat /proc/sys/net/ipv4/tcp_syncookies 2>/dev/null || echo 'FAILED TO READ')"
echo "   Direct sysctl check: $(sysctl net.ipv4.tcp_syncookies 2>/dev/null || echo 'FAILED')"

echo
echo "Testing the exact command from the script:"
if sysctl -a 2>/dev/null | grep -q "net.ipv4.tcp_syncookies = 1"; then
    echo "   ✅ Network security verification: PASSED"
    sysctl -a 2>/dev/null | grep "net.ipv4.tcp_syncookies"
else
    echo "   ❌ Network security verification: FAILED"
    echo "   Raw sysctl output for tcp_syncookies:"
    sysctl -a 2>/dev/null | grep tcp_syncookies || echo "   No tcp_syncookies found"
    
    echo
    echo "   Possible causes:"
    echo "   - sysctl configuration not applied"
    echo "   - Different output format than expected"
    echo "   - Permission issues reading /proc/sys"
    
    echo
    echo "   Manual fix attempts:"
    if [ -f /etc/sysctl.d/99-network-security.conf ]; then
        echo "   Reloading network security config:"
        sysctl -p /etc/sysctl.d/99-network-security.conf
    else
        echo "   ❌ Network security config file missing"
    fi
fi

##########################################################################################
## Run Account Security Debug
##########################################################################################

echo
echo "========================================================================"
echo "2. ACCOUNT SECURITY DEBUGGING"
echo "========================================================================"

echo "A. SUDO CONFIGURATION:"
echo
echo "Testing sudo -l command (exact command from script):"
if sudo -l >/dev/null 2>&1; then
    echo "   ✅ Sudo test: PASSED"
else
    echo "   ❌ Sudo test: FAILED"
    echo "   Error details:"
    sudo -l 2>&1 | head -5
    
    echo
    echo "   Possible causes and fixes:"
    echo "   - User not in sudoers"
    echo "   - Sudo configuration syntax error"
    echo "   - TTY requirement blocking non-interactive use"
    
    echo
    echo "   Checking sudo configuration:"
    if visudo -c >/dev/null 2>&1; then
        echo "   ✅ Sudo syntax: Valid"
    else
        echo "   ❌ Sudo syntax: Invalid"
        visudo -c 2>&1
    fi
    
    echo
    echo "   Manual fix attempt:"
    echo "   Current user groups: $(groups)"
    echo "   Sudo group members: $(getent group sudo | cut -d: -f4)"
fi

echo
echo "B. PAM CONFIGURATION:"
echo
echo "Testing pamtest availability:"
if command -v pamtest >/dev/null 2>&1; then
    echo "   ✅ pamtest: Available"
    echo "   Running PAM test:"
    if pamtest --verbose auth </dev/null >/dev/null 2>&1; then
        echo "   ✅ PAM test: PASSED"
    else
        echo "   ❌ PAM test: FAILED"
        pamtest --verbose auth </dev/null 2>&1 | head -10
    fi
else
    echo "   ❌ pamtest: NOT AVAILABLE"
    echo "   This is likely the cause of the PAM test failure"
    
    echo
    echo "   Alternative PAM checks:"
    if [ -f /etc/pam.d/common-auth ]; then
        echo "   ✅ PAM auth config exists"
        echo "   pam_tally2 configuration:"
        grep pam_tally2 /etc/pam.d/common-auth || echo "   No pam_tally2 found"
    else
        echo "   ❌ PAM auth config missing"
    fi
    
    echo
    echo "   Checking if pam_tally2 works:"
    if command -v pam_tally2 >/dev/null 2>&1; then
        echo "   ✅ pam_tally2 available"
        echo "   Current status: $(pam_tally2 2>/dev/null | head -3 || echo 'Command failed')"
    else
        echo "   ❌ pam_tally2 not available"
        echo "   Checking for newer faillock:"
        command -v faillock >/dev/null 2>&1 && echo "   ✅ faillock available" || echo "   ❌ faillock not available"
    fi
fi

##########################################################################################
## System Environment Check
##########################################################################################

echo
echo "========================================================================"
echo "3. SYSTEM ENVIRONMENT CHECK"
echo "========================================================================"

echo "Runtime environment:"
echo "   User: $(whoami) (UID: $(id -u))"
echo "   Groups: $(groups)"
echo "   Shell: $SHELL"
echo "   TTY: $(tty 2>/dev/null || echo 'No TTY')"
echo "   Container: $(grep -q container /proc/1/cgroup 2>/dev/null && echo 'Yes' || echo 'No')"
echo "   Virtualization: $(systemd-detect-virt 2>/dev/null || echo 'Unknown')"

echo
echo "Package verification:"
packages="sudo libpam-google-authenticator libpam-pwquality pamtester"
for package in $packages; do
    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
        echo "   ✅ $package: installed"
    else
        echo "   ❌ $package: NOT installed"
    fi
done

##########################################################################################
## Proposed Solutions
##########################################################################################

echo
echo "========================================================================"
echo "4. PROPOSED SOLUTIONS"
echo "========================================================================"

echo "Based on the debug results above, here are the recommended fixes:"
echo

echo "For Network Security issue:"
echo "   1. Check if the sysctl format differs on your system"
echo "   2. Manually reload: sysctl -p /etc/sysctl.d/99-network-security.conf"
echo "   3. Alternative test: sysctl net.ipv4.tcp_syncookies | grep -q '= 1'"

echo
echo "For Sudo Configuration issue:"
echo "   1. If TTY required: Remove 'requiretty' from /etc/sudoers.d/security-policies"
echo "   2. If user not in sudoers: usermod -aG sudo <username>"
echo "   3. Check syntax with: visudo -c"

echo
echo "For PAM Configuration issue:"
echo "   1. Install pamtester: apt-get install pamtester"
echo "   2. Alternative: Skip pamtest check - it's informational only"
echo "   3. For Ubuntu 24.04: Consider using faillock instead of pam_tally2"

echo
echo "========================================================================"
echo "Debug complete. Save this output and apply fixes as needed."
echo "========================================================================" 