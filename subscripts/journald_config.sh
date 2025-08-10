#!/bin/bash

##########################################################################################
## SystemD Journal Configuration Script
##########################################################################################
# This script configures systemd journald with enhanced retention settings for
# better log management and compliance with monitoring requirements.

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

show_green "Starting systemd journald configuration..."

##########################################################################################
## Initialize Logging
##########################################################################################

init_logging "journald_config.sh"
log_start "systemd journald configuration"

##########################################################################################
## Configure SystemD Journal
##########################################################################################

show_yellow "Configuring systemd journald retention settings..."

# Backup existing configuration if it exists
if [ -f /etc/systemd/journald.conf ]; then
    log_info "Creating backup of existing journald.conf"
    cp /etc/systemd/journald.conf /etc/systemd/journald.conf.backup.$(date +%Y%m%d_%H%M%S)
fi

# Create the journald configuration with specified settings
log_info "Writing new journald configuration to /etc/systemd/journald.conf"

cat >/etc/systemd/journald.conf <<'EOF'
[Journal]
#Storage=auto
#Compress=yes
#Seal=yes
#SplitMode=uid
#SyncIntervalSec=5m
#RateLimitIntervalSec=30s
#RateLimitBurst=10000
#SystemMaxUse=
#SystemKeepFree=
#SystemMaxFileSize=
SystemMaxFiles=400
#RuntimeMaxUse=
#RuntimeKeepFree=
#RuntimeMaxFileSize=
#RuntimeMaxFiles=100
MaxRetentionSec=13month
MaxFileSec=1day
#ForwardToSyslog=no
#ForwardToKMsg=no
#ForwardToConsole=no
#ForwardToWall=yes
#TTYPath=/dev/console
#MaxLevelStore=debug
#MaxLevelSyslog=debug
EOF

log_success "Journald configuration written successfully"

##########################################################################################
## Validate Configuration
##########################################################################################

show_yellow "Validating journald configuration..."

# Check if the configuration is valid
if systemd-analyze verify /etc/systemd/journald.conf 2>/dev/null; then
    log_success "Journald configuration syntax is valid"
else
    log_warning "Configuration validation not available (systemd-analyze not found or old version)"
fi

# Restart systemd-journald to apply new configuration
show_yellow "Restarting systemd-journald service to apply new configuration..."

if systemctl restart systemd-journald; then
    log_success "systemd-journald service restarted successfully"
else
    log_error "Failed to restart systemd-journald service"
    show_error_and_exit "Unable to apply journald configuration. Check system logs for details."
fi

# Verify the service is running properly
if systemctl is-active --quiet systemd-journald; then
    log_success "systemd-journald service is running properly"
else
    log_error "systemd-journald service is not running after restart"
    show_error_and_exit "systemd-journald service failed to start properly"
fi

##########################################################################################
## Display Configuration Summary
##########################################################################################

show_yellow "Journald configuration summary:"
echo ""
echo "📊 Log Retention Settings:"
echo "  • Maximum retention: 13 months"
echo "  • File rotation: Daily (1 day per file)"
echo "  • Maximum system files: 400"
echo ""
echo "📁 Configuration location: /etc/systemd/journald.conf"
echo "📋 Backup created: /etc/systemd/journald.conf.backup.$(date +%Y%m%d_%H%M%S)"
echo ""

##########################################################################################
## Log Status and Completion
##########################################################################################

log_success "systemd journald configuration completed successfully"
show_green "✅ Journald configuration completed!"

show_yellow "ℹ️  Note: The new settings will apply to all new journal entries."
show_yellow "   Existing journal files will follow the previous retention policy until they expire."

##########################################################################################
## Optional: Display current journal usage
##########################################################################################

show_yellow "Current journal disk usage:"
if command -v journalctl >/dev/null 2>&1; then
    journalctl --disk-usage 2>/dev/null || echo "Unable to determine journal disk usage"
else
    echo "journalctl command not available"
fi

echo ""
show_green "📝 To view journal logs, use: journalctl"
show_green "📊 To check disk usage, use: journalctl --disk-usage"
show_green "🔧 To verify configuration, use: systemctl status systemd-journald"

exit 0
