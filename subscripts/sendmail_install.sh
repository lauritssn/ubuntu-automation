#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################

DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="sendmail_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
## General sendmail configuration
##########################################################################################

## https://www.cloudbooklet.com/how-to-install-and-setup-sendmail-on-ubuntu/

#CONF_ORG=/etc/sysctl.conf
#CONF_BACK=$BACKUPDIR/$(basename $CONF_ORG)_$DATE
#CONF_GIT=$BASEDIR/configs/sysctl/sysctl.conf

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."
show_info "Nothing done."
show_info "$SUBSCRIPT done."


