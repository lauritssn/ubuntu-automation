#!/bin/bash

# http://sysmagazine.com/posts/134974/

##########################################################################################
## Set variables
##########################################################################################

DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="redis_install.sh"

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
## Install Redis
##########################################################################################

apt-get --yes --force-yes install redis-server >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "redis installation failed. Please check logfile and fix error manually.")
show_grey "redis installation done."

##########################################################################################
## Create UFW rule
##########################################################################################

echo "ufw allow proto tcp from $SECURE_SUBNET to any port 6379 # $SECURE_SUBNET_DESC to redis" >> $CRONDIR/ufw.sh 2>&1 || ( show_err "Redis UFW rule installation failed. Please check logfile and fix error manually.")
show_grey "ufw rule to allow acces to redis from $SECURE_SUBNET_DESC($SECURE_SUBNET) added."

##########################################################################################
## Restart redis
##########################################################################################

service redis-server restart >> $LOGDIR/$LOGFILE 2>&1 || ( show_grey "redis service restart failed. Please check logfile and fix error manually.")
show_grey "redis service restarted."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
