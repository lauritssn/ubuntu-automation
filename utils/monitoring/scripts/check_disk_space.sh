#!/usr/bin/env bash

#########################################################################
# Disk Space Monitoring Script for Ubuntu 24.04 Server Automation
# Integrated with systemd timers and Slack notifications
# Enhanced to send "running" notifications only once every 24 hours
#########################################################################

### Constants
THRESHOLD_WARNING=20  # In percent
THRESHOLD_CRITICAL=10 # In percent

SLACK_WEBHOOK_URL="{{SLACK_WEBHOOK_URL}}"
MONITOR_URL="http://localhost:3001"
HOSTNAME=$(hostname)
SCRIPT_NAME="Disk Space Monitor"
KEY="" # Monitoring key variable

# File to track last "running" notification time
LAST_NOTIFY_FILE="/var/log/disk-space-last-notify"

### Initializing variables
WARNING=0
CRITICAL=0
WARNING_ALERT=0
CRITICAL_ALERT=0
disks=()
critical_disks=()
warning_disks=()

### Read the command line parameters
while getopts ":w:c:d:k:" option; do
    case ${option} in
    w)
        THRESHOLD_WARNING=${OPTARG}
        ;;
    c)
        THRESHOLD_CRITICAL=${OPTARG}
        ;;
    d)
        disks+=("${OPTARG}")
        ;;
    k)
        KEY=${OPTARG}
        ;;
    *)
        echo "Invalid option: -${OPTARG}" >&2
        exit 1
        ;;
    esac
done

# Function to check if we should send daily notification
should_send_daily_notification() {
    local current_time=$(date +%s)
    local last_notify_time=0

    # Read last notification time if file exists
    if [ -f "$LAST_NOTIFY_FILE" ]; then
        last_notify_time=$(cat "$LAST_NOTIFY_FILE" 2>/dev/null || echo "0")
    fi

    # Check if 24 hours (86400 seconds) have passed
    local time_diff=$((current_time - last_notify_time))
    if [ $time_diff -ge 86400 ]; then
        echo "$current_time" >"$LAST_NOTIFY_FILE"
        return 0 # Should send notification
    else
        return 1 # Should not send notification
    fi
}

# Function to send a Slack message
send_slack_message() {
    local message="$1"
    local status="$2"
    local force_send="$3"       # If true, always send regardless of daily limit
    local channel="#monitoring" # Replace with your desired Slack channel

    # Only send Slack message if webhook URL is configured
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        # For critical/warning alerts, always send immediately
        # For routine status updates, check daily limit
        if [ "$force_send" = "true" ] || [ "$status" = "critical" ] || [ "$status" = "warning" ] || should_send_daily_notification; then
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
            "critical")
                emoji=":rotating_light:"
                username="System Alert"
                ;;
            *)
                emoji=":information_source:"
                username="System Monitor"
                ;;
            esac

            curl -X POST -H 'Content-type: application/json' --data "{
                \"channel\": \"$channel\",
                \"text\": \"$message\",
                \"username\": \"$username\",
                \"icon_emoji\": \"$emoji\"
            }" "$SLACK_WEBHOOK_URL" 2>/dev/null || echo "Failed to send Slack notification"
        else
            echo "Skipping daily notification (sent within last 24 hours)"
        fi
    else
        echo "Slack webhook not configured, skipping Slack notification"
    fi
}

# Send start notification (only once per 24 hours for routine checks)
send_slack_message "💽 $SCRIPT_NAME started on $HOSTNAME" "start" "false"

### Function to check available space on a given disk
check_disk_space() {
    local mount_point=$1
    local total_used_space=$(df -h "$mount_point" | awk '{print $5}' | tail -1)
    local available_space=$(df -h "$mount_point" | awk '{print $4}' | tail -1)

    # Handle blank or empty used space
    if [ -z "$total_used_space" ]; then
        total_used_space="0%"
    fi

    local used_space_percent=${total_used_space%?}
    local free_space_percent=$((100 - used_space_percent))

    # Convert available space to MB if it is not already in MB
    local available_space_mb
    case ${available_space: -1} in
    G) available_space_mb=$(echo "${available_space%?} * 1024" | bc 2>/dev/null || echo "0") ;;
    M) available_space_mb=${available_space%?} ;;
    K) available_space_mb=$(echo "${available_space%?} / 1024" | bc 2>/dev/null || echo "0") ;;
    *) available_space_mb=$available_space ;;
    esac

    # Echo the values of the disk being checked
    echo "Checking disk: $mount_point"
    echo "Total used space: $total_used_space"
    echo "Used space percent: $used_space_percent%"
    echo "Free space percent: $free_space_percent%"
    echo "Available space: $available_space"
    echo "Available space in MB: $available_space_mb MB"

    if ((free_space_percent <= THRESHOLD_CRITICAL)); then
        echo "  => Disk \"${mount_point}\" is CRITICAL (${free_space_percent}% free)"
        critical_disks+=("${mount_point}: ${free_space_percent}% free")
        CRITICAL=1
    elif ((free_space_percent <= THRESHOLD_WARNING)); then
        echo "  => Disk \"${mount_point}\" is WARNING (${free_space_percent}% free)"
        warning_disks+=("${mount_point}: ${free_space_percent}% free")
        WARNING=1
    else
        echo "  => Disk \"${mount_point}\" is OK (${free_space_percent}% free)"
    fi
}

### Get all mounted filesystems
if [ ${#disks[@]} -eq 0 ]; then
    # If no specific disks specified, check all mounted filesystems
    while IFS= read -r line; do
        mount_point=$(echo "$line" | awk '{print $6}')
        filesystem=$(echo "$line" | awk '{print $1}')

        # Skip pseudo filesystems and system mounts
        if [[ "$filesystem" =~ ^/dev/(sd|hd|vd|nvme|md|mapper) ]] && [[ "$mount_point" =~ ^(/|/home|/var|/tmp|/srv|/opt|/usr) ]]; then
            disks+=("$mount_point")
        fi
    done < <(df -h | tail -n +2)
fi

### Filter out tmpfs and other temporary filesystems
filtered_disks=()
for disk in "${disks[@]}"; do
    if ! df -hT | grep -E "$disk" | grep -q "tmpfs"; then
        filtered_disks+=("$disk")
    fi
done

### Calling function check_disk_space for all disks one by one
for disk in "${filtered_disks[@]}"; do
    check_disk_space "$disk"
    if [ ${CRITICAL} -eq 1 ]; then
        CRITICAL_ALERT=1
        CRITICAL=0
    elif [ ${WARNING} -eq 1 ]; then
        WARNING_ALERT=1
        WARNING=0
    else
        echo "  => Disk \"${disk}\" is OK"
    fi
done

## Notify if at least one disk is in warning or critical state
if [ ${CRITICAL_ALERT} -ne 0 ]; then
    # Send monitor ping if KEY is defined
    if [ -n "$KEY" ]; then
        curl -f -s --max-time 10 "${MONITOR_URL}/api/push/${KEY}?status=down&msg=CRITICAL&ping=" >/dev/null 2>&1 || echo "Failed to send monitor ping"
    fi

    message="CRITICAL: Disk space is critically low on $(hostname):\n"
    for disk in "${critical_disks[@]}"; do
        message+="  - $disk\n"
    done
    send_slack_message "$message" "critical" "false"

    # Log to systemd journal
    echo "CRITICAL: Disk space critically low on disks: ${critical_disks[*]}" | logger -p user.crit -t disk-space-monitor

elif [ ${WARNING_ALERT} -ne 0 ]; then
    # Send monitor ping if KEY is defined
    if [ -n "$KEY" ]; then
        curl -f -s --max-time 10 "${MONITOR_URL}/api/push/${KEY}?status=down&msg=WARNING&ping=" >/dev/null 2>&1 || echo "Failed to send monitor ping"
    fi

    message="WARNING: Disk space is low on $(hostname):\n"
    for disk in "${warning_disks[@]}"; do
        message+="  - $disk\n"
    done
    send_slack_message "$message" "warning" "false"

    # Log to systemd journal
    echo "WARNING: Disk space low on disks: ${warning_disks[*]}" | logger -p user.warn -t disk-space-monitor

else
    # Send healthy monitor ping if KEY is defined
    if [ -n "$KEY" ]; then
        curl -f -s --max-time 10 "${MONITOR_URL}/api/push/${KEY}?status=up&msg=OK&ping=" >/dev/null 2>&1 || echo "Failed to send monitor ping"
    fi

    echo "All disks have sufficient space available"
    send_slack_message "All disks have sufficient space available on $(hostname)" "success" "false"
fi

exit 0
