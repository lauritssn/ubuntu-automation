#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################

DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="webmin_install.sh"

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
## Install Webmin
##########################################################################################

echo "deb http://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
show_grey "webmin repository added."
cd /tmp
wget -q http://www.webmin.com/jcameron-key.asc -O- | apt-key add - >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Adding repository key for webmin repository failed. Please check logfile and fix error manually.")
show_grey "webmin repository key added."

apt-get update >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "apt-get update failed. Please check logfile and fix error manually.")
show_grey "apt-get update done."
apt-get --yes --force-yes install webmin >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "webmin installation failed. Please check logfile and fix error manually.")
show_grey "webmin installation done."

##########################################################################################
## Create UFW rule
##########################################################################################

echo "ufw allow proto tcp from $SECURE_SUBNET to any port 10000 # $SECURE_SUBNET_DESC to Webmin" >> $CRONDIR/ufw.sh 2>&1 || ( show_err "Webmin UFW rule installation failed. Please check logfile and fix error manually.")
show_grey "ufw rule to allow acces to webmin from $SECURE_SUBNET_DESC($SECURE_SUBNET) added."

##########################################################################################
## Restart Webmin
##########################################################################################

service webmin restart >> $LOGDIR/$LOGFILE 2>&1 || ( show_grey "webmin service restart failed. Please check logfile and fix error manually.")
show_grey "webmin service restarted."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
