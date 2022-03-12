#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################

DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="rkhunter_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
## RKHunter configuration
##########################################################################################

CONF1_ORG=/etc/default/rkhunter
CONF1_BACK=$BACKUPDIR/$(basename $CONF1_ORG)_$DATE
CONF1_GIT=$BASEDIR/configs/rkhunter/rkhunter

CONF2_ORG=/etc/rkhunter.conf
CONF2_BACK=$BACKUPDIR/$(basename $CONF2_ORG)_$DATE
CONF2_GIT=$BASEDIR/configs/rkhunter/rkhunter.conf

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Install RKHunter
##########################################################################################

apt-get --yes install rkhunter mailutils >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "rkhunter installation failed. Please check logfile and fix error manually.")
show_yellow "rkhunter installation done."

##########################################################################################
## Copy RKHunter configs
##########################################################################################

if [ -a $CONF1_ORG ]
   then
      cp -p $CONF1_ORG $CONF1_BACK && show_yellow "RKHunter file $CONF1_ORG backed up to $CONF1_BACK."
      cp $CONF1_GIT $CONF1_ORG && show_yellow "Default RKHunter configuration deployed."
   else
      cp $CONF1_GIT $CONF1_ORG && show_yellow "Default RKHunter configuration deployed."
fi

if [ -a $CONF2_ORG ]
   then
      cp -p $CONF2_ORG $CONF2_BACK && show_yellow "RKHunter file $CONF2_ORG backed up to $CONF2_BACK."
      cp $CONF2_GIT $CONF2_ORG && show_yellow "Default RKHunter scan configuration deployed."
   else
      cp $CONF2_GIT $CONF2_ORG && show_yellow "Default RKHunter scan configuration deployed."
fi

##########################################################################################
## Reconfigure E-mails
##########################################################################################

sed -i 's/INFO_EMAIL/'${INFO_EMAIL}'/ig' $CONF1_ORG
sed -i 's/EMAIL_DOMAIN/'${EMAIL_DOMAIN}'/ig' $CONF1_ORG

sed -i 's/INFO_EMAIL/'${INFO_EMAIL}'/ig' $CONF2_ORG
sed -i 's/EMAIL_DOMAIN/'${EMAIL_DOMAIN}'/ig' $CONF2_ORG

##########################################################################################
## Update rkhunter - exit'ing disabled due to weird but OK exit codes from RKHunter
##########################################################################################

rkhunter --update --skip-keypress >> $LOGDIR/$LOGFILE 2>&1 && show_yellow "RKHunter updated."
rkhunter --propupd --skip-keypress >> $LOGDIR/$LOGFILE 2>&1 && show_yellow "RKHunter properties updated."
rkhunter --check --skip-keypress >> $LOGDIR/$LOGFILE 2>&1 || show_yellow "RKHunter check done - check log file $LOGDIR/$LOGFILE."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
