#!/bin/bash

# https://linuxize.com/post/how-to-add-swap-space-on-ubuntu-20-04/

##########################################################################################
## Set variables
##########################################################################################

DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="swap_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
## General fstab configuration
##########################################################################################

CONF_ORG=/etc/fstab
CONF_BACK=$BACKUPDIR/$(basename $CONF_ORG)_$DATE

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Copy fstab config
##########################################################################################

if [ -a $CONF_ORG ]
   then
      cp -p $CONF_ORG $CONF_BACK && show_yellow "Fstab file $CONF_ORG backed up to $CONF_BACK."
fi

##########################################################################################
## Install Swap
##########################################################################################
show_yellow "Creating 1 swap file of 10 Gb."

dd if=/dev/zero of=/var/tmp/swapfile bs=1024 count=10485760 >> $LOGDIR/$LOGFILE 2>&1
mkswap -c -v1 /var/tmp/swapfile >> $LOGDIR/$LOGFILE 2>&1
chmod 600 /var/tmp/swapfile >> $LOGDIR/$LOGFILE 2>&1

show_yellow "Swap file created"

show_yellow "Enable swap on file."

swapon /var/tmp/swapfile >> $LOGDIR/$LOGFILE 2>&1

show_yellow "Swap files enabled"

##########################################################################################
## fstab configuration for swap
##########################################################################################

insertstring='/var/tmp/swapfile swap swap defaults 0 0'
searchstring=`echo $insertstring | sed 's/ //g'`

if (sed -r 's/[ ]+//gi' $CONF_ORG | grep -q "${searchstring}") ; then
	show_yellow "$insertstring - already present"
else
	echo "${insertstring}" >> $CONF_ORG
	show_yellow "'${insertstring}' appended to $CONF_ORG"
fi

show_yellow "Listing swap configuration:"
show_yellow "`swapon -s`"

show_yellow "Listing swap/memory usage:"
show_yellow "`free -m`"

##########################################################################################
## General sysctl configuration
##########################################################################################

CONF_ORG=/etc/sysctl.conf
CONF_BACK=$BACKUPDIR/$(basename $CONF_ORG)_$DATE

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
fi



##########################################################################################
## Replace sysctl configuration for swappiness
##########################################################################################

sed -i 's/#SWAP-REPLACE#//ig' $CONF_ORG >> $LOGDIR/$LOGFILE 2>&1
show_yellow "sysctl.conf swap customizations added."

##########################################################################################
## Restart sysctl
##########################################################################################

sysctl -p >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Sysctl restart failed. Please check logfile and fix error manually.")
show_yellow "Sysctl restarted."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done. Please check $CONF_ORG manually for swap settings."
