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
    local status="$2"  # start, success, warning, error
    local channel="#monitoring"
    
    # Only send Slack message if webhook URL is configured
    if [ -n "$SLACK_WEBHOOK_URL" ]; then        # Set appropriate emoji and username based on status
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
    fi
}

# Send start notification
send_slack_notification "🔍 $SCRIPT_NAME started on $HOSTNAME" "start"

# Run RKHunter scan
echo "Starting RKHunter scan at $(date)"
/usr/bin/rkhunter --cronjob --check --sk 2>&1 | tee -a "$LOG_FILE"
SCAN_EXIT_CODE=$?

# Check scan results
if [ $SCAN_EXIT_CODE -eq 0 ]; then
    # Check if there are any warnings in the log
    WARNINGS=$(tail -n 50 "$LOG_FILE" | grep -i "warning" | wc -l)
    if [ "$WARNINGS" -gt 0 ]; then
        send_slack_notification "⚠️ $SCRIPT_NAME completed on $HOSTNAME with $WARNINGS warnings - Check logs" "warning"
        echo "RKHunter scan completed with $WARNINGS warnings"
    else
        END_TIME=$(date)
        DURATION=$(($(date +%s) - $(date -d "$START_TIME" +%s)))
        send_slack_notification "✅ $SCRIPT_NAME completed successfully on $HOSTNAME - No issues found (Duration: ${DURATION}s)" "success"
        echo "RKHunter scan completed successfully"
    fi
else
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME with exit code $SCAN_EXIT_CODE" "error"
    echo "RKHunter scan failed with exit code: $SCAN_EXIT_CODE"
fi

echo "RKHunter scan completed at $(date)" 