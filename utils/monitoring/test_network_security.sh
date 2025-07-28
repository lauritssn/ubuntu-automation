#!/bin/bash

# Test network security configuration

echo "=== Network Security Tests ==="
echo

echo "Testing IP forwarding (should be disabled):"
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "0" ]; then
    echo "✅ IPv4 forwarding is disabled"
else
    echo "❌ IPv4 forwarding is enabled (potential security risk)"
fi

echo
echo "Testing ICMP response (should be disabled):"
if [ "$(cat /proc/sys/net/ipv4/icmp_echo_ignore_all)" = "1" ]; then
    echo "✅ ICMP ping responses are disabled"
else
    echo "❌ ICMP ping responses are enabled"
fi

echo
echo "Testing SYN cookies (should be enabled):"
if [ "$(cat /proc/sys/net/ipv4/tcp_syncookies)" = "1" ]; then
    echo "✅ TCP SYN cookies are enabled"
else
    echo "❌ TCP SYN cookies are disabled"
fi

echo
echo "Testing reverse path filtering:"
rp_filter_all=$(cat /proc/sys/net/ipv4/conf/all/rp_filter)
if [ "$rp_filter_all" = "1" ]; then
    echo "✅ Reverse path filtering is enabled"
else
    echo "❌ Reverse path filtering is disabled"
fi

echo
echo "Testing source routing (should be disabled):"
source_route=$(cat /proc/sys/net/ipv4/conf/all/accept_source_route)
if [ "$source_route" = "0" ]; then
    echo "✅ Source routing is disabled"
else
    echo "❌ Source routing is enabled (security risk)"
fi

echo
echo "Network security test completed."