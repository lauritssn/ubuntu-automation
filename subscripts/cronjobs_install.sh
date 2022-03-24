##!/bin/bash
#
#
###########################################################################################
### Set variables
###########################################################################################
#
#DATE=`date +%Y-%m-%d_%H%M`
#SUBSCRIPT="cronjobs_install.sh"
#
#if [ -n "$LOGDIR" ]; then
#    LOGDIR=$LOGDIR
#else
#    LOGDIR=/tmp
#fi
#
#LOGFILE=$SUBSCRIPT-$DATE.log
#
###########################################################################################
### Info
###########################################################################################
#
#show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."
#
###########################################################################################
### Write password to secret file
###########################################################################################
#echo "linux_cronjobs:${CRONJOBS_PASS}" >> $CRONDIR/pswd
#
###########################################################################################
### Create cronjobs user
###########################################################################################
#
#USER="cronjobs"
#GROUP="www-data"
#
## If $USER doesn't exist, add it. If that fails, print but don't exit.
#id $USER > /dev/null 2>&1 || (adduser --disabled-password --gecos "" $USER > $LOGDIR/$LOGFILE 2>&1 || ( show_err "Create cronjobs user failed." ))
#
#usermod -g $GROUP $USER >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Changing $USER group to $GROUP failed." )
#show_yellow "Group for $USER changed to $GROUP."
#
#echo "$USER:$CRONJOBS_PASS" | chpasswd >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Changing cronjobs user password failed." )
#show_yellow "$USER user password set to: `show_info "$CRONJOBS_PASS"`"
#
###########################################################################################
### Done
###########################################################################################
#
#show_info "$SUBSCRIPT done."
