#!/bin/bash

##########################################################################################
## Source shared helper functions
##########################################################################################

# Set BASEDIR early for shared functions to use
export BASEDIR="${BASEDIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source the shared helper functions
if [ -f "$BASEDIR/utils/shared_functions.sh" ]; then
    source "$BASEDIR/utils/shared_functions.sh"
else
    echo "❌ ERROR: Shared functions script not found at $BASEDIR/utils/shared_functions.sh"
    echo "Please run this script from the ubuntu-automation directory or set BASEDIR environment variable"
    exit 1
fi

# Fallback function definitions if shared functions aren't available
if ! command -v show_info &>/dev/null; then
    show_info() { echo "INFO: $1"; }
    show_warn() { echo "WARN: $1"; }
    show_err() {
        echo "ERROR: $1"
        exit 1
    }
    show_yellow() { echo "STATUS: $1"; }
fi

##########################################################################################
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="network_security.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/srv/apps/logs
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

# Create enhanced network security configuration following Ubuntu 24.04 conventions
# Use 30- prefix to complement system 10-network-security.conf without conflicts
cp "$SCRIPTDIR/../configs/network_security/30-enhanced-network-security.conf" /etc/sysctl.d/30-enhanced-network-security.conf

# Apply the new sysctl configuration
if ! sysctl -p /etc/sysctl.d/30-enhanced-network-security.conf >>$LOGDIR/$LOGFILE 2>&1; then
    show_err "Enhanced network security sysctl configuration failed. Please check logfile and fix error manually."
    exit 1
fi

show_yellow "Network security sysctl configuration applied successfully."

##########################################################################################
## Configure network interface security
##########################################################################################

show_yellow "Configuring network interface security."

# Create network interface security script
cp "$SCRIPTDIR/../utils/generators/network-interface-security.sh" /etc/network/if-pre-up.d/network-security

chmod +x /etc/network/if-pre-up.d/network-security
show_yellow "Network interface security configuration created."

##########################################################################################
## Configure DNS security
##########################################################################################

show_yellow "Configuring DNS security settings."

# Create systemd-resolved security configuration
mkdir -p /etc/systemd/resolved.conf.d/

cp "$SCRIPTDIR/../configs/network_security/resolved-security.conf" /etc/systemd/resolved.conf.d/security.conf

show_yellow "DNS security configuration applied."

##########################################################################################
## Create network monitoring utilities
##########################################################################################

show_yellow "Creating network monitoring utilities."

# Create script to show network security status
cp "$SCRIPTDIR/../utils/monitoring/show_network_security.sh" $SCRIPTSDIR/show_network_security.sh

chmod +x $SCRIPTSDIR/show_network_security.sh

# Create script to test network security
cp "$SCRIPTDIR/../utils/monitoring/test_network_security.sh" $SCRIPTSDIR/test_network_security.sh

chmod +x $SCRIPTSDIR/test_network_security.sh

# Create script to temporarily enable IP forwarding (for VPN services)
cp "$SCRIPTDIR/../utils/network/enable_ip_forwarding.sh" $SCRIPTSDIR/enable_ip_forwarding.sh

chmod +x $SCRIPTSDIR/enable_ip_forwarding.sh

show_yellow "Network monitoring utilities created."

##########################################################################################
## Verify network security configuration
##########################################################################################

show_yellow "Verifying network security configuration."

# Test sysctl application - use direct sysctl check for better compatibility
tcp_syncookies=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null)
if [ "$tcp_syncookies" = "1" ]; then
    show_yellow "Network security sysctl settings verified."
elif sysctl -a 2>/dev/null | grep -q "net.ipv4.tcp_syncookies = 1"; then
    show_yellow "Network security sysctl settings verified (alternative check)."
else
    show_warn "Some network security settings may not be applied correctly."
    show_yellow "Attempting to reload enhanced network security configuration..."
    if [ -f /etc/sysctl.d/30-enhanced-network-security.conf ]; then
        sysctl -p /etc/sysctl.d/30-enhanced-network-security.conf >>$LOGDIR/$LOGFILE 2>&1
        # Re-test after reload
        tcp_syncookies_retry=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null)
        if [ "$tcp_syncookies_retry" = "1" ]; then
            show_yellow "Network security settings applied successfully after reload."
        fi
    fi
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
## Configure iptables logging for fail2ban port scan detection
##########################################################################################

show_yellow "Configuring iptables logging for port scan detection."

# Create iptables rules for port scan detection and logging
# These rules will generate log entries that fail2ban can monitor

# Create PORTSCAN chain for organizing scan detection rules
iptables -N PORTSCAN 2>/dev/null || true

# Log and detect various types of port scans
# SYN scans (most common)
iptables -A INPUT -p tcp --tcp-flags SYN,ACK SYN -m limit --limit 5/min --limit-burst 7 -j LOG --log-prefix "PORTSCAN: " --log-level 4

# Stealth scans - FIN scan
iptables -A INPUT -p tcp --tcp-flags ALL FIN -m limit --limit 3/min --limit-burst 5 -j LOG --log-prefix "STEALTH_SCAN: " --log-level 4

# Stealth scans - NULL scan
iptables -A INPUT -p tcp --tcp-flags ALL NONE -m limit --limit 3/min --limit-burst 5 -j LOG --log-prefix "STEALTH_SCAN: " --log-level 4

# Stealth scans - XMAS scan
iptables -A INPUT -p tcp --tcp-flags ALL FIN,PSH,URG -m limit --limit 3/min --limit-burst 5 -j LOG --log-prefix "STEALTH_SCAN: " --log-level 4

# Port probing detection - excessive connection attempts to closed ports
iptables -A INPUT -p tcp --dport 1:1023 -m state --state NEW -m recent --name portscan --set
iptables -A INPUT -p tcp --dport 1:1023 -m state --state NEW -m recent --name portscan --rcheck --seconds 60 --hitcount 10 -j LOG --log-prefix "PORT_PROBE: " --log-level 4

# Log potential nmap detection attempts
iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j LOG --log-prefix "NMAP_SCAN: " --log-level 4

# Detect SYN flood attempts
iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT
iptables -A INPUT -p tcp --syn -j LOG --log-prefix "SYN_FLOOD: " --log-level 4

show_yellow "Iptables logging rules for port scan detection configured."

# Make iptables rules persistent
if command -v iptables-save >/dev/null 2>&1; then
    # Create directory for persistent rules if it doesn't exist
    mkdir -p /etc/iptables

    # Save current rules
    iptables-save >/etc/iptables/rules.v4 2>/dev/null || true

    # Install iptables-persistent if not already installed
    if ! dpkg -l | grep -q iptables-persistent; then
        show_yellow "Installing iptables-persistent for rule persistence."
        export DEBIAN_FRONTEND=noninteractive
        if ! apt_install_safe "iptables-persistent" "$LOGDIR/$LOGFILE"; then
            show_warn "Failed to install iptables-persistent"
        fi
    fi

    show_yellow "Iptables rules made persistent."
else
    show_warn "iptables-save not found, rules may not persist after reboot."
fi

##########################################################################################
## Display network security summary
##########################################################################################

show_info "=== Network Security Configuration Summary ==="
show_info "✅ IP forwarding: Disabled by default (VPN services can enable via 40-*.conf)"
show_info "✅ Source routing: Disabled (prevents routing attacks)"
show_info "✅ ICMP responses: Disabled (reduces attack surface)"
show_info "✅ TCP SYN cookies: Enabled (SYN flood protection)"
show_info "✅ Reverse path filtering: Enabled (anti-spoofing)"
show_info "✅ Network buffer limits: Configured for security"
show_info "✅ DNS security: Configured with secure resolvers and DNSSEC"
show_info "✅ Interface security: Automatic configuration on interface up"
show_info "✅ Port scan detection: Iptables logging rules configured for fail2ban"
show_info ""
show_warn "IMPORTANT NETWORK SECURITY NOTES:"
show_info "• IP forwarding is disabled by default (VPN services will enable as needed)"
show_info "• ICMP ping responses are disabled (reduces reconnaissance)"
show_info "• Source routing and redirects are blocked (prevents routing attacks)"
show_info "• DNS uses secure resolvers with DNSSEC validation"
show_info "• Network interfaces are hardened automatically"
show_info "• Port scanning attempts are logged and detected by fail2ban"
show_info ""
show_info "Network monitoring commands:"
show_info "• Show security status: $SCRIPTSDIR/show_network_security.sh"
show_info "• Test configuration: $SCRIPTSDIR/test_network_security.sh"
show_info "• Enable IP forwarding: $SCRIPTSDIR/enable_ip_forwarding.sh (for VPN services)"
show_info "• Check fail2ban port scan protection: sudo fail2ban-client status portscan"

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
