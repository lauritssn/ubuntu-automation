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
## Load script template helper functions
##########################################################################################

# Source helper functions for script template management
source "$BASEDIR/configs/script-templates/script_helper_functions.sh"

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

# Create ClamAV scan script using template
copy_and_configure_script "clamav-scan.sh" "/usr/local/bin/clamav-scan.sh" "ClamAV Scan Script"

# Verify script template variables
verify_script_template "/usr/local/bin/clamav-scan.sh" "ClamAV Scan"

show_yellow "ClamAV systemd timer installed with false positive reduction enabled."

##########################################################################################
## Install RKHunter systemd timers
##########################################################################################

show_yellow "Installing RKHunter systemd timers."

# Create RKHunter scan script using template
copy_and_configure_script "rkhunter-scan.sh" "/usr/local/bin/rkhunter-scan.sh" "RKHunter Scan Script"

# Verify script template variables
verify_script_template "/usr/local/bin/rkhunter-scan.sh" "RKHunter Scan"

# Create RKHunter update script using template
copy_and_configure_script "rkhunter-update.sh" "/usr/local/bin/rkhunter-update.sh" "RKHunter Update Script"

# Verify script template variables
verify_script_template "/usr/local/bin/rkhunter-update.sh" "RKHunter Update"

# Copy RKHunter service and timer files
cp $BASEDIR/configs/systemd/rkhunter-scan.service /etc/systemd/system/
cp $BASEDIR/configs/systemd/rkhunter-scan.timer /etc/systemd/system/
cp $BASEDIR/configs/systemd/rkhunter-update.service /etc/systemd/system/
cp $BASEDIR/configs/systemd/rkhunter-update.timer /etc/systemd/system/

show_yellow "RKHunter systemd timers installed with Slack notifications."

##########################################################################################
## Install Maldet Update timer
##########################################################################################

show_yellow "Installing Maldet Update systemd timer."

# Create Maldet update script using template
copy_and_configure_script "maldet-update.sh" "/usr/local/bin/maldet-update.sh" "Maldet Update Script"

# Verify script template variables
verify_script_template "/usr/local/bin/maldet-update.sh" "Maldet Update"

# Copy Maldet update service and timer files
cp $BASEDIR/configs/systemd/maldet-update.service /etc/systemd/system/
cp $BASEDIR/configs/systemd/maldet-update.timer /etc/systemd/system/

show_yellow "Maldet Update systemd timer installed with Slack notifications."

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

# Note: Slack webhook configuration is now handled automatically by the
# copy_and_configure_script function using script templates
if [[ "$ENABLE_SLACK_MONITORING" =~ [Yy]$ ]] && [ -n "$SLACK_WEBHOOK_URL" ]; then
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

# Enable and start Maldet update timer
systemctl enable maldet-update.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to enable Maldet update timer."
systemctl start maldet-update.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to start Maldet update timer."

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
