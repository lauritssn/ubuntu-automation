#!/bin/bash

##########################################################################################
## NTP Installation Script
##########################################################################################
##
## Description: Configures NTP time synchronization using systemd-timesyncd
##
## Ubuntu Config Files Modified/Altered:
## - /etc/systemd/timesyncd.conf - Modified to set custom NTP servers (if specified)
##
## Ubuntu Config Files Backed Up:
## - /etc/systemd/timesyncd.conf -> $BACKUPDIR/timesyncd.conf_$DATE
##
## System Services Affected:
## - systemd-timesyncd - Restarted after configuration changes
## - chrony - Purged if found (to avoid conflicts)
##
## System Commands Used:
## - timedatectl set-ntp true - Enables NTP synchronization
## - timedatectl status - Verifies NTP configuration
## - timedatectl show-timesync - Shows current NTP servers
##
##########################################################################################

##########################################################################################
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="general_system_settings.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/srv/apps/logs
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

# Source the sed helpers for safe operations
if [ -f "$BASEDIR/utils/helpers/sed_helpers.sh" ]; then
    source "$BASEDIR/utils/helpers/sed_helpers.sh"
elif [ -f "$(dirname "$0")/../utils/helpers/sed_helpers.sh" ]; then
    source "$(dirname "$0")/../utils/helpers/sed_helpers.sh"
else
    show_warn "sed_helpers.sh not found - using legacy sed operations"
fi

##########################################################################################
## Install NTP
##########################################################################################

show_yellow "Install NTP."

CONF_NTP_ORG=/etc/systemd/timesyncd.conf
CONF_NTP_BACK=$BACKUPDIR/$(basename $CONF_NTP_ORG)_$DATE

##########################################################################################
## Backup config
##########################################################################################

if [ -a $CONF_NTP_ORG ]; then
    cp -p $CONF_NTP_ORG $CONF_NTP_BACK && show_yellow "NTP conf file $CONF_NTP_ORG backed up to $CONF_NTP_BACK."
fi

# Handle potential NTP conflicts gracefully
if dpkg -l | grep -q chrony; then
    show_yellow "Removing conflicting chrony package."
    apt --yes purge chrony >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Chrony removal had issues, continuing with systemd-timesyncd anyway."
fi

show_yellow "Configure NTP using modern timedatectl approach."
# Use timedatectl for modern NTP configuration
timedatectl set-ntp true >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to enable NTP synchronization."

# Configure timesyncd.conf for custom NTP servers
if [[ "$NTP" != "dk.pool.ntp.org" ]] || [[ "$NTP_FALLBACK" != "pool.ntp.org" ]]; then
    show_yellow "Configuring custom NTP servers."

    # Use safe functions for NTP configuration to handle special characters
    if command -v safe_uncomment_and_replace >/dev/null 2>&1; then
        safe_uncomment_and_replace "$CONF_NTP_ORG" "NTP" "$NTP" "ntp_backup"
        safe_uncomment_and_replace "$CONF_NTP_ORG" "FallbackNTP" "$NTP_FALLBACK" "ntp_backup"
    else
        # Fallback to safer sed with alternate separator
        sed -i "s|#NTP=.*|NTP=${NTP}|g" "$CONF_NTP_ORG"
        sed -i "s|#FallbackNTP=.*|FallbackNTP=${NTP_FALLBACK}|g" "$CONF_NTP_ORG"
    fi

    systemctl restart systemd-timesyncd >>$LOGDIR/$LOGFILE 2>&1
fi

show_yellow "Verify NTP configuration."
timedatectl status | grep "NTP service"
timedatectl show-timesync --property=ServerName --property=ServerAddress 2>/dev/null || true

show_yellow "NTP successfully installed."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
