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
