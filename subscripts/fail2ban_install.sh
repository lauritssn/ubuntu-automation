#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="fail2ban_install.sh"

if [ -n "$LOGDIR" ]; then
   LOGDIR=$LOGDIR
else
   LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
# General Fail2Ban configuration
##########################################################################################

CONF1_ORG=/etc/fail2ban/jail.conf
CONF1_BACK=$BACKUPDIR/$(basename $CONF1_ORG)_$DATE
CONF1_GIT=$BASEDIR/configs/fail2ban/jail.conf

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Install Fail2Ban
##########################################################################################
if ! apt-get --yes install fail2ban >>$LOGDIR/$LOGFILE 2>&1; then
    show_err "Installation of fail2ban failed. Please check logfile and fix error manually."
    exit 1
fi
show_yellow "Installation of fail2ban done."

##########################################################################################
## Copy Fail2Ban configs
##########################################################################################

if [ -a $CONF1_ORG ]; then
   cp -p $CONF1_ORG $CONF1_BACK && show_yellow "Fail2Ban file $CONF1_ORG backed up to $CONF1_BACK."
   cp $CONF1_GIT $CONF1_ORG && show_yellow "Default Fail2Ban configuration deployed."
else
   cp $CONF1_GIT $CONF1_ORG && show_yellow "Default Fail2Ban configuration deployed."
fi

##########################################################################################
## Reconfigure E-mails
##########################################################################################

sed -i 's/INFO_EMAIL/'${INFO_EMAIL}'/ig' $CONF1_ORG
sed -i 's/EMAIL_DOMAIN/'${EMAIL_DOMAIN}'/ig' $CONF1_ORG

show_yellow "Email adresses reconfigured."

##########################################################################################
## Restart Fail2Ban
##########################################################################################

systemctl restart fail2ban >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Restarting Fail2Ban failed. Please check logfile and fix error manually.")
show_yellow "Fail2Ban restarted."

##########################################################################################
## Done
##########################################################################################

show_info "Fail2Ban installation done."
