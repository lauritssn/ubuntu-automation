#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################
DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="systemd_timers_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log

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
# Based on original cron script but optimized for systemd

# Directories to scan
SCAN_DIR="/home /tmp /var /srv"

# Exclude common false positive locations and file types
# You can uncomment and modify these as needed
EXCLUDE_OPTS="--exclude-dir=/tmp/systemd-private* --exclude-dir=/var/lib/docker --exclude-dir=/var/cache --exclude=*.pid --exclude=*.lock --exclude=*.sock"

# Alternative: More restrictive /tmp scanning (recommended for high false positive environments)
# SCAN_DIR="/home /var/log /var/www /srv"

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

check_scan () {
    # If there were infected files detected, send email alert
    if [ $(tail -n 12 ${LOG_FILE} | grep Infected | grep -v 0 | wc -l) != 0 ]; then
        # Count number of infections
        SCAN_RESULTS=$(tail -n 10 $LOG_FILE | grep 'Infected files')
        INFECTIONS=${SCAN_RESULTS##* }

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
    else
        echo "ClamAV scan completed. No threats found."
    fi
}

# Run ClamAV scan with low priority
echo "Starting ClamAV scan at $(date)"
if [ $AGGRESSIVE = 1 ]; then
    /usr/bin/clamscan -ri --remove $EXCLUDE_OPTS $SCAN_DIR >> $LOG_FILE 2>&1
else
    /usr/bin/clamscan -ri $EXCLUDE_OPTS $SCAN_DIR >> $LOG_FILE 2>&1
fi

# Check scan results and send notifications
check_scan

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

# Copy RKHunter service and timer files
cp $BASEDIR/configs/systemd/rkhunter-scan.service /etc/systemd/system/
cp $BASEDIR/configs/systemd/rkhunter-scan.timer /etc/systemd/system/
cp $BASEDIR/configs/systemd/rkhunter-update.service /etc/systemd/system/
cp $BASEDIR/configs/systemd/rkhunter-update.timer /etc/systemd/system/

show_yellow "RKHunter systemd timers installed."

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