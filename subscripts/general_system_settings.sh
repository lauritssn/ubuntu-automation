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
## Install NTP
##########################################################################################

show_yellow "Install NTP."

CONF_NTP_ORG=/etc/systemd/timesyncd.conf
CONF_NTP_BACK=$BACKUPDIR/$(basename $CONF_NTP_ORG)_$DATE

apt --yes purge chrony > $LOGDIR/$LOGFILE 2>&1 || ( show_err "Removal of Chrony failed. Please check logfile and fix error manually.")

show_yellow "Replace NTP config."
sed -i 's/#NTP=/'NTP=${NTP}'/ig' $CONF_NTP_ORG
sed -i 's/#FallbackNTP=ntp\.ubuntu\.com/'FallbackNTP=${NTP_FALLBACK}'/ig' $CONF_NTP_ORG

show_yellow "Restart NTP services."
systemctl restart systemd-timesyncd
systemctl status systemd-timesyncd
timedatectl
timedatectl show-timesync

show_yellow "NTP successfully installed."

## @TODO
## https://snippets.aktagon.com/snippets/614-how-to-fix-bash-warning-setlocale-lc-all-cannot-change-locale-en-us-
###########################################################################################
## Fix language errors
###########################################################################################
#
#insertstring='LC_ALL=en_GB.utf8'
#searchstring=`echo $insertstring | sed 's/ //g'`
#if (sed -r 's/[ ]+//gi' /etc/environment | grep -q "${searchstring}") ; then
#	show_yellow "$insertstring - already present"
#else
#	echo "${insertstring}" | tee -a /etc/environment >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Updating /etc/environment failed. Please check logfile and fix error manually.")
#fi
#show_yellow "/etc/environment updated."

##########################################################################################
## Install extra packages
##########################################################################################

apt-get --yes install curl dos2unix perl libnet-ssleay-perl openssl libauthen-pam-perl libpam-runtime libio-pty-perl apt-show-versions git subversion gcc build-essential libc6-dev autoconf automake dkms linux-headers-$(uname -r) sqlite3 libsqlite3-dev >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Installation of extra packages failed. Please check logfile and fix error manually.")
show_yellow "Extra packages successfully installed."

# @TODO https://www.informaticar.net/security-hardening-ubuntu-20-04/
##########################################################################################
## Secure SSHD
##########################################################################################
# PermitRootLogin no
# MaxAuthTries 5
# Protocol 2
# ClientAliveInterval 300
# AllowUsers zeljko informaticar

# service ssh restart

# Logging
#SyslogFacility AUTH
#LogLevel INFO

# Authentication:

#LoginGraceTime 2m
#PermitRootLogin prohibit-password


##########################################################################################
## Disable root account completely
##########################################################################################

passwd -l root

# @TODO
##########################################################################################
## Enable Google Authenticator
##########################################################################################

#apt install libpam-google-authenticator
#nano /etc/pam.d/sshd
#Add following line: auth required pam_google_authenticator.so
#
#sudo nano /etc/ssh/sshd_config
#Change to yes following line: ChallengeResponseAuthentication yes
#for user type in terminal: google-authenticator
#
#Time-based tokens - answer: y
#update .google_authenticator file - answer: y
#Dissalow multiple uses – y
#Permit shew of up to 4 minutes – n
#Enable rate limiting – y
#
#service ssh restart

# @TODO
##########################################################################################
## Enable Certificate Authentication
##########################################################################################
# https://www.informaticar.net/configure-passwordless-ssh-login-in-linux/


##########################################################################################
## Disable message of the day
##########################################################################################

systemctl disable motd-news.service
sed -i 's/^ENABLED=.*/ENABLED=0/' /etc/default/motd-news

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
