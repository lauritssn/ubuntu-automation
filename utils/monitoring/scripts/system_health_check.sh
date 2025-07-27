#!/bin/bash

# System Health Check Script for Ubuntu 24.04
# Enhanced with Slack notifications and comprehensive monitoring

# Configuration
SLACK_WEBHOOK_URL="{{SLACK_WEBHOOK_URL}}"
HOSTNAME=$(hostname)
START_TIME=$(date)
SCRIPT_NAME="System Health Check"
HEALTH_ISSUES=0

# Common Slack notification function
send_slack_notification() {
    local message="$1"
    local status="$2" # start, success, warning, error
    local channel="#monitoring"

    # Only send Slack message if webhook URL is configured
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        # Set appropriate emoji and username based on status
        case "$status" in
        "start")
            emoji=":hourglass_flowing_sand:"
            username="System Monitor"
            ;;
        "success")
            emoji=":white_check_mark:"
            username="System Monitor"
            ;;
        "warning")
            emoji=":warning:"
            username="System Alert"
            ;;
        "error")
            emoji=":rotating_light:"
            username="System Alert"
            ;;
        *)
            emoji=":information_source:"
            username="System Monitor"
            ;;
        esac

        # Send notification
        curl -X POST -H 'Content-type: application/json' --data "{
            \"channel\": \"$channel\",
            \"text\": \"$message\",
            \"username\": \"$username\",
            \"icon_emoji\": \"$emoji\"
        }" "$SLACK_WEBHOOK_URL" 2>/dev/null || echo "Failed to send Slack notification"
    else
        echo "Slack webhook not configured, skipping Slack notification"
    fi
}

# Send start notification
send_slack_notification "🔍 $SCRIPT_NAME started on $HOSTNAME" "start"

# Function to check for issues and alert
check_health_metric() {
    local metric_name="$1"
    local warning_condition="$2"
    local critical_condition="$3"
    local current_value="$4"

    if [ "$critical_condition" = "true" ]; then
        send_slack_notification "🚨 CRITICAL: $metric_name on $HOSTNAME - $current_value" "error"
        HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
        echo "CRITICAL: $metric_name - $current_value"
    elif [ "$warning_condition" = "true" ]; then
        send_slack_notification "⚠️ WARNING: $metric_name on $HOSTNAME - $current_value" "warning"
        HEALTH_ISSUES=$((HEALTH_ISSUES + 1))
        echo "WARNING: $metric_name - $current_value"
    fi
}

echo "=== System Health Report - $(date) ==="
echo

# System load and uptime
echo "=== System Load & Uptime ==="
UPTIME_OUTPUT=$(uptime)
echo "$UPTIME_OUTPUT"

# Check load average
LOAD_1MIN=$(echo "$UPTIME_OUTPUT" | awk '{print $(NF-2)}' | sed 's/,//')
LOAD_5MIN=$(echo "$UPTIME_OUTPUT" | awk '{print $(NF-1)}' | sed 's/,//')
CPU_CORES=$(nproc)
LOAD_THRESHOLD_WARNING=$(echo "$CPU_CORES * 0.8" | bc -l 2>/dev/null || echo "$CPU_CORES")
LOAD_THRESHOLD_CRITICAL=$(echo "$CPU_CORES * 1.5" | bc -l 2>/dev/null || echo "$((CPU_CORES * 2))")

if command -v bc >/dev/null 2>&1; then
    LOAD_HIGH_WARNING=$(echo "$LOAD_1MIN > $LOAD_THRESHOLD_WARNING" | bc -l)
    LOAD_HIGH_CRITICAL=$(echo "$LOAD_1MIN > $LOAD_THRESHOLD_CRITICAL" | bc -l)
    check_health_metric "High Load Average" "$LOAD_HIGH_WARNING" "$LOAD_HIGH_CRITICAL" "1min load: $LOAD_1MIN (cores: $CPU_CORES)"
fi

echo

# Memory usage
echo "=== Memory Usage ==="
MEMORY_OUTPUT=$(free -h)
echo "$MEMORY_OUTPUT"

# Check memory usage percentage
MEMORY_USED_PERCENT=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
check_health_metric "High Memory Usage" "$((MEMORY_USED_PERCENT > 80))" "$((MEMORY_USED_PERCENT > 95))" "Memory usage: ${MEMORY_USED_PERCENT}%"

echo

# Disk usage
echo "=== Disk Usage ==="
DISK_OUTPUT=$(df -h / /var /tmp 2>/dev/null)
echo "$DISK_OUTPUT"

# Check disk usage for root partition
ROOT_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
check_health_metric "High Disk Usage (Root)" "$((ROOT_USAGE > 80))" "$((ROOT_USAGE > 95))" "Root filesystem: ${ROOT_USAGE}% used"

echo

# System services status
echo "=== Critical System Services ==="
CRITICAL_SERVICES=("ssh" "systemd-resolved" "cron" "systemd-timesyncd")
for service in "${CRITICAL_SERVICES[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo "✓ $service: running"
    else
        echo "✗ $service: NOT running"
        check_health_metric "Service Down" "false" "true" "$service service is not running"
    fi
done

echo

# Check for failed systemd units
echo "=== Failed Systemd Units ==="
FAILED_UNITS=$(systemctl --failed --no-legend --no-pager | wc -l)
if [ "$FAILED_UNITS" -gt 0 ]; then
    echo "Failed units found:"
    systemctl --failed --no-legend --no-pager
    check_health_metric "Failed Systemd Units" "$((FAILED_UNITS > 0))" "$((FAILED_UNITS > 2))" "$FAILED_UNITS failed units"
else
    echo "No failed systemd units"
fi

echo

# Security scan status
echo "=== Security Monitoring Status ==="
if systemctl is-active --quiet fail2ban; then
    echo "✓ fail2ban: active"
    # Show recent fail2ban actions
    FAIL2BAN_ACTIONS=$(journalctl -u fail2ban --since "24 hours ago" -p warning --no-pager -q | wc -l)
    if [ "$FAIL2BAN_ACTIONS" -gt 0 ]; then
        echo "  Recent actions: $FAIL2BAN_ACTIONS in last 24h"
        check_health_metric "Security Events" "$((FAIL2BAN_ACTIONS > 10))" "$((FAIL2BAN_ACTIONS > 50))" "$FAIL2BAN_ACTIONS fail2ban actions in 24h"
    fi
else
    echo "✗ fail2ban: not running"
fi

if systemctl is-active --quiet clamav-daemon 2>/dev/null; then
    echo "✓ clamav-daemon: active"
else
    echo "- clamav-daemon: not installed or not running"
fi

echo

# Network status
echo "=== Network Status ==="
# Check if we can reach external DNS
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "✓ External connectivity: OK"
else
    echo "✗ External connectivity: FAILED"
    check_health_metric "Network Connectivity" "false" "true" "Cannot reach external DNS (8.8.8.8)"
fi

# Check listening services
echo "=== Listening Services ==="
ss -tulpn | grep LISTEN | head -5

echo

# System errors
echo "=== Recent System Errors ==="
ERROR_COUNT=$(journalctl -p err --since "24 hours ago" --no-pager -q | wc -l)
echo "Errors in last 24 hours: $ERROR_COUNT"

if [ "$ERROR_COUNT" -gt 0 ]; then
    journalctl -p err --since "24 hours ago" --no-pager -n 10
    if [ "$ERROR_COUNT" -gt 20 ]; then
        check_health_metric "High Error Rate" "false" "true" "$ERROR_COUNT errors in last 24 hours"
    elif [ "$ERROR_COUNT" -gt 10 ]; then
        check_health_metric "Elevated Error Rate" "true" "false" "$ERROR_COUNT errors in last 24 hours"
    fi
else
    echo "No recent errors"
fi
echo

# Network connections
echo "=== Active Network Connections ==="
ss -tulpn | grep LISTEN | head -10
echo

# Load average and processes
echo "=== Top Processes by CPU ==="
ps aux --sort=-%cpu | head -10
echo

echo "=== Report completed at $(date) ==="

# Send completion notification
END_TIME=$(date)
DURATION=$(($(date +%s) - $(date -d "$START_TIME" +%s)))

if [ "$HEALTH_ISSUES" -eq 0 ]; then
    send_slack_notification "✅ $SCRIPT_NAME completed on $HOSTNAME - All systems healthy (Duration: ${DURATION}s)" "success"
else
    send_slack_notification "⚠️ $SCRIPT_NAME completed on $HOSTNAME - $HEALTH_ISSUES issues detected (Duration: ${DURATION}s)" "warning"
fi
