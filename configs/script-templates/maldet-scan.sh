#!/bin/bash

# Maldet Security Scanning Script for systemd timer
# Independent scanning without ClamAV database integration

# Configuration
SLACK_WEBHOOK_URL="{{SLACK_WEBHOOK_URL}}"
HOSTNAME=$(hostname)
START_TIME=$(date)
SCRIPT_NAME="Maldet Security Scan"

# Directories to scan (focus on web directories and common attack vectors)
SCAN_DIR="/home /tmp /var/www /var/log /srv"

# Location of log file
LOG_FILE="/var/log/maldet/maldet_scan.log"

# Email configuration
SUBJECT="Malware detected on $(hostname)"
EMAIL="{{INFO_EMAIL}}"
EMAIL_FROM="maldet@{{EMAIL_DOMAIN}}"

# Create log directory if it doesn't exist
mkdir -p /var/log/maldet

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

# Check if maldet is installed
if ! command -v maldet >/dev/null 2>&1; then
    send_slack_notification "❌ Maldet not found on $HOSTNAME - scan aborted" "error"
    echo "ERROR: Maldet is not installed or not in PATH"
    exit 1
fi

# Update maldet signatures before scanning
echo "Updating Maldet signatures..."
if maldet --update-sigs 2>&1 | tee -a "$LOG_FILE"; then
    echo "Maldet signatures updated successfully"
else
    echo "Warning: Maldet signature update failed - proceeding with existing signatures"
fi

# Record scan start time
echo "Starting Maldet scan at $(date)" | tee -a "$LOG_FILE"

# Run the scan using maldet's native scanning (can use ClamAV engine if configured)
# The -a flag enables automatic quarantine of threats
maldet -a $SCAN_DIR 2>&1 | tee -a "$LOG_FILE"

SCAN_EXIT_CODE=$?

# Parse scan results
INFECTED_FILES=$(grep -i "malware detected\|hits.*:" "$LOG_FILE" | tail -20)
INFECTED_COUNT=$(grep -c -i "malware detected\|infected.*:" "$LOG_FILE" || echo "0")

echo "Maldet scan completed at $(date)" | tee -a "$LOG_FILE"
echo "Scan exit code: $SCAN_EXIT_CODE" | tee -a "$LOG_FILE"
echo "Threats found: $INFECTED_COUNT" | tee -a "$LOG_FILE"

# Generate report based on results
if [ "$INFECTED_COUNT" -gt 0 ]; then
    echo "MALWARE DETECTED!" | tee -a "$LOG_FILE"
    echo "Detected threats:" | tee -a "$LOG_FILE"
    echo "$INFECTED_FILES" | tee -a "$LOG_FILE"

    # Send critical alert
    send_slack_notification "🚨 CRITICAL: $SCRIPT_NAME found $INFECTED_COUNT threats on $HOSTNAME! Check logs immediately." "error"

    # Send email alert if configured
    if command -v mail >/dev/null 2>&1 && [ -n "$EMAIL" ]; then
        echo "Sending email alert to $EMAIL"
        {
            echo "Maldet has detected malware on $HOSTNAME!"
            echo ""
            echo "Scan completed: $(date)"
            echo "Threats found: $INFECTED_COUNT"
            echo ""
            echo "Details:"
            echo "$INFECTED_FILES"
            echo ""
            echo "Please investigate immediately."
        } | mail -s "$SUBJECT" "$EMAIL"
    fi

    # Log to systemd journal
    echo "CRITICAL: Maldet found $INFECTED_COUNT threats" | logger -p user.crit -t maldet-scan

else
    # No threats found
    END_TIME=$(date)
    DURATION=$(($(date +%s) - $(date -d "$START_TIME" +%s)))
    send_slack_notification "✅ $SCRIPT_NAME completed successfully on $HOSTNAME - No threats detected (Duration: ${DURATION}s)" "success"
fi

# Check for scan errors
if [ $SCAN_EXIT_CODE -ne 0 ] && [ $SCAN_EXIT_CODE -ne 1 ]; then
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME with exit code $SCAN_EXIT_CODE" "error"
    exit $SCAN_EXIT_CODE
fi

echo "Maldet scan completed at $(date)" 