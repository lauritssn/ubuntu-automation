#!/bin/bash

# Show current network security configuration

echo "=== Network Security Status ==="
echo

echo "IP Forwarding Status:"
echo "IPv4 forwarding: $(cat /proc/sys/net/ipv4/ip_forward)"
echo "IPv6 forwarding: $(cat /proc/sys/net/ipv6/conf/all/forwarding)"
echo

echo "ICMP Security:"
echo "Ignore pings: $(cat /proc/sys/net/ipv4/icmp_echo_ignore_all)"
echo "Ignore broadcasts: $(cat /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts)"
echo

echo "TCP Security:"
echo "SYN cookies: $(cat /proc/sys/net/ipv4/tcp_syncookies)"
echo "SYN retries: $(cat /proc/sys/net/ipv4/tcp_syn_retries)"
echo

echo "Reverse Path Filtering:"
for iface in $(ls /proc/sys/net/ipv4/conf/ | grep -v all | grep -v default); do
    rp_filter=$(cat /proc/sys/net/ipv4/conf/$iface/rp_filter 2>/dev/null || echo "N/A")
    echo "$iface: $rp_filter"
done
echo

echo "Active Network Connections:"
netstat -tuln | head -20
echo

echo "Recent Network Security Events:"
journalctl --since "1 hour ago" | grep -i "denied\|blocked\|dropped" | tail -10