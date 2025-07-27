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
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="netdata_install.sh"

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
## Install Netdata
##########################################################################################

## https://learn.netdata.cloud/guides/longer-metrics-storage/

show_yellow "Installing Netdata - you may need to answer yes to certain install commands."

show_yellow "Please install Netdata using Netdata script from your account instead."
# cd /tmp
# bash <(curl -Ss https://my-netdata.io/kickstart.sh) >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Installation of Netdata package failed. Please check logfile and fix error manually.")

if ! apt-get --yes install netdata >>$LOGDIR/$LOGFILE 2>&1; then
    show_err "Installation of netdata failed. Please check logfile and fix error manually."
    exit 1
fi
show_yellow "Netdata installed successfully."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
