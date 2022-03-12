#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################

DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="sysctl_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
## General sysctl configuration
##########################################################################################

CONF_ORG=/etc/sysctl.conf
CONF_BACK=$BACKUPDIR/$(basename $CONF_ORG)_$DATE
CONF_GIT=$BASEDIR/configs/sysctl/sysctl.conf

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Copy sysctl config
##########################################################################################

if [ -a $CONF_ORG ]
   then
      cp -p $CONF_ORG $CONF_BACK && show_yellow "Sysctl file $CONF_ORG backed up to $CONF_BACK."
      cp $CONF_GIT $CONF_ORG && show_yellow "Default sysctl configuration deployed."
   else
      cp $CONF_GIT $CONF_ORG && show_yellow "Default sysctl configuration deployed."
fi

##########################################################################################
## Restart sysctl
##########################################################################################

sysctl -p >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Sysctl restart failed. Please check logfile and fix error manually.")
show_yellow "Sysctl restarted."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done. Please check $CONF_ORG manually for swap settings."


