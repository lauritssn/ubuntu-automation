#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################

DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="system_update.sh"

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
## Run update
##########################################################################################

apt-get update > $LOGDIR/$LOGFILE 2>&1 || ( show_err "apt-get update failed. Please check logfile and fix error manually.")
show_yellow "apt-get update done."

apt-get --yes --force-yes upgrade >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "apt-get --yes --force-yes upgrade failed. Please check logfile and fix error manually.")
show_yellow "apt-get upgrade done."

apt-get --yes --force-yes autoremove >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "apt-get autoremove failed. Please check logfile and fix error manually.")
show_yellow "apt-get autoremove done."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
