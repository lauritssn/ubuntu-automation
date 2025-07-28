#!/bin/bash

# ClamAV Update Script for systemd timer
# Enhanced with Slack notifications for signature updates

# Configuration
SLACK_WEBHOOK_URL="{{SLACK_WEBHOOK_URL}}"
HOSTNAME=$(hostname)
START_TIME=$(date)
SCRIPT_NAME="ClamAV Signature Update"
LOG_FILE="/var/log/clamav/freshclam_scheduled.log"

# Create log directory if it doesn't exist
mkdir -p /var/log/clamav

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
send_slack_notification "🦠 $SCRIPT_NAME started on $HOSTNAME" "start"

# Ensure proper permissions for ClamAV directories and files
echo "Ensuring proper ClamAV permissions..."

# Create and fix log directory permissions (more comprehensive)
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
chown -R clamav:clamav "$(dirname "$LOG_FILE")" 2>/dev/null || true
chmod 755 "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Fix database directory permissions (critical for freshclam)
if [ -d "/var/lib/clamav" ]; then
    chown -R clamav:clamav /var/lib/clamav 2>/dev/null || true
    chmod 755 /var/lib/clamav 2>/dev/null || true
    # Ensure database files have proper permissions
    find /var/lib/clamav -type f -exec chmod 644 {} \; 2>/dev/null || true
fi

# Create and fix run directory for ClamAV
mkdir -p /var/run/clamav 2>/dev/null || true
chown clamav:clamav /var/run/clamav 2>/dev/null || true
chmod 755 /var/run/clamav 2>/dev/null || true

# Create log file with proper ownership if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE" 2>/dev/null || true
    chown clamav:clamav "$LOG_FILE" 2>/dev/null || true
    chmod 644 "$LOG_FILE" 2>/dev/null || true
fi

# Create additional ClamAV log files that might be needed
touch /var/log/clamav/freshclam.log 2>/dev/null || true
chown clamav:clamav /var/log/clamav/freshclam.log 2>/dev/null || true
chmod 644 /var/log/clamav/freshclam.log 2>/dev/null || true

# Update ClamAV virus definitions
echo "Starting ClamAV signature update at $(date)" | tee -a "$LOG_FILE"

# Run freshclam to update virus signatures
# If the log file still has permission issues, run without specific log file
if freshclam --log="$LOG_FILE" --verbose 2>/dev/null; then
    UPDATE_EXIT_CODE=0
else
    # Fallback: run freshclam without custom log file (uses default logging)
    echo "Warning: Custom log file failed, using default freshclam logging" | tee -a "$LOG_FILE" 2>/dev/null || echo "Warning: Custom log file failed, using default freshclam logging"
    freshclam --verbose
    UPDATE_EXIT_CODE=$?
fi

# Check the exit code and send appropriate notifications
case $UPDATE_EXIT_CODE in
0)
    # Success - signatures were updated
    END_TIME=$(date)
    DURATION=$(($(date +%s) - $(date -d "$START_TIME" +%s)))
    send_slack_notification "✅ $SCRIPT_NAME completed successfully on $HOSTNAME - New signatures downloaded (Duration: ${DURATION}s)" "success"
    echo "ClamAV signatures updated successfully" | tee -a "$LOG_FILE"
    ;;
1)
    # Already up to date - this is also considered success
    END_TIME=$(date)
    DURATION=$(($(date +%s) - $(date -d "$START_TIME" +%s)))
    send_slack_notification "✅ $SCRIPT_NAME completed on $HOSTNAME - Signatures already up to date (Duration: ${DURATION}s)" "success"
    echo "ClamAV signatures are already up to date" | tee -a "$LOG_FILE"
    ;;
40)
    # Network error
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME: Network connectivity issue (exit code: 40)" "error"
    echo "ClamAV signature update failed: Network connectivity issue" | tee -a "$LOG_FILE"
    exit $UPDATE_EXIT_CODE
    ;;
50)
    # Configuration error
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME: Configuration error (exit code: 50)" "error"
    echo "ClamAV signature update failed: Configuration error" | tee -a "$LOG_FILE"
    exit $UPDATE_EXIT_CODE
    ;;
52)
    # Database update error
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME: Database update error (exit code: 52)" "error"
    echo "ClamAV signature update failed: Database update error" | tee -a "$LOG_FILE"
    exit $UPDATE_EXIT_CODE
    ;;
53)
    # DNS resolution error
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME: DNS resolution error (exit code: 53)" "error"
    echo "ClamAV signature update failed: DNS resolution error" | tee -a "$LOG_FILE"
    exit $UPDATE_EXIT_CODE
    ;;
54)
    # Mirror problem
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME: Mirror access problem (exit code: 54)" "error"
    echo "ClamAV signature update failed: Mirror access problem" | tee -a "$LOG_FILE"
    exit $UPDATE_EXIT_CODE
    ;;
55)
    # Connection timeout
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME: Connection timeout (exit code: 55)" "error"
    echo "ClamAV signature update failed: Connection timeout" | tee -a "$LOG_FILE"
    exit $UPDATE_EXIT_CODE
    ;;
56)
    # Proxy error
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME: Proxy configuration error (exit code: 56)" "error"
    echo "ClamAV signature update failed: Proxy configuration error" | tee -a "$LOG_FILE"
    exit $UPDATE_EXIT_CODE
    ;;
58)
    # Can't get information about user from /etc/passwd
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME: User permission error (exit code: 58)" "error"
    echo "ClamAV signature update failed: User permission error" | tee -a "$LOG_FILE"
    exit $UPDATE_EXIT_CODE
    ;;
59)
    # Can't drop privileges
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME: Privilege drop error (exit code: 59)" "error"
    echo "ClamAV signature update failed: Privilege drop error" | tee -a "$LOG_FILE"
    exit $UPDATE_EXIT_CODE
    ;;
60)
    # Can't switch to the clamav user
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME: User switch error (exit code: 60)" "error"
    echo "ClamAV signature update failed: User switch error" | tee -a "$LOG_FILE"
    exit $UPDATE_EXIT_CODE
    ;;
61)
    # Can't create freshclam.dat
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME: Database file creation error (exit code: 61)" "error"
    echo "ClamAV signature update failed: Database file creation error" | tee -a "$LOG_FILE"
    exit $UPDATE_EXIT_CODE
    ;;
62)
    # Can't create PID file or lock file
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME: PID/lock file error (exit code: 62)" "error"
    echo "ClamAV signature update failed: PID/lock file error" | tee -a "$LOG_FILE"
    exit $UPDATE_EXIT_CODE
    ;;
*)
    # Unknown error
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME: Unknown error (exit code: $UPDATE_EXIT_CODE)" "error"
    echo "ClamAV signature update failed with unknown error: exit code $UPDATE_EXIT_CODE" | tee -a "$LOG_FILE"
    exit $UPDATE_EXIT_CODE
    ;;
esac

echo "ClamAV signature update completed at $(date)" | tee -a "$LOG_FILE"
