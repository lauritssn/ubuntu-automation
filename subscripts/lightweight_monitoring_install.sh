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
## Lightweight Monitoring Install Script
##########################################################################################
## This script installs and configures lightweight monitoring tools for Ubuntu 24.04
##
## UBUNTU CONFIGURATION FILES MODIFIED:
## ------------------------------------
## System Files:
##   /etc/default/sysstat                    - Modified: Enables sysstat data collection
##
## Created Files:
##   /etc/skel/.bash_aliases                 - Created: Monitoring aliases template for new users
##   /root/.bash_aliases                     - Created: Monitoring aliases for root user
##   $SCRIPTSDIR/system_health_check.sh      - Created: System health monitoring script
##   $SCRIPTSDIR/check_disk_space.sh         - Created: Disk space monitoring script
##
## Template Files Used:
##   configs/script-templates/system_health_check.sh    - Template for system health script
##   configs/script-templates/check_disk_space.sh       - Template for disk space script
##
## Services Modified:
##   sysstat.service                         - Enabled and restarted for system statistics
##
## Packages Installed:
##   sysstat, nethogs, ncdu, tree           - Lightweight monitoring tools
##
##########################################################################################

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
## Helper functions are available via parent script (install.sh or run_subscript.sh)
##########################################################################################

# Note: Script template helper functions are available through shared_functions.sh
# which is already sourced by the parent script (install.sh or run_subscript.sh)

##########################################################################################
## Info
##########################################################################################
show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Install lightweight monitoring tools
##########################################################################################

show_yellow "Installing lightweight monitoring tools."

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

##########################################################################################
## Configure disk space monitoring script
##########################################################################################

show_yellow "Configuring disk space monitoring script with Slack integration."

# Note: Slack webhook configuration is now handled automatically by the
# copy_and_configure_script function using script templates
if [[ "$ENABLE_SLACK_MONITORING" =~ [Yy]$ ]] && [ -n "$SLACK_WEBHOOK_URL" ]; then
    show_yellow "Disk space monitoring script configured with Slack notifications enabled"
else
    show_yellow "Disk space monitoring script configured (Slack notifications disabled)"
fi

##########################################################################################
## Create monitoring aliases and shortcuts
##########################################################################################

show_yellow "Creating monitoring aliases."

# Create .bash_aliases file for monitoring shortcuts
cat >/etc/skel/.bash_aliases <<'EOF'
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
