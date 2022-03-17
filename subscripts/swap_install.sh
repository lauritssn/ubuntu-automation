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
## Install Swap
##########################################################################################
show_yellow "Creating 10 swap files of 1 Gb."

#SWAP_FILE_SIZE_GB=1
#SWAP_FILE_SIZE=((SWAP_FILE_SIZE_GB*1048576))

##!/bin/bash
#COUNTER=0
#while [  $COUNTER -lt 10 ]; do
#   echo The counter is $COUNTER
#   let COUNTER=COUNTER+1
#done


dd if=/dev/zero of=/var/tmp/swapfile01 bs=1024 count=1048576 >> $LOGDIR/$LOGFILE 2>&1
dd if=/dev/zero of=/var/tmp/swapfile02 bs=1024 count=1048576 >> $LOGDIR/$LOGFILE 2>&1
dd if=/dev/zero of=/var/tmp/swapfile03 bs=1024 count=1048576 >> $LOGDIR/$LOGFILE 2>&1
dd if=/dev/zero of=/var/tmp/swapfile04 bs=1024 count=1048576 >> $LOGDIR/$LOGFILE 2>&1
dd if=/dev/zero of=/var/tmp/swapfile05 bs=1024 count=1048576 >> $LOGDIR/$LOGFILE 2>&1
dd if=/dev/zero of=/var/tmp/swapfile06 bs=1024 count=1048576 >> $LOGDIR/$LOGFILE 2>&1
dd if=/dev/zero of=/var/tmp/swapfile07 bs=1024 count=1048576 >> $LOGDIR/$LOGFILE 2>&1
dd if=/dev/zero of=/var/tmp/swapfile08 bs=1024 count=1048576 >> $LOGDIR/$LOGFILE 2>&1
dd if=/dev/zero of=/var/tmp/swapfile09 bs=1024 count=1048576 >> $LOGDIR/$LOGFILE 2>&1
dd if=/dev/zero of=/var/tmp/swapfile10 bs=1024 count=1048576 >> $LOGDIR/$LOGFILE 2>&1

mkswap -c -v1 /var/tmp/swapfile01 >> $LOGDIR/$LOGFILE 2>&1
mkswap -c -v1 /var/tmp/swapfile02 >> $LOGDIR/$LOGFILE 2>&1
mkswap -c -v1 /var/tmp/swapfile03 >> $LOGDIR/$LOGFILE 2>&1
mkswap -c -v1 /var/tmp/swapfile04 >> $LOGDIR/$LOGFILE 2>&1
mkswap -c -v1 /var/tmp/swapfile05 >> $LOGDIR/$LOGFILE 2>&1
mkswap -c -v1 /var/tmp/swapfile06 >> $LOGDIR/$LOGFILE 2>&1
mkswap -c -v1 /var/tmp/swapfile07 >> $LOGDIR/$LOGFILE 2>&1
mkswap -c -v1 /var/tmp/swapfile08 >> $LOGDIR/$LOGFILE 2>&1
mkswap -c -v1 /var/tmp/swapfile09 >> $LOGDIR/$LOGFILE 2>&1
mkswap -c -v1 /var/tmp/swapfile10 >> $LOGDIR/$LOGFILE 2>&1

show_yellow "Swap files created"

show_yellow "Enable swap on files."

chmod 600 /var/tmp/swapfile01 >> $LOGDIR/$LOGFILE 2>&1
chmod 600 /var/tmp/swapfile02 >> $LOGDIR/$LOGFILE 2>&1
chmod 600 /var/tmp/swapfile03 >> $LOGDIR/$LOGFILE 2>&1
chmod 600 /var/tmp/swapfile04 >> $LOGDIR/$LOGFILE 2>&1
chmod 600 /var/tmp/swapfile05 >> $LOGDIR/$LOGFILE 2>&1
chmod 600 /var/tmp/swapfile06 >> $LOGDIR/$LOGFILE 2>&1
chmod 600 /var/tmp/swapfile07 >> $LOGDIR/$LOGFILE 2>&1
chmod 600 /var/tmp/swapfile08 >> $LOGDIR/$LOGFILE 2>&1
chmod 600 /var/tmp/swapfile09 >> $LOGDIR/$LOGFILE 2>&1
chmod 600 /var/tmp/swapfile10 >> $LOGDIR/$LOGFILE 2>&1

swapon /var/tmp/swapfile01 >> $LOGDIR/$LOGFILE 2>&1
swapon /var/tmp/swapfile02 >> $LOGDIR/$LOGFILE 2>&1
swapon /var/tmp/swapfile03 >> $LOGDIR/$LOGFILE 2>&1
swapon /var/tmp/swapfile04 >> $LOGDIR/$LOGFILE 2>&1
swapon /var/tmp/swapfile05 >> $LOGDIR/$LOGFILE 2>&1
swapon /var/tmp/swapfile06 >> $LOGDIR/$LOGFILE 2>&1
swapon /var/tmp/swapfile07 >> $LOGDIR/$LOGFILE 2>&1
swapon /var/tmp/swapfile08 >> $LOGDIR/$LOGFILE 2>&1
swapon /var/tmp/swapfile09 >> $LOGDIR/$LOGFILE 2>&1
swapon /var/tmp/swapfile10 >> $LOGDIR/$LOGFILE 2>&1

show_yellow "Swap files enabled"

##########################################################################################
## Replace sysctl configuration for swap
##########################################################################################

sed -i 's/#SWAP-REPLACE#//ig' $CONF_ORG >> $LOGDIR/$LOGFILE 2>&1 # Not done - Why not just replace the sysctl config from Git?
show_yellow "sysctl.conf swap customizations added."

show_yellow "Listing swap configuration:"
show_yellow "`swapon -s`"

show_yellow "Listing swap/memory usage:"
show_yellow "`free -m`"

##########################################################################################
## Replace sysctl configuration for Digital Ocean
##########################################################################################

sed -i 's/#DO-REPLACE#//ig' $CONF_ORG >> $LOGDIR/$LOGFILE 2>&1 # Not done - Why not just replace the sysctl config from Git?
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
