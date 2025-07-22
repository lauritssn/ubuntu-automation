#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="rkhunter_install.sh"

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
## RKHunter configuration
##########################################################################################

CONF1_ORG=/etc/default/rkhunter
CONF1_BACK=$BACKUPDIR/$(basename $CONF1_ORG)_$DATE
CONF1_GIT=$BASEDIR/configs/rkhunter/rkhunter

CONF2_ORG=/etc/rkhunter.conf
CONF2_BACK=$BACKUPDIR/$(basename $CONF2_ORG)_$DATE
CONF2_GIT=$BASEDIR/configs/rkhunter/rkhunter.conf

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Install RKHunter
##########################################################################################

apt-get --yes install rkhunter mailutils >>$LOGDIR/$LOGFILE 2>&1 || (show_err "rkhunter installation failed. Please check logfile and fix error manually.")
show_yellow "rkhunter installation done."

##########################################################################################
## Copy RKHunter configs
##########################################################################################

if [ -a $CONF1_ORG ]; then
   cp -p $CONF1_ORG $CONF1_BACK && show_yellow "RKHunter file $CONF1_ORG backed up to $CONF1_BACK."
   cp $CONF1_GIT $CONF1_ORG && show_yellow "Default RKHunter configuration deployed."
else
   cp $CONF1_GIT $CONF1_ORG && show_yellow "Default RKHunter configuration deployed."
fi

if [ -a $CONF2_ORG ]; then
   cp -p $CONF2_ORG $CONF2_BACK && show_yellow "RKHunter file $CONF2_ORG backed up to $CONF2_BACK."
   cp $CONF2_GIT $CONF2_ORG && show_yellow "Default RKHunter scan configuration deployed."
else
   cp $CONF2_GIT $CONF2_ORG && show_yellow "Default RKHunter scan configuration deployed."
fi

##########################################################################################
## Reconfigure E-mails
##########################################################################################

# Use the helper function to replace template variables properly
replace_script_variables "$CONF1_ORG"
replace_script_variables "$CONF2_ORG"

# Verify that all placeholders were replaced correctly
verify_script_template "$CONF1_ORG" "RKHunter Default Config"
verify_script_template "$CONF2_ORG" "RKHunter Main Config"

##########################################################################################
## Update rkhunter - exit'ing disabled due to weird but OK exit codes from RKHunter
##########################################################################################

rkhunter --update --skip-keypress >>$LOGDIR/$LOGFILE 2>&1 && show_yellow "RKHunter updated."
rkhunter --propupd --skip-keypress >>$LOGDIR/$LOGFILE 2>&1 && show_yellow "RKHunter properties updated."
rkhunter --check --skip-keypress >>$LOGDIR/$LOGFILE 2>&1 || show_yellow "RKHunter check done - check log file $LOGDIR/$LOGFILE."

##########################################################################################
## Note: RKHunter scheduling now handled by systemd timers
##########################################################################################

show_yellow "RKHunter scanning and updates will be configured via systemd timers."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
