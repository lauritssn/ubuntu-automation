#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################
DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="systemd_timers_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/srv/apps/logs
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
## Common Slack notification function for all monitoring scripts
##########################################################################################

create_slack_function() {
    local script_file="$1"
    local script_name="$2"
    
    # Add Slack notification function to the script
    cat >> "$script_file" << 'SLACK_FUNCTION_EOF'

# Common Slack notification function
send_slack_notification() {
    local message="$1"
    local status="$2"  # start, success, warning, error
    local channel="#monitoring"
    
    # Only send Slack message if webhook URL is configured
    if [ "$SLACK_WEBHOOK_URL" != "SLACK_WEBHOOK_PLACEHOLDER" ] && [ -n "$SLACK_WEBHOOK_URL" ]; then
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
    fi
}

SLACK_FUNCTION_EOF
}

##########################################################################################
## Info
##########################################################################################
show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Install systemd timer units
##########################################################################################

show_yellow "Installing systemd timer units for security scanning and monitoring."

# Create systemd directory for custom units
mkdir -p /etc/systemd/system

##########################################################################################
## Install ClamAV systemd timer
##########################################################################################

show_yellow "Installing ClamAV systemd timer."

# Copy ClamAV service and timer files
cp $BASEDIR/configs/systemd/clamav-scan.service /etc/systemd/system/
cp $BASEDIR/configs/systemd/clamav-scan.timer /etc/systemd/system/

# Create ClamAV scan script
cat > /usr/local/bin/clamav-scan.sh << 'EOF'
#!/bin/bash

# ClamAV Scanning Script for systemd timer
# Enhanced with Slack notifications and comprehensive monitoring

# Configuration
SLACK_WEBHOOK_URL="SLACK_WEBHOOK_PLACEHOLDER"
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
EMAIL="INFO_EMAIL"
EMAIL_FROM="clamav@EMAIL_DOMAIN"

# Aggressive mode (remove infected files)
AGGRESSIVE=0

# Create log directory if it doesn't exist
mkdir -p /var/log/clamav
EOF

create_slack_function /usr/local/bin/clamav-scan.sh "ClamAV"

cat >> /usr/local/bin/clamav-scan.sh << 'EOF'

# Send start notification
send_slack_notification "🦠 $SCRIPT_NAME started on $HOSTNAME" "start"

check_scan () {
    # If there were infected files detected, send email alert
    if [ $(tail -n 12 ${LOG_FILE} | grep Infected | grep -v 0 | wc -l) != 0 ]; then
        # Count number of infections
        SCAN_RESULTS=$(tail -n 10 $LOG_FILE | grep 'Infected files')
        INFECTIONS=${SCAN_RESULTS##* }

        # Send critical Slack alert
        send_slack_notification "🚨 $SCRIPT_NAME on $HOSTNAME found $INFECTIONS infected files! Check logs immediately." "error"

        EMAILMESSAGE=$(mktemp /tmp/virus-alert.XXXXX)
        echo "To: ${EMAIL}" >> ${EMAILMESSAGE}
        echo "From: ${EMAIL_FROM}" >> ${EMAILMESSAGE}
        echo "Subject: ${SUBJECT}" >> ${EMAILMESSAGE}
        echo "Importance: High" >> ${EMAILMESSAGE}
        echo "X-Priority: 1" >> ${EMAILMESSAGE}
        
        if [ $AGGRESSIVE = 1 ]; then
            echo -e "\n$(tail -n $((10 + ($INFECTIONS*2))) $LOG_FILE)" >> ${EMAILMESSAGE}
        else
            echo -e "\n$(tail -n $((10 + $INFECTIONS)) $LOG_FILE)" >> ${EMAILMESSAGE}
        fi

        # Send email via postfix
        sendmail -t < ${EMAILMESSAGE}
        rm -f ${EMAILMESSAGE}
        
        # Log to systemd journal
        echo "ClamAV found $INFECTIONS infected files. Email alert sent."
        return 1
    else
        echo "ClamAV scan completed. No threats found."
        return 0
    fi
}

# Run ClamAV scan with low priority
echo "Starting ClamAV scan at $(date)"

# Run the scan and capture exit code
if [ $AGGRESSIVE = 1 ]; then
    /usr/bin/clamscan -ri --remove $EXCLUDE_OPTS $SCAN_DIR >> $LOG_FILE 2>&1
    SCAN_EXIT_CODE=$?
else
    /usr/bin/clamscan -ri $EXCLUDE_OPTS $SCAN_DIR >> $LOG_FILE 2>&1
    SCAN_EXIT_CODE=$?
fi

# Check scan results and send notifications
if check_scan; then
    END_TIME=$(date)
    DURATION=$(($(date +%s) - $(date -d "$START_TIME" +%s)))
    send_slack_notification "✅ $SCRIPT_NAME completed successfully on $HOSTNAME (Duration: ${DURATION}s)" "success"
else
    send_slack_notification "⚠️ $SCRIPT_NAME completed with threats detected on $HOSTNAME - Check email alerts" "warning"
fi

# Check for scan errors
if [ $SCAN_EXIT_CODE -ne 0 ] && [ $SCAN_EXIT_CODE -ne 1 ]; then
    send_slack_notification "❌ $SCRIPT_NAME failed on $HOSTNAME with exit code $SCAN_EXIT_CODE" "error"
    exit $SCAN_EXIT_CODE
fi

echo "ClamAV scan completed at $(date)"
EOF

chmod +x /usr/local/bin/clamav-scan.sh

# Replace email placeholders
sed -i 's/INFO_EMAIL/'${INFO_EMAIL}'/g' /usr/local/bin/clamav-scan.sh
sed -i 's/EMAIL_DOMAIN/'${EMAIL_DOMAIN}'/g' /usr/local/bin/clamav-scan.sh

show_yellow "ClamAV systemd timer installed with false positive reduction enabled."

##########################################################################################
## Install RKHunter systemd timers
##########################################################################################

show_yellow "Installing RKHunter systemd timers."

# Create RKHunter scan script with Slack notifications
cat > /usr/local/bin/rkhunter-scan.sh << 'EOF'
#!/bin/bash

# RKHunter Security Scan Script for systemd timer
# Enhanced with Slack notifications and comprehensive monitoring

# Configuration
SLACK_WEBHOOK_URL="SLACK_WEBHOOK_PLACEHOLDER"
HOSTNAME=$(hostname)
START_TIME=$(date)
SCRIPT_NAME="RKHunter Security Scan"
LOG_FILE="/var/log/rkhunter.log"

EOF

create_slack_function /usr/local/bin/rkhunter-scan.sh "RKHunter"

cat >> /usr/local/bin/rkhunter-scan.sh << 'EOF'

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
EOF

chmod +x /usr/local/bin/rkhunter-scan.sh

# Create RKHunter update script with Slack notifications
cat > /usr/local/bin/rkhunter-update.sh << 'EOF'
#!/bin/bash

# RKHunter Update Script for systemd timer
# Enhanced with Slack notifications

# Configuration
SLACK_WEBHOOK_URL="SLACK_WEBHOOK_PLACEHOLDER"
HOSTNAME=$(hostname)
START_TIME=$(date)
SCRIPT_NAME="RKHunter Database Update"

EOF

create_slack_function /usr/local/bin/rkhunter-update.sh "RKHunter Update"

cat >> /usr/local/bin/rkhunter-update.sh << 'EOF'

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
EOF

chmod +x /usr/local/bin/rkhunter-update.sh

# Copy RKHunter service and timer files
cp $BASEDIR/configs/systemd/rkhunter-scan.service /etc/systemd/system/
cp $BASEDIR/configs/systemd/rkhunter-scan.timer /etc/systemd/system/
cp $BASEDIR/configs/systemd/rkhunter-update.service /etc/systemd/system/
cp $BASEDIR/configs/systemd/rkhunter-update.timer /etc/systemd/system/

# Update service files to use our scripts
sed -i 's|ExecStart=/usr/bin/rkhunter --cronjob --check --sk|ExecStart=/usr/local/bin/rkhunter-scan.sh|' /etc/systemd/system/rkhunter-scan.service
sed -i 's|ExecStart=/usr/bin/rkhunter --update --cronjob|ExecStart=/usr/local/bin/rkhunter-update.sh|' /etc/systemd/system/rkhunter-update.service

show_yellow "RKHunter systemd timers installed with Slack notifications."

##########################################################################################
## Install System Health Check timer
##########################################################################################

show_yellow "Installing System Health Check systemd timer."

# Copy system health service and timer files
cp $BASEDIR/configs/systemd/system-health-check.service /etc/systemd/system/
cp $BASEDIR/configs/systemd/system-health-check.timer /etc/systemd/system/

show_yellow "System Health Check systemd timer installed."

##########################################################################################
## Install Swap Monitor timer
##########################################################################################

show_yellow "Installing Swap Monitor systemd timer."

# Copy swap monitor service and timer files
cp $BASEDIR/configs/systemd/swap-monitor.service /etc/systemd/system/
cp $BASEDIR/configs/systemd/swap-monitor.timer /etc/systemd/system/

show_yellow "Swap Monitor systemd timer installed."

##########################################################################################
## Install Disk Space Monitor timer
##########################################################################################

show_yellow "Installing Disk Space Monitor systemd timer."

# Copy disk space monitor service and timer files
cp $BASEDIR/configs/systemd/disk-space-monitor.service /etc/systemd/system/
cp $BASEDIR/configs/systemd/disk-space-monitor.timer /etc/systemd/system/

show_yellow "Disk Space Monitor systemd timer installed."

##########################################################################################
## Enable and start systemd timers
##########################################################################################

##########################################################################################
## Configure Slack webhooks for all monitoring scripts
##########################################################################################

show_yellow "Configuring Slack notifications for monitoring scripts."

# Replace Slack webhook placeholder in all monitoring scripts if enabled
if [[ "$ENABLE_SLACK_MONITORING" =~ [Yy]$ ]] && [ -n "$SLACK_WEBHOOK_URL" ]; then
    # ClamAV scan script
    if [ -f /usr/local/bin/clamav-scan.sh ]; then
        sed -i 's|SLACK_WEBHOOK_PLACEHOLDER|'${SLACK_WEBHOOK_URL}'|g' /usr/local/bin/clamav-scan.sh
        show_yellow "ClamAV scan script configured with Slack notifications"
    fi
    
    # RKHunter scripts
    if [ -f /usr/local/bin/rkhunter-scan.sh ]; then
        sed -i 's|SLACK_WEBHOOK_PLACEHOLDER|'${SLACK_WEBHOOK_URL}'|g' /usr/local/bin/rkhunter-scan.sh
        show_yellow "RKHunter scan script configured with Slack notifications"
    fi
    
    if [ -f /usr/local/bin/rkhunter-update.sh ]; then
        sed -i 's|SLACK_WEBHOOK_PLACEHOLDER|'${SLACK_WEBHOOK_URL}'|g' /usr/local/bin/rkhunter-update.sh
        show_yellow "RKHunter update script configured with Slack notifications"
    fi
    
    # System health check script
    if [ -f $SCRIPTSDIR/system_health_check.sh ]; then
        sed -i 's|SLACK_WEBHOOK_PLACEHOLDER|'${SLACK_WEBHOOK_URL}'|g' $SCRIPTSDIR/system_health_check.sh
        show_yellow "System health check script configured with Slack notifications"
    fi
    
    # Swap monitoring script
    if [ -f $SCRIPTSDIR/check_swap_usage.sh ]; then
        sed -i 's|SLACK_WEBHOOK_PLACEHOLDER|'${SLACK_WEBHOOK_URL}'|g' $SCRIPTSDIR/check_swap_usage.sh
        show_yellow "Swap monitoring script configured with Slack notifications"
    fi
    
    # Disk space monitoring script (already handled in lightweight_monitoring_install.sh)
    if [ -f $SCRIPTSDIR/check_disk_space.sh ]; then
        sed -i 's|SLACK_WEBHOOK_PLACEHOLDER|'${SLACK_WEBHOOK_URL}'|g' $SCRIPTSDIR/check_disk_space.sh
        show_yellow "Disk space monitoring script configured with Slack notifications"
    fi
    
    show_yellow "All monitoring scripts configured with Slack notifications enabled"
else
    show_yellow "Slack notifications disabled for monitoring scripts"
fi

##########################################################################################
## Enable and start systemd timers
##########################################################################################

show_yellow "Enabling and starting systemd timers."

# Reload systemd daemon to recognize new units
systemctl daemon-reload >>$LOGDIR/$LOGFILE 2>&1

# Enable and start ClamAV timer
systemctl enable clamav-scan.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to enable ClamAV timer."
systemctl start clamav-scan.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to start ClamAV timer."

# Enable and start RKHunter timers
systemctl enable rkhunter-scan.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to enable RKHunter scan timer."
systemctl start rkhunter-scan.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to start RKHunter scan timer."

systemctl enable rkhunter-update.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to enable RKHunter update timer."
systemctl start rkhunter-update.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to start RKHunter update timer."

# Enable and start System Health Check timer
systemctl enable system-health-check.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to enable System Health Check timer."
systemctl start system-health-check.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to start System Health Check timer."

# Enable and start Swap Monitor timer
systemctl enable swap-monitor.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to enable Swap Monitor timer."
systemctl start swap-monitor.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to start Swap Monitor timer."

# Enable and start Disk Space Monitor timer
systemctl enable disk-space-monitor.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to enable Disk Space Monitor timer."
systemctl start disk-space-monitor.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to start Disk Space Monitor timer."

show_yellow "All systemd timers enabled and started."

##########################################################################################
## Display timer status
##########################################################################################

show_yellow "Systemd timer status:"
systemctl list-timers --no-pager | grep -E "(clamav|rkhunter|system-health|swap-monitor|disk-space-monitor)" || true

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done. Use 'systemctl list-timers' to view all timers."
show_info "View logs with: journalctl -u <service-name> --since yesterday"