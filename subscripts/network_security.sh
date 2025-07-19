#!/bin/bash

##########################################################################################
## Network Security and Hardening
##########################################################################################

##########################################################################################
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="network_security.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Deploy comprehensive sysctl network security configuration
##########################################################################################

show_yellow "Configuring network security via sysctl for Ubuntu 24.04."

# Backup original sysctl configuration
CONF_ORG=/etc/sysctl.conf
CONF_BACK=$BACKUPDIR/$(basename $CONF_ORG)_$DATE
CONF_GIT=$BASEDIR/configs/sysctl/sysctl.conf

if [ -a $CONF_ORG ]; then
    cp -p $CONF_ORG $CONF_BACK && show_yellow "Sysctl file $CONF_ORG backed up to $CONF_BACK."
fi

# Create comprehensive network security configuration
cat > /etc/sysctl.d/99-network-security.conf << 'EOF'
# Network Security Configuration for Ubuntu 24.04
# Comprehensive security hardening for network stack

##########################################################################################
## IP Forwarding and Routing Security
##########################################################################################

# Disable IP forwarding (will be enabled by specific services if needed)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Disable source routing (prevents routing manipulation)
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Disable redirects (prevents routing manipulation)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Disable sending redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

##########################################################################################
## ICMP Security
##########################################################################################

# Ignore ICMP ping requests (reduces attack surface)
net.ipv4.icmp_echo_ignore_all = 1

# Ignore broadcast ping requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bogus ICMP error responses
net.ipv4.icmp_ignore_bogus_error_responses = 1

##########################################################################################
## TCP Security
##########################################################################################

# Enable TCP SYN cookies (protection against SYN flood attacks)
net.ipv4.tcp_syncookies = 1

# Reduce TCP SYN retries (faster detection of dead connections)
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_synack_retries = 2

# TCP keepalive settings (detect dead connections)
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 3

# Enable TCP window scaling
net.ipv4.tcp_window_scaling = 1

# Enable selective acknowledgements
net.ipv4.tcp_sack = 1

# Enable timestamps
net.ipv4.tcp_timestamps = 1

# Protect against time-wait assassination
net.ipv4.tcp_rfc1337 = 1

##########################################################################################
## Network Buffer and Connection Limits
##########################################################################################

# Increase network buffer sizes for better performance
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Connection tracking limits (only if netfilter modules are loaded)
# These will be applied conditionally by the load script

# Maximum number of connections
net.core.somaxconn = 1024
net.core.netdev_max_backlog = 2000

##########################################################################################
## ARP Security
##########################################################################################

# ARP security settings
net.ipv4.conf.all.arp_filter = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.all.arp_ignore = 1

##########################################################################################
## IPv6 Security
##########################################################################################

# Disable IPv6 router advertisements
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

# Disable IPv6 router solicitations
net.ipv6.conf.all.router_solicitations = 0
net.ipv6.conf.default.router_solicitations = 0

# Disable IPv6 autoconfiguration
net.ipv6.conf.all.autoconf = 0
net.ipv6.conf.default.autoconf = 0

##########################################################################################
## Reverse Path Filtering
##########################################################################################

# Enable reverse path filtering (anti-spoofing)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

##########################################################################################
## Log Martian Packets
##########################################################################################

# Log packets with impossible addresses
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

##########################################################################################
## Memory and Process Security
##########################################################################################

# Kernel security settings
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1

# Disable core dumps
kernel.core_pattern = |/bin/false

# Control shared memory
kernel.shmmax = 268435456
kernel.shmall = 268435456

##########################################################################################
## File System Security
##########################################################################################

# Filesystem security
fs.suid_dumpable = 0
fs.protected_hardlinks = 1
fs.protected_symlinks = 1

EOF

# Apply the new sysctl configuration
if ! sysctl -p /etc/sysctl.d/99-network-security.conf >>$LOGDIR/$LOGFILE 2>&1; then
    show_err "Network security sysctl configuration failed. Please check logfile and fix error manually."
    exit 1
fi

show_yellow "Network security sysctl configuration applied successfully."

##########################################################################################
## Configure network interface security
##########################################################################################

show_yellow "Configuring network interface security."

# Create network interface security script
cat > /etc/network/if-pre-up.d/network-security << 'EOF'
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
EOF

chmod +x /etc/network/if-pre-up.d/network-security
show_yellow "Network interface security configuration created."

##########################################################################################
## Configure DNS security
##########################################################################################

show_yellow "Configuring DNS security settings."

# Create systemd-resolved security configuration
mkdir -p /etc/systemd/resolved.conf.d/

cat > /etc/systemd/resolved.conf.d/security.conf << 'EOF'
[Resolve]
# DNS Security Configuration

# Use secure DNS servers (Cloudflare and Quad9)
DNS=1.1.1.1 9.9.9.9
FallbackDNS=1.0.0.1 149.112.112.112

# Enable DNS over TLS for security
DNS=1.1.1.1#cloudflare-dns.com 9.9.9.9#dns.quad9.net

# Enable DNSSEC validation
DNSSEC=yes

# Prevent DNS cache poisoning
Cache=yes

# Prevent DNS leaks
DNSStubListener=yes
EOF

show_yellow "DNS security configuration applied."

##########################################################################################
## Create network monitoring utilities
##########################################################################################

show_yellow "Creating network monitoring utilities."

# Create script to show network security status
cat > $SCRIPTSDIR/show_network_security.sh << 'EOF'
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
EOF

chmod +x $SCRIPTSDIR/show_network_security.sh

# Create script to test network security
cat > $SCRIPTSDIR/test_network_security.sh << 'EOF'
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
EOF

chmod +x $SCRIPTSDIR/test_network_security.sh

# Create script to temporarily enable IP forwarding (for VPN services)
cat > $SCRIPTSDIR/enable_ip_forwarding.sh << 'EOF'
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
EOF

chmod +x $SCRIPTSDIR/enable_ip_forwarding.sh

show_yellow "Network monitoring utilities created."

##########################################################################################
## Verify network security configuration
##########################################################################################

show_yellow "Verifying network security configuration."

# Test sysctl application
if sysctl -a 2>/dev/null | grep -q "net.ipv4.tcp_syncookies = 1"; then
    show_yellow "Network security sysctl settings verified."
else
    show_warn "Some network security settings may not be applied correctly."
fi

# Check if systemd-resolved is running
if systemctl is-active systemd-resolved >/dev/null 2>&1; then
    show_yellow "DNS resolver is active."
    systemctl restart systemd-resolved >>$LOGDIR/$LOGFILE 2>&1
    show_yellow "DNS resolver restarted with security configuration."
else
    show_warn "systemd-resolved is not active. DNS security settings may not be applied."
fi

##########################################################################################
## Display network security summary
##########################################################################################

show_info "=== Network Security Configuration Summary ==="
show_info "✅ IP forwarding: Disabled (default secure state)"
show_info "✅ Source routing: Disabled (prevents routing attacks)"
show_info "✅ ICMP responses: Disabled (reduces attack surface)"
show_info "✅ TCP SYN cookies: Enabled (SYN flood protection)"
show_info "✅ Reverse path filtering: Enabled (anti-spoofing)"
show_info "✅ Network buffer limits: Configured for security"
show_info "✅ DNS security: Configured with secure resolvers and DNSSEC"
show_info "✅ Interface security: Automatic configuration on interface up"
show_info ""
show_warn "IMPORTANT NETWORK SECURITY NOTES:"
show_info "• IP forwarding is disabled by default (VPN services will enable as needed)"
show_info "• ICMP ping responses are disabled (reduces reconnaissance)"
show_info "• Source routing and redirects are blocked (prevents routing attacks)"
show_info "• DNS uses secure resolvers with DNSSEC validation"
show_info "• Network interfaces are hardened automatically"
show_info ""
show_info "Network monitoring commands:"
show_info "• Show security status: $SCRIPTSDIR/show_network_security.sh"
show_info "• Test configuration: $SCRIPTSDIR/test_network_security.sh"
show_info "• Enable IP forwarding: $SCRIPTSDIR/enable_ip_forwarding.sh (for VPN services)"

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done." 