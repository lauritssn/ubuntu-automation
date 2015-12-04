#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################

DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="memcached_install.sh"

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
## Install Memcached
##########################################################################################

apt-get --yes --force-yes install memcached >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "memcached installation failed. Please check logfile and fix error manually.")
show_grey "memcached installation done."

##########################################################################################
## Create UFW rule
##########################################################################################

echo "ufw allow proto tcp from $SECURE_SUBNET to any port 11211 # $SECURE_SUBNET_DESC to Memcached" >> $CRONDIR/ufw.sh 2>&1 || ( show_err "Memcached UFW rule installation failed. Please check logfile and fix error manually.")
show_grey "ufw rule to allow acces to memcached from $SECURE_SUBNET_DESC($SECURE_SUBNET) added."

##########################################################################################
## Restart Memcached
##########################################################################################

service memcached restart >> $LOGDIR/$LOGFILE 2>&1 || ( show_grey "memcached service restart failed. Please check logfile and fix error manually.")
show_grey "memcached service restarted."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
