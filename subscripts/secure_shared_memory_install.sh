#!/bin/bash

##########################################################################################
## Source shared helper functions
##########################################################################################

# Set BASEDIR early for shared functions to use
export BASEDIR="${BASEDIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source the shared helper functions
if [ -f "$BASEDIR/utils/shared_functions.sh" ]; then
    source "$BASEDIR/utils/shared_functions.sh"
else
    echo "❌ ERROR: Shared functions script not found at $BASEDIR/utils/shared_functions.sh"
    echo "Please run this script from the ubuntu-automation directory or set BASEDIR environment variable"
    exit 1
fi

# Fallback function definitions if shared functions aren't available
if ! command -v show_info &>/dev/null; then
    show_info() { echo "INFO: $1"; }
    show_warn() { echo "WARN: $1"; }
    show_err() {
        echo "ERROR: $1"
        exit 1
    }
    show_yellow() { echo "STATUS: $1"; }
fi

##########################################################################################
## Secure Shared Memory Configuration
##########################################################################################

##########################################################################################
## Ubuntu Configuration Files Modified by this Script
##########################################################################################
##
## Files Modified:
## - /etc/fstab - Adds secure shared memory mount configuration
##
## Files Backed up:
## - /etc/fstab -> $BACKUPDIR/fstab_<timestamp>
##
##########################################################################################

##########################################################################################
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="secure_shared_memory_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/srv/apps/logs
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

cp -p $CONF_ORG $CONF_BACK && show_yellow "Config file $CONF_ORG backed up to $CONF_BACK."

##########################################################################################
## Check for secure shared memory and insert if not there
##########################################################################################

insertstring='tmpfs /dev/shm tmpfs defaults,noexec,nosuid 0 0'
searchstring=$(echo $insertstring | sed 's/ //g')

if (sed -r 's/[ ]+//gi' $CONF_ORG | grep -q "${searchstring}"); then
    show_yellow "$insertstring - already present"
else
    echo "${insertstring}" >>$CONF_ORG
    show_yellow "'${insertstring}' appended to $CONF_ORG"
fi

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done. Please reboot server to take effect."
