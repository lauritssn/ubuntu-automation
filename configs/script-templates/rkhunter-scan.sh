#!/bin/bash

# RKHunter Security Scan Script for systemd timer
# Enhanced with Slack notifications and comprehensive monitoring

# Configuration
SLACK_WEBHOOK_URL="{{SLACK_WEBHOOK_URL}}"
HOSTNAME=$(hostname)
START_TIME=$(date)
SCRIPT_NAME="RKHunter Security Scan"
LOG_FILE="/var/log/rkhunter.log"

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

# Run RKHunter scan
echo "Starting RKHunter scan at $(date)"
/usr/bin/rkhunter --cronjob --check --sk 2>&1 | tee -a "$LOG_FILE"
SCAN_EXIT_CODE=$?

# Check scan results
# First, check if any rootkits were actually found (the important metric)
# Look for the summary line that shows rootkit count
ROOTKITS_FOUND=$(grep "Possible rootkits:" "$LOG_FILE" | tail -1 | awk '{print $3}' 2>/dev/null || echo "0")

# Fallback: if we can't parse the count, check for any rootkit warnings in the log
if [ "$ROOTKITS_FOUND" = "0" ] || [ -z "$ROOTKITS_FOUND" ]; then
    # Check if there are any actual rootkit detections (not just warnings)
    if grep -q "INFECTION" "$LOG_FILE" 2>/dev/null; then
        ROOTKITS_FOUND="1"
    else
        ROOTKITS_FOUND="0"
    fi
fi

if [ "$ROOTKITS_FOUND" = "0" ]; then
    # No rootkits found - this is good
    if [ $SCAN_EXIT_CODE -eq 0 ]; then
        # Perfect - no warnings and no rootkits
        END_TIME=$(date)
        DURATION=$(($(date +%s) - $(date -d "$START_TIME" +%s)))
        send_slack_notification "✅ $SCRIPT_NAME completed successfully on $HOSTNAME - No issues found (Duration: ${DURATION}s)" "success"
        echo "RKHunter scan completed successfully"
    else
        # Exit code 1 but no rootkits - just warnings (which is acceptable)
        WARNINGS=$(grep -i "warning" "$LOG_FILE" | tail -20 | wc -l)
        END_TIME=$(date)
        DURATION=$(($(date +%s) - $(date -d "$START_TIME" +%s)))
        send_slack_notification "✅ $SCRIPT_NAME completed on $HOSTNAME with $WARNINGS warnings but no rootkits found (Duration: ${DURATION}s)" "success"
        echo "RKHunter scan completed with $WARNINGS warnings but no rootkits found"
    fi
else
    # Rootkits found - this is serious
    send_slack_notification "🚨 $SCRIPT_NAME found $ROOTKITS_FOUND possible rootkits on $HOSTNAME - URGENT CHECK REQUIRED" "error"
    echo "RKHunter scan found $ROOTKITS_FOUND possible rootkits - urgent attention required"
fi

echo "RKHunter scan completed at $(date)"
