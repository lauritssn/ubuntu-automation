#!/bin/bash

##########################################################################################
## System Update Script
##
## Description:
## This script performs system package updates using apt-get commands.
##
## Ubuntu Config Files Changed/Altered:
## - /var/lib/apt/lists/* - Package list files updated during 'apt-get update'
## - /var/cache/apt/archives/* - Package cache updated during package downloads
## - /var/lib/dpkg/status - Package status database updated during upgrades
## - /var/lib/dpkg/info/* - Package information files updated during upgrades
## - /var/log/apt/history.log - APT command history log updated
## - /var/log/apt/term.log - APT terminal output log updated
## - /var/log/dpkg.log - DPKG operations log updated
## - Various system files under /etc/, /usr/, /lib/, etc. - Updated by individual packages
## - Package configuration files in /etc/ - May be updated by upgraded packages
##
## Note: This script does not directly modify configuration files, but the package
## upgrades it performs may update system configuration files as part of the normal
## package upgrade process. Users should review any configuration file prompts
## during the upgrade process.
##########################################################################################

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
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="system_update.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/srv/apps/logs
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
## Info
##########################################################################################
show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Run update
##########################################################################################

apt-get update >$LOGDIR/$LOGFILE 2>&1 || (show_err "apt-get update failed. Please check logfile and fix error manually.")
show_yellow "apt-get update done."

apt-get --yes upgrade >>$LOGDIR/$LOGFILE 2>&1 || (show_err "apt-get --yes upgrade failed. Please check logfile and fix error manually.")
show_yellow "apt-get upgrade done."

apt-get --yes autoremove >>$LOGDIR/$LOGFILE 2>&1 || (show_err "apt-get autoremove failed. Please check logfile and fix error manually.")
show_yellow "apt-get autoremove done."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
