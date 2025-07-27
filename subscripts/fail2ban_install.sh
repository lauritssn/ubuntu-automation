#!/bin/bash

##########################################################################################
## UBUNTU CONFIGURATION FILES MODIFIED BY THIS SCRIPT
##########################################################################################
#
# This script modifies the following Ubuntu system configuration files:
#
# FILES CREATED/COPIED:
# • /etc/fail2ban/jail.conf - Main fail2ban configuration (backed up if exists)
# • /etc/fail2ban/filter.d/wireguard.conf - WireGuard-specific fail2ban filter (optional)
#
# FILES MODIFIED IN-PLACE:
# • /etc/fail2ban/jail.conf - Email addresses are updated via sed substitution:
#   - INFO_EMAIL placeholder replaced with actual email address
#   - EMAIL_DOMAIN placeholder replaced with actual domain
#
# SERVICES AFFECTED:
# • fail2ban service - restarted after configuration changes
#
# BACKUP LOCATIONS:
# • Original jail.conf backed up to: $BACKUPDIR/jail.conf_<timestamp>
#
##########################################################################################

##########################################################################################
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="fail2ban_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/srv/apps/logs
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
# General Fail2Ban configuration
##########################################################################################

CONF1_ORG=/etc/fail2ban/jail.conf
CONF1_BACK=$BACKUPDIR/$(basename $CONF1_ORG)_$DATE
CONF1_GIT=$BASEDIR/configs/fail2ban/jail.conf

# WireGuard filter configuration
FILTER_WG_ORG=/etc/fail2ban/filter.d/wireguard.conf
FILTER_WG_GIT=$BASEDIR/configs/fail2ban/filter.d/wireguard.conf

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Install Fail2Ban
##########################################################################################
if ! apt-get --yes install fail2ban >>$LOGDIR/$LOGFILE 2>&1; then
    show_err "Installation of fail2ban failed. Please check logfile and fix error manually."
    exit 1
fi
show_yellow "Installation of fail2ban done."

##########################################################################################
## Copy Fail2Ban configs
##########################################################################################

if [ -f $CONF1_ORG ]; then
    cp -p $CONF1_ORG $CONF1_BACK && show_yellow "Fail2Ban file $CONF1_ORG backed up to $CONF1_BACK."
    cp $CONF1_GIT $CONF1_ORG && show_yellow "Default Fail2Ban configuration deployed."
else
    cp $CONF1_GIT $CONF1_ORG && show_yellow "Default Fail2Ban configuration deployed."
fi

# Copy WireGuard filter if it exists
if [ -f $FILTER_WG_GIT ]; then
    cp $FILTER_WG_GIT $FILTER_WG_ORG && show_yellow "WireGuard fail2ban filter deployed."
else
    show_warn "WireGuard filter not found, skipping WireGuard protection."
fi

##########################################################################################
## Reconfigure E-mails
##########################################################################################

# Source the sed helpers for safe operations
source "$SCRIPTDIR/../utils/helpers/sed_helpers.sh"

# Use safe email replacement functions
replace_email_placeholder "$CONF1_ORG" "INFO_EMAIL" "$INFO_EMAIL"
replace_email_placeholder "$CONF1_ORG" "EMAIL_DOMAIN" "$EMAIL_DOMAIN"

show_yellow "Email adresses reconfigured."

##########################################################################################
## Restart Fail2Ban
##########################################################################################

if ! systemctl restart fail2ban >>$LOGDIR/$LOGFILE 2>&1; then
    show_err "Restarting Fail2Ban failed. Please check logfile and fix error manually."
    exit 1
fi
show_yellow "Fail2Ban restarted."

##########################################################################################
## Validate Configuration
##########################################################################################

show_yellow "Validating Fail2Ban configuration."

# Test fail2ban configuration
if fail2ban-client --test >>$LOGDIR/$LOGFILE 2>&1; then
    show_yellow "Fail2Ban configuration test passed."
else
    show_warn "Fail2Ban configuration test failed. Check logfile: $LOGDIR/$LOGFILE"
fi

##########################################################################################
## Done
##########################################################################################

show_info "Fail2Ban installation done."
show_info "=== Fail2Ban Configuration Summary ==="
show_info "✅ SSH Protection: ENABLED (aggressive mode, 3 attempts, 2h ban)"
show_info "✅ WireGuard Protection: ENABLED (5 attempts, 1h ban)"
show_info "✅ Recidive Protection: ENABLED (repeat offenders, 1 week ban)"
show_info "✅ Progressive Ban Times: ENABLED (bans get longer for repeat offenses)"
show_info "✅ Email Notifications: CONFIGURED"
show_info ""
show_info "Use 'sudo $SCRIPTSDIR/show_fail2ban_status.sh' or 'sudo $BASEDIR/utils/show_fail2ban_status.sh' to monitor protection status."
show_info "Available commands: status, jails, bans, recent, events, config, test, unban, ssh, wireguard"
