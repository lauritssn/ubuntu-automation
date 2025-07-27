#!/bin/bash

##########################################################################################
## Fail2Ban Status and Management Utility
##########################################################################################

# Get script directory for sourcing shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared functions if available
if [ -f "$SCRIPT_DIR/shared_functions.sh" ]; then
    source "$SCRIPT_DIR/shared_functions.sh"
else
    # Fallback color functions if shared functions not available
    show_info() { echo -e "\033[1;32m[INFO]\033[0m $1"; }
    show_warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
    show_err() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }
    show_yellow() { echo -e "\033[1;33m$1\033[0m"; }
fi

##########################################################################################
## Functions
##########################################################################################

show_service_status() {
    echo "=== Fail2Ban Service Status ==="
    if systemctl is-active --quiet fail2ban; then
        echo "✅ fail2ban service is running"
        systemctl status fail2ban --no-pager -l --lines=5
    else
        echo "❌ fail2ban service is NOT running"
        systemctl status fail2ban --no-pager -l --lines=5
    fi
    echo
}

show_active_jails() {
    echo "=== Active Jails ==="
    if command -v fail2ban-client >/dev/null 2>&1; then
        fail2ban-client status 2>/dev/null || echo "Failed to get jail status"
    else
        echo "fail2ban-client not found"
    fi
    echo
}

show_jail_details() {
    local jail="$1"
    echo "=== $jail Jail Details ==="
    if fail2ban-client status "$jail" >/dev/null 2>&1; then
        fail2ban-client status "$jail"
    else
        echo "$jail jail is not active or not configured"
    fi
    echo
}

show_recent_bans() {
    echo "=== Recent Ban Activity (last 24 hours) ==="
    if journalctl -u fail2ban --since "24 hours ago" --no-pager -q | grep -i "ban\|unban" | tail -20; then
        :
    else
        echo "No recent ban activity found"
    fi
    echo
}

show_current_banned_ips() {
    echo "=== Currently Banned IPs ==="

    # Check SSH jail
    echo "SSH (sshd) jail:"
    if iptables -L f2b-sshd -n 2>/dev/null | grep DROP; then
        :
    else
        echo "  No currently banned IPs for SSH"
    fi

    # Check WireGuard jail
    echo "WireGuard jail:"
    if iptables -L f2b-wireguard -n 2>/dev/null | grep DROP; then
        :
    else
        echo "  No currently banned IPs for WireGuard"
    fi

    # Check Recidive jail
    echo "Recidive (repeat offenders) jail:"
    if iptables -L f2b-recidive -n 2>/dev/null | grep DROP; then
        :
    else
        echo "  No currently banned IPs for recidive"
    fi

    # Check Postfix jail
    echo "Postfix SASL jail:"
    if iptables -L f2b-postfix-sasl-aggressive -n 2>/dev/null | grep DROP; then
        :
    else
        echo "  No currently banned IPs for Postfix"
    fi
    echo
}

show_fail2ban_config() {
    echo "=== Fail2Ban Configuration Summary ==="

    # Check main configuration
    if [ -f /etc/fail2ban/jail.conf ]; then
        echo "Main configuration: /etc/fail2ban/jail.conf"
        echo "Key settings:"
        echo "  Default ban time: $(grep '^bantime' /etc/fail2ban/jail.conf | head -1 | awk '{print $3}')"
        echo "  Default find time: $(grep '^findtime' /etc/fail2ban/jail.conf | head -1 | awk '{print $3}')"
        echo "  Default max retry: $(grep '^maxretry' /etc/fail2ban/jail.conf | head -1 | awk '{print $3}')"
        echo "  Backend: $(grep '^backend' /etc/fail2ban/jail.conf | head -1 | awk '{print $3}')"
        echo "  Ban time increment: $(grep '^bantime.increment' /etc/fail2ban/jail.conf | head -1 | awk '{print $3}')"
    else
        echo "❌ Main configuration file not found"
    fi

    # Check enabled jails
    echo ""
    echo "Enabled jails in configuration:"
    if [ -f /etc/fail2ban/jail.conf ]; then
        grep -A 10 "^\[.*\]$" /etc/fail2ban/jail.conf | grep -B 1 "^enabled = true" | grep "^\[" | sed 's/\[//g; s/\]//g' | while read jail; do
            echo "  ✅ $jail"
        done
    fi
    echo
}

show_security_events() {
    echo "=== Security Events Summary ==="

    # Count different types of events in the last 24 hours
    local ban_count=$(journalctl -u fail2ban --since "24 hours ago" --no-pager -q | grep -c "Ban " 2>/dev/null || echo "0")
    local unban_count=$(journalctl -u fail2ban --since "24 hours ago" --no-pager -q | grep -c "Unban " 2>/dev/null || echo "0")
    local ssh_attempts=$(journalctl --since "24 hours ago" --no-pager -q | grep -i ssh | grep -c "failed\|invalid" 2>/dev/null || echo "0")

    echo "Last 24 hours:"
    echo "  🚫 IPs banned: $ban_count"
    echo "  ✅ IPs unbanned: $unban_count"
    echo "  🔒 Failed SSH attempts: $ssh_attempts"

    # Show top attacking IPs
    echo ""
    echo "Top attacking IPs (SSH failures):"
    journalctl --since "24 hours ago" --no-pager -q | grep -i ssh | grep -i "failed" | grep -oE 'from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort | uniq -c | sort -nr | head -5 | while read count ip; do
        echo "  $ip ($count attempts)"
    done
    echo
}

unban_ip() {
    local ip="$1"
    local jail="$2"

    if [ -z "$ip" ]; then
        echo "Usage: unban_ip <ip_address> [jail_name]"
        echo "Example: unban_ip 192.168.1.100 sshd"
        return 1
    fi

    if [ -n "$jail" ]; then
        echo "Unbanning IP $ip from jail $jail..."
        fail2ban-client set "$jail" unbanip "$ip"
    else
        echo "Unbanning IP $ip from all jails..."
        fail2ban-client unban "$ip"
    fi
}

test_fail2ban_config() {
    echo "=== Testing Fail2Ban Configuration ==="

    if fail2ban-client --test; then
        echo "✅ Fail2Ban configuration test passed"
    else
        echo "❌ Fail2Ban configuration test failed"
        return 1
    fi
    echo
}

show_usage() {
    cat <<'EOF'
Fail2Ban Status and Management Utility

Usage:
    ./show_fail2ban_status.sh [command] [options]

Commands:
    status (default)    Show comprehensive fail2ban status
    jails              Show active jails and their status
    bans               Show currently banned IPs
    recent             Show recent ban/unban activity
    events             Show security events summary
    config             Show configuration summary
    test               Test fail2ban configuration
    unban <ip> [jail]  Unban an IP address
    ssh                Show SSH-specific security info
    help               Show this help message

Examples:
    ./show_fail2ban_status.sh                    # Show full status
    ./show_fail2ban_status.sh jails              # Show jail status only
    ./show_fail2ban_status.sh unban 192.168.1.100 sshd  # Unban IP from SSH jail
    ./show_fail2ban_status.sh events             # Show security events summary

Jail-specific commands:
    ./show_fail2ban_status.sh ssh                # SSH security overview
    ./show_fail2ban_status.sh wireguard          # WireGuard security status
    ./show_fail2ban_status.sh portscan           # Port scanning protection status

EOF
}

show_ssh_security() {
    echo "=== SSH Security Overview ==="

    # SSH jail status
    show_jail_details "sshd"

    # Recent SSH attacks
    echo "Recent SSH attack patterns (last 24 hours):"
    journalctl --since "24 hours ago" --no-pager -q | grep -i ssh | grep -i "failed\|invalid\|refused" | tail -10
    echo

    # SSH attack sources
    echo "Most frequent SSH attack sources:"
    journalctl --since "24 hours ago" --no-pager -q | grep -i ssh | grep -i "failed" | grep -oE 'from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort | uniq -c | sort -nr | head -10
    echo

    # Successful SSH logins
    echo "Recent successful SSH logins:"
    journalctl --since "24 hours ago" --no-pager -q | grep -i ssh | grep -i "accepted" | tail -5
    echo
}

##########################################################################################
## Main execution
##########################################################################################

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    show_warn "Some operations require root privileges. Run with sudo for full functionality."
fi

# Parse command line arguments
case "${1:-status}" in
"status" | "")
    show_service_status
    show_active_jails
    show_jail_details "sshd"
    show_jail_details "wireguard"
    show_jail_details "portscan"
    show_jail_details "recidive"
    show_current_banned_ips
    show_recent_bans
    ;;
"jails")
    show_active_jails
    show_jail_details "sshd"
    show_jail_details "wireguard"
    show_jail_details "portscan"
    show_jail_details "recidive"
    show_jail_details "postfix-sasl-aggressive"
    ;;
"bans")
    show_current_banned_ips
    ;;
"recent")
    show_recent_bans
    ;;
"events")
    show_security_events
    ;;
"config")
    show_fail2ban_config
    ;;
"test")
    test_fail2ban_config
    ;;
"unban")
    if [ "$EUID" -ne 0 ]; then
        show_err "Unban operation requires root privileges. Run with sudo."
        exit 1
    fi
    unban_ip "$2" "$3"
    ;;
"ssh")
    show_ssh_security
    ;;
"wireguard")
    show_jail_details "wireguard"
    echo "WireGuard VPN attack attempts:"
    journalctl --since "24 hours ago" --no-pager -q | grep -i wireguard | grep -i "invalid\|failed" | tail -10
    ;;
"portscan")
    show_jail_details "portscan"
    echo "Port scanning attempts detected:"
    journalctl --since "24 hours ago" --no-pager -q | grep -E "PORTSCAN:|STEALTH_SCAN:|NMAP_SCAN:|PORT_PROBE:|SYN_FLOOD:" | tail -20
    echo
    echo "Recent iptables log entries:"
    tail -50 /var/log/kern.log | grep -E "PORTSCAN:|STEALTH_SCAN:|NMAP_SCAN:|PORT_PROBE:|SYN_FLOOD:" | tail -10
    ;;
"help" | "-h" | "--help")
    show_usage
    ;;
*)
    show_err "Unknown command: $1"
    show_usage
    exit 1
    ;;
esac
