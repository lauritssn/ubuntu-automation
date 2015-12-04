#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################

DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="general_system_settings.sh"

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
## Install NTPD
##########################################################################################

apt-get --yes --force-yes install ntp > $LOGDIR/$LOGFILE 2>&1 || ( show_err "Installation of NTP failed. Please check logfile and fix error manually.")
show_grey "NTP successfully installed."

##########################################################################################
# Fix language errors
##########################################################################################

insertstring='LC_ALL=en_GB.utf8'
searchstring=`echo $insertstring | sed 's/ //g'`
if (sed -r 's/[ ]+//gi' /etc/environment | grep -q "${searchstring}") ; then
	show_grey "$insertstring - already present"
else
	echo "${insertstring}" | tee -a /etc/environment >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Updating /etc/environment failed. Please check logfile and fix error manually.")
fi
show_grey "/etc/environment updated."

##########################################################################################
## Install extra packages
##########################################################################################

apt-get --yes --force-yes install curl dos2unix perl libnet-ssleay-perl openssl libauthen-pam-perl libpam-runtime libio-pty-perl apt-show-versions git subversion gcc build-essential libc6-dev autoconf automake dkms linux-headers-$(uname -r) sqlite3 libsqlite3-dev >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Installation of extra packages failed. Please check logfile and fix error manually.")
show_grey "Extra packages successfully installed."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
