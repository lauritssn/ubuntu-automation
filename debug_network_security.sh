#!/bin/bash

##########################################################################################
## Network Security Debug Script
##########################################################################################

echo "=== Network Security Debug Information ==="
echo "Timestamp: $(date)"
echo

##########################################################################################
## Check sysctl TCP SYN cookies specifically
##########################################################################################

echo "1. Testing TCP SYN cookies setting:"
echo "   Current value: $(cat /proc/sys/net/ipv4/tcp_syncookies 2>/dev/null || echo 'FAILED TO READ')"
echo "   Direct sysctl check: $(sysctl net.ipv4.tcp_syncookies 2>/dev/null || echo 'FAILED')"

echo
echo "2. Testing sysctl -a command that script uses:"
if sysctl -a 2>/dev/null | grep -q "net.ipv4.tcp_syncookies = 1"; then
    echo "   ✅ sysctl -a | grep tcp_syncookies test: PASSED"
    sysctl -a 2>/dev/null | grep "net.ipv4.tcp_syncookies"
else
    echo "   ❌ sysctl -a | grep tcp_syncookies test: FAILED"
    echo "   Raw sysctl -a output for tcp_syncookies:"
    sysctl -a 2>/dev/null | grep tcp_syncookies || echo "   No tcp_syncookies found in sysctl -a output"
fi

echo
echo "3. Check if sysctl configuration file exists and was applied:"
if [ -f /etc/sysctl.d/99-network-security.conf ]; then
    echo "   ✅ Network security sysctl file exists"
    echo "   TCP SYN cookies setting in file:"
    grep "tcp_syncookies" /etc/sysctl.d/99-network-security.conf || echo "   Not found in config file"
else
    echo "   ❌ Network security sysctl file missing: /etc/sysctl.d/99-network-security.conf"
fi

echo
echo "4. Check if sysctl settings were actually applied:"
echo "   Last sysctl reload: $(systemctl show systemd-sysctl --property=ActiveEnterTimestamp --value)"
echo "   Sysctl service status:"
systemctl status systemd-sysctl --no-pager -l | head -10

echo
echo "5. Check for sysctl errors in journal:"
echo "   Recent sysctl errors:"
journalctl -u systemd-sysctl --since "1 hour ago" --no-pager | tail -10

echo
echo "6. Test manual sysctl reload:"
echo "   Attempting to reload network security config:"
if sysctl -p /etc/sysctl.d/99-network-security.conf 2>&1; then
    echo "   ✅ Manual reload successful"
else
    echo "   ❌ Manual reload failed"
fi

echo
echo "7. Check all network security related sysctl settings:"
echo "   All network security settings currently active:"
sysctl net.ipv4.ip_forward net.ipv4.tcp_syncookies net.ipv4.conf.all.rp_filter net.ipv4.icmp_echo_ignore_all 2>/dev/null || echo "   Some settings failed to read"

echo
echo "=== Network Security Debug Complete ===" 