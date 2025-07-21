#!/bin/bash

# RKHunter Update Script for systemd timer
# Enhanced with Slack notifications

# Configuration
SLACK_WEBHOOK_URL="{{SLACK_WEBHOOK_URL}}"
HOSTNAME=$(hostname)
START_TIME=$(date)
SCRIPT_NAME="RKHunter Database Update"

# Common Slack notification function
send_slack_notification() {
    local message="$1"
    local status="$2"  # start, success, warning, error
    local channel="#monitoring"
    
    # Only send Slack message if webhook URL is configured
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
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
send_slack_notification "🔄 $SCRIPT_NAME started on $HOSTNAME" "start"

# Update RKHunter database
echo "Starting RKHunter update at $(date)"
/usr/bin/rkhunter --update --cronjob
UPDATE_EXIT_CODE=$?

if [ $UPDATE_EXIT_CODE -eq 0 ]; then
    END_TIME=$(date)
    DURATION=$(($(date +%s) - $(date -d "$START_TIME" +%s)))
    send_slack_notification "✅ $SCRIPT_NAME completed successfully on $HOSTNAME (Duration: ${DURATION}s)" "success"
    echo "RKHunter update completed successfully"
else
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME with exit code $UPDATE_EXIT_CODE" "error"
    echo "RKHunter update failed with exit code: $UPDATE_EXIT_CODE"
fi

echo "RKHunter update completed at $(date)" 