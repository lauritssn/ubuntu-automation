#!/bin/bash

##########################################################################################
## Maldet Signature Update Script for systemd timer
##########################################################################################
DATE=$(date +%Y-%m-%d_%H%M)
SCRIPT_NAME="Maldet Signature Update"

# Source helper functions if available
if [ -f "/usr/local/bin/script_helper_functions.sh" ]; then
    source /usr/local/bin/script_helper_functions.sh
elif [ -f "$(dirname "$0")/script_helper_functions.sh" ]; then
    source "$(dirname "$0")/script_helper_functions.sh"
else
    # Fallback functions if helper script not available
    show_info() { echo "[INFO] $1"; }
    show_yellow() { echo "[WARNING] $1"; }
    show_err() {
        echo "[ERROR] $1" >&2
        exit 1
    }
    show_warn() { echo "[WARN] $1"; }
fi

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/srv/apps/logs
fi

LOGFILE="maldet-update-$DATE.log"

# Configuration
SLACK_WEBHOOK_URL="{{SLACK_WEBHOOK_URL}}"
HOSTNAME=$(hostname)
START_TIME=$(date)

##########################################################################################
## Functions
##########################################################################################

# Slack notification function
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

# Function to check if maldet is installed
check_maldet_installation() {
    if ! command -v maldet >/dev/null 2>&1; then
        show_err "Maldet is not installed or not in PATH"
    fi

    if [ ! -f "/usr/local/maldetect/conf.maldet" ]; then
        show_err "Maldet configuration file not found"
    fi

    show_info "Maldet installation verified"
}

# Function to update signatures
update_signatures() {
    local update_exit_code

    show_info "Starting Maldet signature update..."

    # Update signatures with detailed logging
    echo "$(date): Starting signature update" >>"$LOGDIR/$LOGFILE"

    # Run the update command
    if /usr/bin/maldet --update-sigs 2>&1 | tee -a "$LOGDIR/$LOGFILE"; then
        update_exit_code=0
        show_info "Maldet signatures updated successfully"
    else
        update_exit_code=$?
        show_err "Maldet signature update failed with exit code: $update_exit_code"
    fi

    echo "$(date): Signature update completed with exit code $update_exit_code" >>"$LOGDIR/$LOGFILE"

    return $update_exit_code
}

# Function to verify signature update
verify_update() {
    local sig_count
    local maldet_version

    show_info "Verifying signature update..."

    # Get current signature count and version info
    if maldet_version=$(maldet --version 2>/dev/null); then
        echo "Maldet version info:" >>"$LOGDIR/$LOGFILE"
        echo "$maldet_version" >>"$LOGDIR/$LOGFILE"
        show_info "Maldet version verification completed"
    else
        show_warn "Could not retrieve Maldet version information"
    fi

    # Check signature directory
    if [ -d "/usr/local/maldetect/sigs" ]; then
        sig_count=$(find /usr/local/maldetect/sigs -name "*.ndb" -o -name "*.hdb" -o -name "*.ldb" | wc -l)
        show_info "Found $sig_count signature files in /usr/local/maldetect/sigs"
        echo "$(date): Signature file count: $sig_count" >>"$LOGDIR/$LOGFILE"

        if [ "$sig_count" -gt 0 ]; then
            show_info "Signature update verification successful"
            return 0
        else
            show_warn "No signature files found after update"
            return 1
        fi
    else
        show_warn "Maldet signature directory not found"
        return 1
    fi
}

##########################################################################################
## Main execution
##########################################################################################

# Create log directory if it doesn't exist
mkdir -p "$LOGDIR" 2>/dev/null || true

# Log script start
echo "$(date): Starting $SCRIPT_NAME" >>"$LOGDIR/$LOGFILE"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    show_err "This script must be run as root (or with sudo)."
fi

# Send start notification
send_slack_notification "🔄 $SCRIPT_NAME started on $HOSTNAME" "start"

# Main execution
check_maldet_installation

if update_signatures; then
    if verify_update; then
        END_TIME=$(date)
        DURATION=$(($(date +%s) - $(date -d "$START_TIME" +%s)))
        send_slack_notification "✅ $SCRIPT_NAME completed successfully on $HOSTNAME (Duration: ${DURATION}s)" "success"
        show_info "$SCRIPT_NAME completed successfully"

        show_info "Maldet signatures are now available for independent scanning"

        exit_code=0
    else
        send_slack_notification "⚠️ $SCRIPT_NAME completed with warnings on $HOSTNAME: Signature verification failed" "warning"
        show_warn "$SCRIPT_NAME completed with warnings"
        exit_code=1
    fi
else
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME: Signature update failed" "error"
    show_err "$SCRIPT_NAME failed"
    exit_code=1
fi

# Log script completion
echo "$(date): Completed $SCRIPT_NAME with exit code $exit_code" >>"$LOGDIR/$LOGFILE"

show_info "$SCRIPT_NAME completed. Log available at: $LOGDIR/$LOGFILE"
exit $exit_code
