#!/bin/bash

# Network interface security configuration
# Applied before network interfaces come up

# Get the interface name
IFACE="$1"

# Skip if not a physical interface
if [[ "$IFACE" =~ ^(lo|docker|br-|veth) ]]; then
    exit 0
fi

# Configure interface-specific security settings
echo 1 > /proc/sys/net/ipv4/conf/$IFACE/rp_filter 2>/dev/null || true
echo 0 > /proc/sys/net/ipv4/conf/$IFACE/accept_source_route 2>/dev/null || true
echo 0 > /proc/sys/net/ipv4/conf/$IFACE/accept_redirects 2>/dev/null || true
echo 0 > /proc/sys/net/ipv4/conf/$IFACE/send_redirects 2>/dev/null || true
echo 1 > /proc/sys/net/ipv4/conf/$IFACE/log_martians 2>/dev/null || true

# IPv6 security for interface
echo 0 > /proc/sys/net/ipv6/conf/$IFACE/accept_ra 2>/dev/null || true
echo 0 > /proc/sys/net/ipv6/conf/$IFACE/accept_redirects 2>/dev/null || true
echo 0 > /proc/sys/net/ipv6/conf/$IFACE/autoconf 2>/dev/null || true

exit 0