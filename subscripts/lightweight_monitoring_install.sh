#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################
DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="lightweight_monitoring_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/srv/apps/logs
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
## Load script template helper functions
##########################################################################################

# Source helper functions for script template management
source "$BASEDIR/configs/script-templates/script_helper_functions.sh"

##########################################################################################
## Info
##########################################################################################
show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Install lightweight monitoring tools
##########################################################################################

show_yellow "Installing lightweight monitoring tools."

# htop and iotop are already installed in general_system_settings.sh
# Install additional lightweight monitoring tools
apt-get --yes install sysstat nethogs ncdu tree >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Installation of monitoring tools failed. Please check logfile and fix error manually.")

show_yellow "Lightweight monitoring tools installed successfully."

##########################################################################################
## Configure system monitoring scripts
##########################################################################################

show_yellow "Creating system monitoring utilities."

# Create system health check script using template
copy_and_configure_script "system_health_check.sh" "$SCRIPTSDIR/system_health_check.sh" "System Health Check Script"

# Verify script template variables
verify_script_template "$SCRIPTSDIR/system_health_check.sh" "System Health Check"

##########################################################################################
## Create disk space monitoring script
##########################################################################################

show_yellow "Creating disk space monitoring script."

# Create disk space monitoring script using template
copy_and_configure_script "check_disk_space.sh" "$SCRIPTSDIR/check_disk_space.sh" "Disk Space Monitor Script"

# Verify script template variables
verify_script_template "$SCRIPTSDIR/check_disk_space.sh" "Disk Space Monitor"
while IFS= read -r line; do
    if [[ "$line" == *"%"* ]] && [[ "$line" != "Filesystem"* ]]; then
        USAGE_PERCENT=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        MOUNT_POINT=$(echo "$line" | awk '{print $6}')
        if [ "$USAGE_PERCENT" -gt 90 ]; then
            check_health_metric "Critical Disk Space" "false" "true" "$MOUNT_POINT at ${USAGE_PERCENT}%"
        elif [ "$USAGE_PERCENT" -gt 80 ]; then
            check_health_metric "Low Disk Space" "true" "false" "$MOUNT_POINT at ${USAGE_PERCENT}%"
        fi
    fi
done <<< "$DISK_OUTPUT"

echo

# Service status (critical services)
echo "=== Critical Service Status ==="
SERVICES_TO_CHECK="ssh ufw clamav-daemon fail2ban"
FAILED_SERVICES=""

for service in $SERVICES_TO_CHECK; do
    if systemctl is-active "$service" >/dev/null 2>&1; then
        echo "$service: active"
    else
        echo "$service: FAILED"
        FAILED_SERVICES="$FAILED_SERVICES $service"
    fi
done

# Check Wireguard if enabled
if systemctl is-enabled wg-quick@wg0 >/dev/null 2>&1; then
    if systemctl is-active wg-quick@wg0 >/dev/null 2>&1; then
        echo "wg-quick@wg0: active"
    else
        echo "wg-quick@wg0: FAILED"
        FAILED_SERVICES="$FAILED_SERVICES wg-quick@wg0"
    fi
fi

if [ -n "$FAILED_SERVICES" ]; then
    check_health_metric "Critical Services Down" "false" "true" "Services failed:$FAILED_SERVICES"
fi

echo

# Recent failed services
echo "=== Recent Service Failures ==="
FAILED_SERVICES_OUTPUT=$(systemctl --failed --no-pager --no-legend 2>/dev/null)
if [ -n "$FAILED_SERVICES_OUTPUT" ]; then
    echo "$FAILED_SERVICES_OUTPUT"
    check_health_metric "System Services Failed" "true" "false" "$(echo "$FAILED_SERVICES_OUTPUT" | wc -l) services failed"
else
    echo "No failed services"
fi
echo

# Last 10 system errors
echo "=== Recent System Errors ==="
ERROR_COUNT=$(journalctl -p err --since "24 hours ago" --no-pager -q | wc -l 2>/dev/null || echo "0")
if [ "$ERROR_COUNT" -gt 0 ]; then
    journalctl -p err --since "24 hours ago" --no-pager -n 10
    if [ "$ERROR_COUNT" -gt 20 ]; then
        check_health_metric "High Error Rate" "false" "true" "$ERROR_COUNT errors in last 24 hours"
    elif [ "$ERROR_COUNT" -gt 10 ]; then
        check_health_metric "Elevated Error Rate" "true" "false" "$ERROR_COUNT errors in last 24 hours"
    fi
else
    echo "No recent errors"
fi
echo

# Network connections
echo "=== Active Network Connections ==="
ss -tulpn | grep LISTEN | head -10
echo

# Load average and processes
echo "=== Top Processes by CPU ==="
ps aux --sort=-%cpu | head -10
echo

echo "=== Report completed at $(date) ==="

# Send completion notification
END_TIME=$(date)
DURATION=$(($(date +%s) - $(date -d "$START_TIME" +%s)))

if [ "$HEALTH_ISSUES" -eq 0 ]; then
    send_slack_notification "✅ $SCRIPT_NAME completed on $HOSTNAME - All systems healthy (Duration: ${DURATION}s)" "success"
else
    send_slack_notification "⚠️ $SCRIPT_NAME completed on $HOSTNAME - $HEALTH_ISSUES issues detected (Duration: ${DURATION}s)" "warning"
fi
EOF

chmod +x $SCRIPTSDIR/system_health_check.sh
show_yellow "System health check script created at $SCRIPTSDIR/system_health_check.sh"

##########################################################################################
## Create disk space monitoring script
##########################################################################################

show_yellow "Creating disk space monitoring script."

# Create disk space monitoring script (enhanced version of check_disk_space.sh)
cat > $SCRIPTSDIR/check_disk_space.sh << 'EOF'
#!/usr/bin/env bash

#########################################################################
# Disk Space Monitoring Script for Ubuntu 24.04 Server Automation
# Integrated with systemd timers and Slack notifications
#########################################################################

### Constants
THRESHOLD_WARNING=20     # In percent
THRESHOLD_CRITICAL=10    # In percent

SLACK_WEBHOOK_URL="SLACK_WEBHOOK_PLACEHOLDER"
MONITOR_URL="http://localhost:3001"

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
            key=${OPTARG}
            ;;
        *)
            echo "Invalid option: -${OPTARG}" >&2
            exit 1
            ;;
    esac
done

# Function to send a Slack message
send_slack_message() {
    local message="$1"
    local channel="#monitoring"  # Replace with your desired Slack channel

    # Only send Slack message if webhook URL is configured
    if [ "$SLACK_WEBHOOK_URL" != "SLACK_WEBHOOK_PLACEHOLDER" ] && [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' --data "{
            \"channel\": \"$channel\",
            \"text\": \"$message\",
            \"username\": \"Disk Space Monitor\",
            \"icon_emoji\": \":exclamation:\"
        }" "$SLACK_WEBHOOK_URL" 2>/dev/null || echo "Failed to send Slack notification"
    else
        echo "Slack webhook not configured, skipping Slack notification"
    fi
}

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
    local free_space_percent=$(( 100 - used_space_percent ))

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

    if (( free_space_percent <= THRESHOLD_CRITICAL )); then
        CRITICAL=1
        critical_disks+=("$mount_point ($free_space_percent% available - $available_space_mb MB available)")
        return 2
    elif (( free_space_percent <= THRESHOLD_WARNING )); then
        WARNING=1
        warning_disks+=("$mount_point ($free_space_percent% available - $available_space_mb MB available)")
        return 1
    else
        return 0
    fi
}

### Check if the disk is passed as command line else select all filesystems except tmpfs
if [ ${#disks[@]} -lt 1 ]; then
    echo "No disk is provided, selecting all non-tmpfs filesystems as default"
    mapfile -t disks < <(df -hT | grep -vE '^tmpfs|^Filesystem' | awk '{print $7}')
fi

### Filter out tmpfs filesystems
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
    # Send monitor ping if key is provided
    if [ -n "$key" ]; then
        curl -f -s --max-time 10 "${MONITOR_URL}/api/push/${key}?status=down&msg=CRITICAL&ping=" >/dev/null 2>&1 || echo "Failed to send monitor ping"
    fi
    
    message="CRITICAL: Disk space is critically low on $(hostname):\n"
    for disk in "${critical_disks[@]}"; do
        message+="  - $disk\n"
    done
    send_slack_message "$message"
    
    # Log to systemd journal
    echo "CRITICAL: Disk space critically low on disks: ${critical_disks[*]}" | logger -p user.crit -t disk-space-monitor
    
elif [ ${WARNING_ALERT} -ne 0 ]; then
    # Send monitor ping if key is provided
    if [ -n "$key" ]; then
        curl -f -s --max-time 10 "${MONITOR_URL}/api/push/${key}?status=down&msg=WARNING&ping=" >/dev/null 2>&1 || echo "Failed to send monitor ping"
    fi
    
    message="WARNING: Disk space is low on $(hostname):\n"
    for disk in "${warning_disks[@]}"; do
        message+="  - $disk\n"
    done
    send_slack_message "$message"
    
    # Log to systemd journal
    echo "WARNING: Disk space low on disks: ${warning_disks[*]}" | logger -p user.warn -t disk-space-monitor
    
else
    # Send healthy monitor ping if key is provided
    if [ -n "$key" ]; then
        curl -f -s --max-time 10 "${MONITOR_URL}/api/push/${key}?status=up&msg=OK&ping=" >/dev/null 2>&1 || echo "Failed to send monitor ping"
    fi
    
    echo "All disks have sufficient space available"
fi

exit 0
EOF

chmod +x $SCRIPTSDIR/check_disk_space.sh

# Replace Slack webhook placeholder if enabled
if [[ "$ENABLE_SLACK_MONITORING" =~ [Yy]$ ]] && [ -n "$SLACK_WEBHOOK_URL" ]; then
    sed -i 's|SLACK_WEBHOOK_PLACEHOLDER|'${SLACK_WEBHOOK_URL}'|g' $SCRIPTSDIR/check_disk_space.sh
    show_yellow "Disk space monitoring script created with Slack notifications enabled"
else
    show_yellow "Disk space monitoring script created (Slack notifications disabled)"
fi

show_yellow "Disk space monitoring script created at $SCRIPTSDIR/check_disk_space.sh"

##########################################################################################
## Create monitoring aliases and shortcuts
##########################################################################################

show_yellow "Creating monitoring aliases."

# Create .bash_aliases file for monitoring shortcuts
cat > /etc/skel/.bash_aliases << 'EOF'
# System monitoring aliases for Ubuntu 24.04
alias sysstatus='systemctl status'
alias syslog='journalctl -f'
alias syserr='journalctl -p err --since "1 hour ago"'
alias sysload='systemd-cgtop'
alias netstat='ss -tulpn'
alias processes='ps aux --sort=-%cpu | head -20'
alias diskuse='df -h && echo && ncdu /'
alias memuse='free -h && echo && ps aux --sort=-%mem | head -10'
alias syshealth='/srv/apps/scripts/system_health_check.sh'
alias diskcheck='/srv/apps/scripts/check_disk_space.sh'
EOF

# Apply to root user
cp /etc/skel/.bash_aliases /root/.bash_aliases

show_yellow "Monitoring aliases created:"
show_info "  syshealth  - Full system health report"
show_info "  diskcheck  - Manual disk space check with Slack notifications"

##########################################################################################
## Configure sysstat for historical data
##########################################################################################

show_yellow "Configuring system statistics collection."

# Enable sysstat data collection
sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat 2>/dev/null || true

# Start and enable sysstat
systemctl enable sysstat >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to enable sysstat service."
systemctl restart sysstat >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to restart sysstat service."

show_yellow "System statistics collection enabled. Use 'sar' command for historical data."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done. Use 'syshealth' command for system overview."