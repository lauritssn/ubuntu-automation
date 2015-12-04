#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################
DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="ufw_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log

CONF_ORG_1=$CRONDIR/ufw.sh
CONF_BACK_1=$BACKUPDIR/$(basename $CONF_ORG_1)_$DATE

CONF_BACK_2=$BACKUPDIR/ufw_rules_$DATE

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Install UFW
##########################################################################################

apt-get --yes --force-yes install ufw > $LOGDIR/$LOGFILE 2>&1 || ( show_err "Installation of UFW failed. Please check logfile and fix error manually.")
show_grey "UFW installation done."

##########################################################################################
## Check if a ufw.sh file exists and back up
##########################################################################################

if [ -f $CONF_ORG_1 ];
then
   cp -p $CONF_ORG_1 $CONF_BACK_1 && show_grey "Config file $CONF_ORG_1 backed up to $CONF_BACK_1."
fi

##########################################################################################
## Back up active ufw rules
##########################################################################################

ufw status numbered >> $CONF_BACK_2 2>/dev/null
show_grey "Backup of active ufw rules can be found in $CONF_BACK_2."

##########################################################################################
## Inform about UFW script - can be changed later if we want to apply rules by default
##########################################################################################

show_grey "UFW script can now be run using: `show_info "sudo $CONF_ORG_1"`"
show_grey "Contents of UFW script is shown below:"

cat $CONF_ORG_1 $CONF_BACK_2

#@todo need ufw enable in script

##########################################################################################
## Enable UFW
##########################################################################################

ufw --force enable >> $LOGDIR/$LOGFILE 2>&1 || ( show_grey "ufw enable failed. Please check logfile and fix error manually.")
show_grey "ufw enabled."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
