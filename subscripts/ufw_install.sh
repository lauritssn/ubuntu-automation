#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################
DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="ufw_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log

CONF_ORG_1=$SCRIPTSDIR/ufw.sh
CONF_BACK_1=$BACKUPDIR/$(basename $CONF_ORG_1)_$DATE

CONF_BACK_2=$BACKUPDIR/ufw_rules_$DATE

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Install UFW
##########################################################################################

apt-get --yes install ufw >$LOGDIR/$LOGFILE 2>&1 || (show_err "Installation of UFW failed. Please check logfile and fix error manually.")
show_yellow "UFW installation done."

##########################################################################################
## Check if a ufw.sh file exists and back up
##########################################################################################

if [ -f $CONF_ORG_1 ]; then
    cp -p $CONF_ORG_1 $CONF_BACK_1 && show_yellow "Config file $CONF_ORG_1 backed up to $CONF_BACK_1."
fi

##########################################################################################
## Back up active ufw rules
##########################################################################################

ufw status numbered >>$CONF_BACK_2 2>/dev/null
show_yellow "Backup of active ufw rules can be found in $CONF_BACK_2."

##########################################################################################
## Inform about UFW script - can be changed later if we want to apply rules by default
##########################################################################################

show_yellow "UFW script can now be run using: $(show_info "sudo bash $CONF_ORG_1")"
show_yellow "Contents of UFW script is shown below:"

cat $CONF_ORG_1 $CONF_BACK_2

##########################################################################################
## Configure UFW for Ubuntu 24.04
##########################################################################################

show_yellow "Configuring UFW defaults for Ubuntu 24.04."

# Configure defaults
ufw default deny incoming >>$LOGDIR/$LOGFILE 2>&1
ufw default allow outgoing >>$LOGDIR/$LOGFILE 2>&1

# Enable IPv6 support (Ubuntu 24.04 best practice)
sed -i 's/IPV6=no/IPV6=yes/' /etc/default/ufw 2>/dev/null || true

# Configure logging (Ubuntu 24.04 recommendation)
ufw logging on >>$LOGDIR/$LOGFILE 2>&1

show_yellow "UFW configured for Ubuntu 24.04 with IPv6 support and logging enabled."

##########################################################################################
## Enable UFW
##########################################################################################

ufw --force enable >>$LOGDIR/$LOGFILE 2>&1 || (show_yellow "ufw enable failed. Please check logfile and fix error manually.")
show_yellow "ufw enabled."

##########################################################################################
## Run UFW configuration script
##########################################################################################

if [ -f $CONF_ORG_1 ]; then
    show_yellow "Running UFW configuration script: $CONF_ORG_1"
    bash $CONF_ORG_1 >>$LOGDIR/$LOGFILE 2>&1 || (show_yellow "UFW script execution failed. Please check logfile and fix error manually.")
    show_yellow "UFW configuration script executed."
else
    show_yellow "UFW configuration script not found at $CONF_ORG_1"
fi

##########################################################################################
## Reload UFW to apply all configuration changes
##########################################################################################

ufw reload >>$LOGDIR/$LOGFILE 2>&1 || (show_yellow "ufw reload failed. Please check logfile and fix error manually.")
show_yellow "ufw reloaded to apply configuration changes."

##########################################################################################
## Verify UFW status
##########################################################################################

ufw status verbose >>$LOGDIR/$LOGFILE 2>&1
show_yellow "UFW status verified and logged."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
