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
    local status="$2" # start, success, warning, error
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
    else
        echo "Slack webhook not configured, skipping Slack notification"
    fi
}

# Send start notification
send_slack_notification "🔄 $SCRIPT_NAME started on $HOSTNAME" "start"

# Update RKHunter database
echo "Starting RKHunter update at $(date)"

# Skip update if WEB_CMD is set to /bin/false (security measure)
if grep -q 'WEB_CMD="/bin/false"' /etc/rkhunter.conf 2>/dev/null; then
    echo "Warning: WEB_CMD is set to /bin/false in rkhunter.conf"
    echo "This prevents remote updates. Consider commenting out WEB_CMD or using package manager updates."
    send_slack_notification "⚠️ $SCRIPT_NAME on $HOSTNAME: WEB_CMD disabled, skipping remote update" "warning"
    UPDATE_EXIT_CODE=0
else
    /usr/bin/rkhunter --update --cronjob
    UPDATE_EXIT_CODE=$?
fi

# Update file properties regardless of database update result
echo "Updating RKHunter file properties at $(date)"
/usr/bin/rkhunter --propupd --cronjob
PROPUPD_EXIT_CODE=$?

# Check if propupd failed due to warnings (common issue)
if [ $PROPUPD_EXIT_CODE -ne 0 ]; then
    echo "Property update failed. Checking for warnings in RKHunter log..."

    # Check if this is just a warning issue, not a real failure
    WARNING_COUNT=$(grep -c "Warning:" /var/log/rkhunter.log 2>/dev/null || echo "0")
    ERROR_COUNT=$(grep -c "ERROR:" /var/log/rkhunter.log 2>/dev/null || echo "0")

    if [ $WARNING_COUNT -gt 0 ] && [ $ERROR_COUNT -eq 0 ]; then
        echo "Found $WARNING_COUNT warnings but no errors. This may be acceptable."
        echo "Consider reviewing and whitelisting legitimate warnings."
        send_slack_notification "⚠️ $SCRIPT_NAME on $HOSTNAME: Property update failed due to $WARNING_COUNT warnings (no errors)" "warning"

        # Still exit with failure for manual review, but provide context
        exit $PROPUPD_EXIT_CODE
    fi
fi

# Determine overall result
if [ $UPDATE_EXIT_CODE -eq 0 ] && [ $PROPUPD_EXIT_CODE -eq 0 ]; then
    END_TIME=$(date)
    DURATION=$(($(date +%s) - $(date -d "$START_TIME" +%s)))
    send_slack_notification "✅ $SCRIPT_NAME completed successfully on $HOSTNAME (Duration: ${DURATION}s)" "success"
    echo "RKHunter update completed successfully"
elif [ $PROPUPD_EXIT_CODE -ne 0 ]; then
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME: Property update failed with exit code $PROPUPD_EXIT_CODE" "error"
    echo "RKHunter property update failed with exit code: $PROPUPD_EXIT_CODE"
    exit $PROPUPD_EXIT_CODE
elif [ $UPDATE_EXIT_CODE -ne 0 ]; then
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME: Database update failed with exit code $UPDATE_EXIT_CODE" "error"
    echo "RKHunter database update failed with exit code: $UPDATE_EXIT_CODE"
    exit $UPDATE_EXIT_CODE
fi

echo "RKHunter update completed at $(date)"
