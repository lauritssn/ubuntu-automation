##!/bin/bash
#
#
###########################################################################################
### Set variables
###########################################################################################
#
#DATE=`date +%Y-%m-%d_%H%M`
#SUBSCRIPT="administrator_install.sh"
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
#echo "linux_administrator:${ADMINISTRATOR_PASS}" >> $CRONDIR/pswd
#
###########################################################################################
### Create administrator user
###########################################################################################
#
#USER="administrator"
#GROUP="www-data"
#
## If $USER doesn't exist, add it. If that fails, print but don't exit.
#id $USER > /dev/null 2>&1 || (adduser --disabled-password --gecos "" $USER > $LOGDIR/$LOGFILE 2>&1 || ( show_err "Create administrator user failed." ))
#
##@todo - exit script if user exists
#
#usermod -g $GROUP $USER >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Changing $USER group to $GROUP failed." )
#show_yellow "Group for $USER changed to $GROUP."
#
#echo "$USER:$ADMINISTRATOR_PASS" | chpasswd >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Changing administrator user password failed." )
#show_yellow "$USER user password set to: `show_info "$ADMINISTRATOR_PASS"`"
#
## @todo
## sudo vi /etc/sudoers
## administrator ALL=(ALL:ALL) ALL
#
###########################################################################################
### Done
###########################################################################################
#
#show_info "$SUBSCRIPT done."
