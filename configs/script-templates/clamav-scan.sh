#!/bin/bash

# ClamAV Scanning Script for systemd timer
# Enhanced with Slack notifications and comprehensive monitoring

# Configuration
SLACK_WEBHOOK_URL="{{SLACK_WEBHOOK_URL}}"
HOSTNAME=$(hostname)
START_TIME=$(date)
SCRIPT_NAME="ClamAV Antivirus Scan"

# Directories to scan
SCAN_DIR="/home /tmp /var /srv"

# Exclude common false positive locations and file types
EXCLUDE_OPTS="--exclude-dir=/tmp/systemd-private* --exclude-dir=/var/lib/docker --exclude-dir=/var/cache --exclude=*.pid --exclude=*.lock --exclude=*.sock"

# Location of log file
LOG_FILE="/var/log/clamav/manual_clamscan.log"

# Email configuration
SUBJECT="Infections detected on $(hostname)"
EMAIL="{{INFO_EMAIL}}"
EMAIL_FROM="clamav@{{EMAIL_DOMAIN}}"

# Aggressive mode (remove infected files)
AGGRESSIVE=0

# Create log directory if it doesn't exist
mkdir -p /var/log/clamav

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
send_slack_notification "🦠 $SCRIPT_NAME started on $HOSTNAME" "start"

# Update virus definitions before scanning
echo "Updating ClamAV virus definitions..."
freshclam --quiet

# Record scan start time
echo "Starting ClamAV scan at $(date)" | tee -a "$LOG_FILE"

# Run the scan
if [ "$AGGRESSIVE" -eq 1 ]; then
    # Remove infected files (use with caution)
    clamscan -r --bell -i --remove $EXCLUDE_OPTS $SCAN_DIR 2>&1 | tee -a "$LOG_FILE"
else
    # Just detect and report
    clamscan -r --bell -i $EXCLUDE_OPTS $SCAN_DIR 2>&1 | tee -a "$LOG_FILE"
fi

SCAN_EXIT_CODE=$?

# Parse scan results
INFECTED_FILES=$(grep "FOUND" "$LOG_FILE" | tail -20)
INFECTED_COUNT=$(grep -c "FOUND" "$LOG_FILE" || echo "0")

echo "ClamAV scan completed at $(date)" | tee -a "$LOG_FILE"
echo "Scan exit code: $SCAN_EXIT_CODE" | tee -a "$LOG_FILE"
echo "Infected files found: $INFECTED_COUNT" | tee -a "$LOG_FILE"

# Generate report based on results
if [ "$INFECTED_COUNT" -gt 0 ]; then
    echo "INFECTED FILES DETECTED!" | tee -a "$LOG_FILE"
    echo "Infected files:" | tee -a "$LOG_FILE"
    echo "$INFECTED_FILES" | tee -a "$LOG_FILE"
    
    # Send critical alert
    send_slack_notification "🚨 CRITICAL: $SCRIPT_NAME found $INFECTED_COUNT infected files on $HOSTNAME! Check logs immediately." "error"
    
    # Send email alert if configured
    if command -v mail >/dev/null 2>&1 && [ -n "$EMAIL" ]; then
        echo "Sending email alert to $EMAIL"
        {
            echo "ClamAV has detected infected files on $HOSTNAME!"
            echo ""
            echo "Scan completed: $(date)"
            echo "Infected files: $INFECTED_COUNT"
            echo ""
            echo "Details:"
            echo "$INFECTED_FILES"
            echo ""
            echo "Please investigate immediately."
        } | mail -s "$SUBJECT" "$EMAIL"
    fi
    
    # Log to systemd journal
    echo "CRITICAL: ClamAV found $INFECTED_COUNT infected files" | logger -p user.crit -t clamav-scan
    
else
    # No infections found
    END_TIME=$(date)
    DURATION=$(($(date +%s) - $(date -d "$START_TIME" +%s)))
    send_slack_notification "✅ $SCRIPT_NAME completed successfully on $HOSTNAME - No threats detected (Duration: ${DURATION}s)" "success"
fi

# Check for scan errors
if [ $SCAN_EXIT_CODE -ne 0 ] && [ $SCAN_EXIT_CODE -ne 1 ]; then
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME with exit code $SCAN_EXIT_CODE" "error"
    exit $SCAN_EXIT_CODE
fi

echo "ClamAV scan completed at $(date)" 