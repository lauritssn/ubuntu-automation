#!/bin/bash

##########################################################################################
## Network Security and Hardening
##########################################################################################
##
## UBUNTU CONFIGURATION FILES MODIFIED BY THIS SCRIPT:
##
## FILES CREATED/MODIFIED:
## • /etc/sysctl.d/99-network-security.conf     - Main network security configuration for sysctl
## • /etc/network/if-pre-up.d/network-security  - Network interface security script (auto-runs on interface up)
## • /etc/systemd/resolved.conf.d/security.conf - DNS security configuration for systemd-resolved
##
## RUNTIME KERNEL PARAMETERS MODIFIED (via /proc/sys/):
## • /proc/sys/net/ipv4/conf/*/rp_filter         - Reverse path filtering (per interface)
## • /proc/sys/net/ipv4/conf/*/accept_source_route - Source routing acceptance (per interface)
## • /proc/sys/net/ipv4/conf/*/accept_redirects   - ICMP redirect acceptance (per interface)
## • /proc/sys/net/ipv4/conf/*/send_redirects     - ICMP redirect sending (per interface)
## • /proc/sys/net/ipv4/conf/*/log_martians       - Martian packet logging (per interface)
## • /proc/sys/net/ipv6/conf/*/accept_ra          - IPv6 Router Advertisement acceptance (per interface)
## • /proc/sys/net/ipv6/conf/*/accept_redirects   - IPv6 redirect acceptance (per interface)
## • /proc/sys/net/ipv6/conf/*/autoconf           - IPv6 autoconfiguration (per interface)
## • /proc/sys/net/ipv4/ip_forward                - IPv4 forwarding (when IP forwarding is enabled)
## • /proc/sys/net/ipv6/conf/all/forwarding       - IPv6 forwarding (when IP forwarding is enabled)
##
## BACKUP FILES CREATED:
## • $BACKUPDIR/sysctl.conf_$DATE                - Backup of original /etc/sysctl.conf (if exists)
##
## DIRECTORIES CREATED:
## • /etc/systemd/resolved.conf.d/               - systemd-resolved configuration directory (if not exists)
##
## MONITORING SCRIPTS CREATED:
## • $SCRIPTSDIR/show_network_security.sh        - Script to display current network security status
## • $SCRIPTSDIR/test_network_security.sh        - Script to test network security configuration
## • $SCRIPTSDIR/enable_ip_forwarding.sh         - Script to temporarily enable IP forwarding (for VPN services)
##
## PERMISSIONS SET:
## • /etc/network/if-pre-up.d/network-security   - Set to executable (755)
## • $SCRIPTSDIR/show_network_security.sh        - Set to executable (755)
## • $SCRIPTSDIR/test_network_security.sh        - Set to executable (755)
## • $SCRIPTSDIR/enable_ip_forwarding.sh         - Set to executable (755)
##
## SERVICES RESTARTED:
## • systemd-resolved                            - Restarted to apply DNS security configuration
##
##########################################################################################

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

# Create comprehensive network security configuration
cp "$SCRIPTDIR/../configs/network_security/99-network-security.conf" /etc/sysctl.d/99-network-security.conf

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
cp "$SCRIPTDIR/../utils/show_network_security.sh" $SCRIPTSDIR/show_network_security.sh

chmod +x $SCRIPTSDIR/show_network_security.sh

# Create script to test network security
cp "$SCRIPTDIR/../utils/test_network_security.sh" $SCRIPTSDIR/test_network_security.sh

chmod +x $SCRIPTSDIR/test_network_security.sh

# Create script to temporarily enable IP forwarding (for VPN services)
cp "$SCRIPTDIR/../utils/enable_ip_forwarding.sh" $SCRIPTSDIR/enable_ip_forwarding.sh

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
    show_yellow "Attempting to reload network security configuration..."
    if [ -f /etc/sysctl.d/99-network-security.conf ]; then
        sysctl -p /etc/sysctl.d/99-network-security.conf >>$LOGDIR/$LOGFILE 2>&1
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
