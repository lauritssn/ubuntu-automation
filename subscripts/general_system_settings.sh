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

##########################################################################################
## Backup config
##########################################################################################

if [ -a $CONF_NTP_ORG ]
   then
      cp -p $CONF_NTP_ORG $CONF_NTP_BACK && show_yellow "NTP conf file $CONF_NTP_ORG backed up to $CONF_NTP_BACK."
fi


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
show_yellow "Install extra packages."
apt-get --yes install acct atop curl dos2unix perl libnet-ssleay-perl openssl libauthen-pam-perl libpam-runtime libio-pty-perl apt-show-versions git subversion gcc build-essential libc6-dev autoconf automake dkms linux-headers-$(uname -r) sqlite3 libsqlite3-dev >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Installation of extra packages failed. Please check logfile and fix error manually.")
show_yellow "Extra packages successfully installed."

# @TODO https://www.informaticar.net/security-hardening-ubuntu-20-04/
##########################################################################################
## Secure SSHD
##########################################################################################

CONF_SSH_ORG=/etc/ssh/sshd_config
CONF_SSH_BACK=$BACKUPDIR/$(basename $CONF_NTP_ORG)_$DATE

##########################################################################################
## Backup config
##########################################################################################

if [ -a $CONF_SSH_ORG ]
   then
      cp -p $CONF_SSH_ORG $CONF_SSH_BACK && show_yellow "SSH conf file $CONF_SSH_ORG backed up to $CONF_SSH_BACK."
fi

sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' $CONF_SSH_ORG
sed -i 's/^MaxAuthTries.*/MaxAuthTries 5/' $CONF_SSH_ORG
sed -i 's/^Protocol.*/Protocol 2/' $CONF_SSH_ORG
sed -i 's/^ClientAliveInterval.*/ClientAliveInterval 300/' $CONF_SSH_ORG

sed -i 's/^LoginGraceTime.*/LoginGraceTime 2m/' $CONF_SSH_ORG
sed -i 's/^PermitRootLogin.*/PermitRootLogin prohibit-password/' $CONF_SSH_ORG

sed -i 's/^SyslogFacility.*/SyslogFacility AUTH/' $CONF_SSH_ORG
sed -i 's/^LogLevel.*/LogLevel INFO/' $CONF_SSH_ORG
sed -i 's/^PermitRootLogin.*/PermitRootLogin prohibit-password/' $CONF_SSH_ORG

# AllowUsers some_user1 some_user2

service ssh restart



##########################################################################################
## Disable root account completely
##########################################################################################
show_yellow "Disable root account."
passwd -l root > $LOGDIR/$LOGFILE 2>&1 || ( show_err "root disable failed. Please check logfile and fix error manually.")
show_yellow "root account disabled."

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
show_yellow "Disable message of the day."
systemctl disable motd-news.service > $LOGDIR/$LOGFILE 2>&1 || ( show_err "Stop message of the day service failed. Please check logfile and fix error manually.")
sed -i 's/^ENABLED=.*/ENABLED=0/' /etc/default/motd-news > $LOGDIR/$LOGFILE 2>&1 || ( show_err "Disable message of the day service failed. Please check logfile and fix error manually.")
show_yellow "Message of the day disabled."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
