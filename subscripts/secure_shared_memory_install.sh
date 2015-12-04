#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################

DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="secure_shared_memory_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
## Backup fstab configuration
##########################################################################################

CONF_ORG=/etc/fstab
CONF_BACK=$BACKUPDIR/$(basename $CONF_ORG)_$DATE

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Copy fstab configuration
##########################################################################################

cp -p $CONF_ORG $CONF_BACK && show_grey "Config file $CONF_ORG backed up to $CONF_BACK."

##########################################################################################
## Check for secure shared memory and insert if not there
##########################################################################################

insertstring='tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0'
searchstring=`echo $insertstring | sed 's/ //g'`

if (sed -r 's/[ ]+//gi' $CONF_ORG | grep -q "${searchstring}") ; then
	show_grey "$insertstring - already present"
else
	echo "${insertstring}" >> $CONF_ORG
	show_grey "'${insertstring}' appended to $CONF_ORG"
fi	

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done. Please reboot server to take effect."

