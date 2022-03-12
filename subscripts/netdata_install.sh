#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################
DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="netdata_install.sh"

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
## Install Netdata
##########################################################################################

## https://learn.netdata.cloud/guides/longer-metrics-storage/

show_yellow "Installing Netdata - you may need to answer yes to certain install commands."
cd /tmp
bash <(curl -Ss https://my-netdata.io/kickstart.sh) >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Installation of Netdata package failed. Please check logfile and fix error manually.")
show_yellow "Netdata installed successfully."

##########################################################################################
## Create UFW rule
##########################################################################################

echo "ufw allow proto tcp from $SECURE_SUBNET to any port 19999 # $SECURE_SUBNET_DESC to Netdata" >> $CRONDIR/ufw.sh || ( show_err "Netdata UFW rule installation failed. Please check logfile and fix error manually.")
show_yellow "ufw rule to allow access to Netdata from $SECURE_SUBNET_DESC($SECURE_SUBNET) added."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
