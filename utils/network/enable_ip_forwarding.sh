#!/bin/bash

# Temporarily enable IP forwarding for VPN services
# This should only be used by VPN installation scripts

echo "Enabling IP forwarding for VPN services..."

# Enable IPv4 forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl -w net.ipv4.ip_forward=1

# Enable IPv6 forwarding
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
sysctl -w net.ipv6.conf.all.forwarding=1

echo "IP forwarding enabled. This will be reset on reboot unless made permanent."
echo "VPN services should make this permanent in their own configuration."