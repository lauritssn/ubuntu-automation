#!/bin/bash

# Swap Usage Monitor for Ubuntu 24.04
# Enhanced with Slack notifications and comprehensive monitoring

# Configuration
SLACK_WEBHOOK_URL="{{SLACK_WEBHOOK_URL}}"
HOSTNAME=$(hostname)
START_TIME=$(date)
SCRIPT_NAME="Swap Usage Monitor"

SWAP_WARN_THRESHOLD=25 # Warning at 25% swap usage
SWAP_CRIT_THRESHOLD=50 # Critical at 50% swap usage

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
send_slack_notification "💾 $SCRIPT_NAME started on $HOSTNAME" "start"

# Get current swap usage percentage
SWAP_TOTAL=$(free | grep Swap | awk '{print $2}')
SWAP_USED=$(free | grep Swap | awk '{print $3}')

# Handle systems without swap
if [ "$SWAP_TOTAL" -eq 0 ]; then
    echo "No swap space configured on this system"
    send_slack_notification "ℹ️ $SCRIPT_NAME completed on $HOSTNAME - No swap space configured" "success"
    exit 0
fi

SWAP_USAGE_PERCENT=$(echo "scale=2; $SWAP_USED * 100 / $SWAP_TOTAL" | bc 2>/dev/null || echo "0")
SWAP_USAGE_PERCENT_INT=$(echo "$SWAP_USAGE_PERCENT" | cut -d. -f1)

# Display current swap status
echo "=== Swap Usage Report - $(date) ==="
echo "Total Swap: $((SWAP_TOTAL / 1024)) MB"
echo "Used Swap: $((SWAP_USED / 1024)) MB"
echo "Swap Usage: ${SWAP_USAGE_PERCENT}%"
echo ""

# Memory pressure context
MEMORY_TOTAL=$(free | grep Mem | awk '{print $2}')
MEMORY_USED=$(free | grep Mem | awk '{print $3}')
MEMORY_USAGE_PERCENT=$(echo "scale=2; $MEMORY_USED * 100 / $MEMORY_TOTAL" | bc 2>/dev/null || echo "0")

echo "Memory Usage: ${MEMORY_USAGE_PERCENT}%"
echo ""

# Check thresholds and send alerts
if [ "$SWAP_USAGE_PERCENT_INT" -ge "$SWAP_CRIT_THRESHOLD" ]; then
    echo "CRITICAL: Swap usage is critically high (${SWAP_USAGE_PERCENT}%)"

    # Show top memory-consuming processes
    echo "Top memory-consuming processes:"
    ps aux --sort=-%mem | head -10

    send_slack_notification "🚨 CRITICAL: Swap usage critically high on $HOSTNAME - ${SWAP_USAGE_PERCENT}% used (Memory: ${MEMORY_USAGE_PERCENT}%)" "error"

    # Log to systemd journal
    echo "CRITICAL: Swap usage critically high: ${SWAP_USAGE_PERCENT}%" | logger -p user.crit -t swap-monitor

elif [ "$SWAP_USAGE_PERCENT_INT" -ge "$SWAP_WARN_THRESHOLD" ]; then
    echo "WARNING: Swap usage is elevated (${SWAP_USAGE_PERCENT}%)"

    # Show top memory-consuming processes
    echo "Top memory-consuming processes:"
    ps aux --sort=-%mem | head -5

    send_slack_notification "⚠️ WARNING: Elevated swap usage on $HOSTNAME - ${SWAP_USAGE_PERCENT}% used (Memory: ${MEMORY_USAGE_PERCENT}%)" "warning"

    # Log to systemd journal
    echo "WARNING: Elevated swap usage: ${SWAP_USAGE_PERCENT}%" | logger -p user.warn -t swap-monitor

else
    echo "OK: Swap usage is normal (${SWAP_USAGE_PERCENT}%)"

    END_TIME=$(date)
    DURATION=$(($(date +%s) - $(date -d "$START_TIME" +%s)))
    send_slack_notification "✅ $SCRIPT_NAME completed on $HOSTNAME - Swap usage normal: ${SWAP_USAGE_PERCENT}% (Duration: ${DURATION}s)" "success"
fi

echo "=== Swap monitoring completed at $(date) ==="
