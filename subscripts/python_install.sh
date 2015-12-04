#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################

DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="python_install.sh"

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
## Install Python
##########################################################################################

apt-get --yes --force-yes install python python-dev build-essential libblas3gf libc6 libgcc1 libgfortran3 liblapack3gf libstdc++6 build-essential python-all-dev libatlas-base-dev gfortran  python-software-properties python-numpy  python-scipy python-pandas python-selenium >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "python installation failed. Please check logfile and fix error manually.")
show_grey "python installation done."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."