#!/bin/bash

##########################################################################################
## Source shared helper functions
##########################################################################################

# Set BASEDIR early for shared functions to use
export BASEDIR="${BASEDIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source the shared helper functions
if [ -f "$BASEDIR/utils/shared_functions.sh" ]; then
    source "$BASEDIR/utils/shared_functions.sh"
else
    echo "❌ ERROR: Shared functions script not found at $BASEDIR/utils/shared_functions.sh"
    echo "Please run this script from the ubuntu-automation directory or set BASEDIR environment variable"
    exit 1
fi

# Fallback function definitions if shared functions aren't available
if ! command -v show_info &>/dev/null; then
    show_info() { echo "INFO: $1"; }
    show_warn() { echo "WARN: $1"; }
    show_err() {
        echo "ERROR: $1"
        exit 1
    }
    show_yellow() { echo "STATUS: $1"; }
fi

##########################################################################################
## Systemd Timers Installation and Configuration
##########################################################################################
#
# This script modifies, creates, or copies the following Ubuntu system files:
#
# SYSTEMD SERVICE & TIMER FILES (copied to /etc/systemd/system/):
#   - clamav-scan.service
#   - clamav-scan.timer
#   - clamav-update.service
#   - clamav-update.timer
#   - rkhunter-scan.service
#   - rkhunter-scan.timer
#   - rkhunter-update.service
#   - rkhunter-update.timer
#   - maldet-scan.service
#   - maldet-scan.timer
#   - maldet-update.service
#   - maldet-update.timer
#   - system-health-check.service
#   - system-health-check.timer
#   - swap-monitor.service
#   - swap-monitor.timer
#   - disk-space-monitor.service
#   - disk-space-monitor.timer
#
# EXECUTABLE SCRIPTS (created/copied to /usr/local/bin/):
#   - clamav-scan.sh (from script template)
#   - clamav-update.sh (from script template)
#   - rkhunter-scan.sh (from script template)
#   - rkhunter-update.sh (from script template)
#   - maldet-scan.sh (from script template)
#   - maldet-update.sh (from script template)
#
# DIRECTORIES CREATED:
#   - /etc/systemd/system/ (if not exists)
#
# FILE OWNERSHIP CHANGES:
#   - /var/lib/clamav/* (set to clamav:clamav)
#
# SYSTEMD DAEMON MODIFICATIONS:
#   - systemctl daemon-reload (reloads systemd configuration)
#   - Enables and starts all installed timer units
#
##########################################################################################

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
## Helper functions are available via parent script (install.sh or run_subscript.sh)
##########################################################################################

# Note: Script template helper functions are available through shared_functions.sh
# which is already sourced by the parent script (install.sh or run_subscript.sh)

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

# Verify ClamAV daemon is working before setting up timers
if systemctl is-active --quiet clamav-daemon.service; then
    show_yellow "ClamAV daemon is running - systemd timers can be configured."
else
    show_warn "ClamAV daemon is not running. Attempting to start..."
    if systemctl start clamav-daemon.service >>$LOGDIR/$LOGFILE 2>&1; then
        show_yellow "ClamAV daemon started successfully."
    else
        show_err "ClamAV daemon failed to start. Please check 'systemctl status clamav-daemon' for details."
        exit 1
    fi
fi

# Ensure ClamAV database directory has proper ownership before starting timers
if [ -d "/var/lib/clamav" ]; then
    show_yellow "Ensuring proper ClamAV database ownership before configuring timers..."
    chown -R clamav:clamav /var/lib/clamav 2>/dev/null || true
fi

# Copy ClamAV service and timer files
cp $BASEDIR/configs/systemd/clamav-scan.service /etc/systemd/system/
cp $BASEDIR/configs/systemd/clamav-scan.timer /etc/systemd/system/
cp $BASEDIR/configs/systemd/clamav-update.service /etc/systemd/system/
cp $BASEDIR/configs/systemd/clamav-update.timer /etc/systemd/system/

# Copy ClamAV scan script from utils/monitoring/scripts/
SOURCE_CLAMAV_SCAN="$BASEDIR/utils/monitoring/scripts/clamav-scan.sh"
DEST_CLAMAV_SCAN="/usr/local/bin/clamav-scan.sh"

if [ -f "$SOURCE_CLAMAV_SCAN" ]; then
    show_yellow "Installing ClamAV scan script from $SOURCE_CLAMAV_SCAN"
    cp "$SOURCE_CLAMAV_SCAN" "$DEST_CLAMAV_SCAN"
    sed -i "s|{{SLACK_WEBHOOK_URL}}|${SLACK_WEBHOOK_URL:-}|g" "$DEST_CLAMAV_SCAN"
    chmod +x "$DEST_CLAMAV_SCAN"
    show_yellow "ClamAV scan script installed at $DEST_CLAMAV_SCAN"
else
    show_warn "Source ClamAV scan script not found at $SOURCE_CLAMAV_SCAN"
fi

# Copy ClamAV update script from utils/monitoring/scripts/
SOURCE_CLAMAV_UPDATE="$BASEDIR/utils/monitoring/scripts/clamav-update.sh"
DEST_CLAMAV_UPDATE="/usr/local/bin/clamav-update.sh"

if [ -f "$SOURCE_CLAMAV_UPDATE" ]; then
    show_yellow "Installing ClamAV update script from $SOURCE_CLAMAV_UPDATE"
    cp "$SOURCE_CLAMAV_UPDATE" "$DEST_CLAMAV_UPDATE"
    sed -i "s|{{SLACK_WEBHOOK_URL}}|${SLACK_WEBHOOK_URL:-}|g" "$DEST_CLAMAV_UPDATE"
    chmod +x "$DEST_CLAMAV_UPDATE"
    show_yellow "ClamAV update script installed at $DEST_CLAMAV_UPDATE"
else
    show_warn "Source ClamAV update script not found at $SOURCE_CLAMAV_UPDATE"
fi

show_yellow "ClamAV systemd timers installed with Slack notifications enabled."

##########################################################################################
## Install RKHunter systemd timers
##########################################################################################

show_yellow "Installing RKHunter systemd timers."

# Copy RKHunter scan script from utils/monitoring/scripts/
SOURCE_RKHUNTER_SCAN="$BASEDIR/utils/monitoring/scripts/rkhunter-scan.sh"
DEST_RKHUNTER_SCAN="/usr/local/bin/rkhunter-scan.sh"

if [ -f "$SOURCE_RKHUNTER_SCAN" ]; then
    show_yellow "Installing RKHunter scan script from $SOURCE_RKHUNTER_SCAN"
    cp "$SOURCE_RKHUNTER_SCAN" "$DEST_RKHUNTER_SCAN"
    sed -i "s|{{SLACK_WEBHOOK_URL}}|${SLACK_WEBHOOK_URL:-}|g" "$DEST_RKHUNTER_SCAN"
    chmod +x "$DEST_RKHUNTER_SCAN"
    show_yellow "RKHunter scan script installed at $DEST_RKHUNTER_SCAN"
else
    show_warn "Source RKHunter scan script not found at $SOURCE_RKHUNTER_SCAN"
fi

# Copy RKHunter update script from utils/monitoring/scripts/
SOURCE_RKHUNTER_UPDATE="$BASEDIR/utils/monitoring/scripts/rkhunter-update.sh"
DEST_RKHUNTER_UPDATE="/usr/local/bin/rkhunter-update.sh"

if [ -f "$SOURCE_RKHUNTER_UPDATE" ]; then
    show_yellow "Installing RKHunter update script from $SOURCE_RKHUNTER_UPDATE"
    cp "$SOURCE_RKHUNTER_UPDATE" "$DEST_RKHUNTER_UPDATE"
    sed -i "s|{{SLACK_WEBHOOK_URL}}|${SLACK_WEBHOOK_URL:-}|g" "$DEST_RKHUNTER_UPDATE"
    chmod +x "$DEST_RKHUNTER_UPDATE"
    show_yellow "RKHunter update script installed at $DEST_RKHUNTER_UPDATE"
else
    show_warn "Source RKHunter update script not found at $SOURCE_RKHUNTER_UPDATE"
fi

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

# Copy Maldet update script from utils/monitoring/scripts/
SOURCE_MALDET_UPDATE="$BASEDIR/utils/monitoring/scripts/maldet-update.sh"
DEST_MALDET_UPDATE="/usr/local/bin/maldet-update.sh"

if [ -f "$SOURCE_MALDET_UPDATE" ]; then
    show_yellow "Installing Maldet update script from $SOURCE_MALDET_UPDATE"
    cp "$SOURCE_MALDET_UPDATE" "$DEST_MALDET_UPDATE"
    sed -i "s|{{SLACK_WEBHOOK_URL}}|${SLACK_WEBHOOK_URL:-}|g" "$DEST_MALDET_UPDATE"
    chmod +x "$DEST_MALDET_UPDATE"
    show_yellow "Maldet update script installed at $DEST_MALDET_UPDATE"
else
    show_warn "Source Maldet update script not found at $SOURCE_MALDET_UPDATE"
fi

# Copy Maldet update service and timer files
cp $BASEDIR/configs/systemd/maldet-update.service /etc/systemd/system/
cp $BASEDIR/configs/systemd/maldet-update.timer /etc/systemd/system/

show_yellow "Maldet Update systemd timer installed with Slack notifications."

##########################################################################################
## Install Maldet Scan timer
##########################################################################################

show_yellow "Installing Maldet Scan systemd timer."

# Copy Maldet scan script from utils/monitoring/scripts/
SOURCE_MALDET_SCAN="$BASEDIR/utils/monitoring/scripts/maldet-scan.sh"
DEST_MALDET_SCAN="/usr/local/bin/maldet-scan.sh"

if [ -f "$SOURCE_MALDET_SCAN" ]; then
    show_yellow "Installing Maldet scan script from $SOURCE_MALDET_SCAN"
    cp "$SOURCE_MALDET_SCAN" "$DEST_MALDET_SCAN"
    sed -i "s|{{SLACK_WEBHOOK_URL}}|${SLACK_WEBHOOK_URL:-}|g" "$DEST_MALDET_SCAN"
    chmod +x "$DEST_MALDET_SCAN"
    show_yellow "Maldet scan script installed at $DEST_MALDET_SCAN"
else
    show_warn "Source Maldet scan script not found at $SOURCE_MALDET_SCAN"
fi

# Copy Maldet scan service and timer files
cp $BASEDIR/configs/systemd/maldet-scan.service /etc/systemd/system/
cp $BASEDIR/configs/systemd/maldet-scan.timer /etc/systemd/system/

show_yellow "Maldet Scan systemd timer installed with independent scanning."

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

# Enable and start ClamAV timers
systemctl enable clamav-scan.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to enable ClamAV scan timer."
systemctl start clamav-scan.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to start ClamAV scan timer."

systemctl enable clamav-update.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to enable ClamAV update timer."
systemctl start clamav-update.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to start ClamAV update timer."

# Enable and start RKHunter timers
systemctl enable rkhunter-scan.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to enable RKHunter scan timer."
systemctl start rkhunter-scan.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to start RKHunter scan timer."

systemctl enable rkhunter-update.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to enable RKHunter update timer."
systemctl start rkhunter-update.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to start RKHunter update timer."

# Enable and start Maldet update timer
systemctl enable maldet-update.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to enable Maldet update timer."
systemctl start maldet-update.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to start Maldet update timer."

# Enable and start Maldet scan timer
systemctl enable maldet-scan.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to enable Maldet scan timer."
systemctl start maldet-scan.timer >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to start Maldet scan timer."

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
systemctl list-timers --no-pager | grep -E "(clamav|rkhunter|system-health|swap-monitor|disk-space-monitor|maldet)" || true

show_yellow "Slack-enabled monitoring scripts installed:"
echo "  ✅ /srv/apps/scripts/check_disk_space.sh"
echo "  ✅ /srv/apps/scripts/check_swap_usage.sh"
echo "  ✅ /srv/apps/scripts/system_health_check.sh"
echo "  ✅ /usr/local/bin/clamav-scan.sh"
echo "  ✅ /usr/local/bin/clamav-update.sh"
echo "  ✅ /usr/local/bin/rkhunter-scan.sh"
echo "  ✅ /usr/local/bin/rkhunter-update.sh"
echo "  ✅ /usr/local/bin/maldet-scan.sh"
echo "  ✅ /usr/local/bin/maldet-update.sh"

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done. Use 'systemctl list-timers' to view all timers."
show_info "View logs with: journalctl -u <service-name> --since yesterday"
