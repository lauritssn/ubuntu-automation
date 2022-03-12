#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################

DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="clamav_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
# General ClamAV configuration
##########################################################################################

CONF_ORG=/etc/cron.daily/clamav
CONF_BACK=$BACKUPDIR/$(basename $CONF_ORG)_$DATE
CONF_GIT=$BASEDIR/configs/clamav/clamav

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Install ClamAV
##########################################################################################

apt-get --yes install clamav clamav-daemon clamav-freshclam > $LOGDIR/$LOGFILE 2>&1 || ( show_err "ClamAV installation failed. Please check logfile and fix error manually.")
show_yellow "ClamAV installation successfull."

##########################################################################################
## Update ClamAV
##########################################################################################

show_yellow "Updating ClamAV (this may take a while!)."
systemctl stop clamav-freshclam.service >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Stopping freshclam service failed. Please check logfile and fix error manually.")
freshclam >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "ClamAV update failed. Please check logfile and fix error manually.")
systemctl start clamav-freshclam.service >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Starting freshclam service failed. Please check logfile and fix error manually.")
show_yellow "ClamAV update done."

##########################################################################################
## Copy ClamAV cronjob
##########################################################################################

if [ -a $CONF_ORG ]
   then
      cp -p $CONF_ORG $CONF_BACK && show_yellow "ClamAV cron job file $CONF_ORG backed up to $CONF_BACK."
      cp $CONF_GIT $CONF_ORG && show_yellow "Default ClamAV cronjob deployed."
   else
      cp $CONF_GIT $CONF_ORG && show_yellow "Default ClamAV cronjob deployed."
fi

##########################################################################################
## Reconfigure E-mails
##########################################################################################

sed -i 's/INFO_EMAIL/'${INFO_EMAIL}'/ig' $CONF_ORG
sed -i 's/EMAIL_DOMAIN/'${EMAIL_DOMAIN}'/ig' $CONF_ORG

##########################################################################################
## Make the file executable.
##########################################################################################

chmod +x $CONF_ORG >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Making ClamAV cron job $CONF_ORG executable failed. Please check logfile and fix error manually.")
show_yellow "ClamAV cron job $CONF_ORG made executable."

##########################################################################################
## Restart ClamAV
##########################################################################################

service clamav-daemon restart >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Restarting ClamAV failed. Please check logfile and fix error manually.")
show_yellow "ClamAV restarted."

#@todo - error in clamav email replacement

##########################################################################################
## DONE
##########################################################################################

show_info "$SUBSCRIPT done."
