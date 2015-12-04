#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################

DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="email_alter.sh"
#LOGDIR=/some/other/path # Set the log directory to a different directory than /tmp

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log


SET_EMAIL_DOMAIN=N
SET_EMAIL_ADDRESS=N

EMAIL_DOMAIN_OLD="olddomain.dk"
INFO_EMAIL_OLD="old.mail@${EMAIL_DOMAIN_OLD}"
EMAIL_DOMAIN_NEW="new.domain"
INFO_EMAIL_NEW="new.mail@${EMAIL_DOMAIN_NEW}"

BACKUPDIR="/var/deploy/automation-backup"

# Create /var/deploy/automation-backup if it doesn't exist - also creates /var/deploy ($DEPLOYDIR)
if [ ! -d $BACKUPDIR ]
   then
      mkdir -p $BACKUPDIR
fi

##########################################################################################
## Message/logging functions
##########################################################################################

# Grey
show_grey () {
    echo $(tput bold)$(tput setaf 0) $@ $(tput sgr 0)
}
# White
show_norm () {
    echo $(tput bold)$(tput setaf 9) $@ $(tput sgr 0)
}
# Blue
show_info () {
    echo $(tput bold)$(tput setaf 4) $@ $(tput sgr 0)
}
# Green
show_warn () {
    echo $(tput bold)$(tput setaf 2) $@ $(tput sgr 0)
}
# Red
show_err ()  {
    echo $(tput bold)$(tput setaf 1) $@ $(tput sgr 0)
}

##########################################################################################
## Check if we're are root
##########################################################################################

if [[ $EUID -ne 0 ]]; then
   show_err "Script must be run as root. Please check logfile and fix error manually."
   exit 1
fi

##########################################################################################
## Get input
##########################################################################################

read -p "Do You want to change e-mail domain (Y/N)?" -n 1 SET_EMAIL_DOMAIN; echo
if [[ $SET_EMAIL_DOMAIN =~ [Yy]$ ]]
   then
      read -p "Enter new e-mail domain (only domain part of e-mail address): " EMAIL_DOMAIN_NEW
fi

read -p "Do You want to change e-mail address (Y/N)?" -n 1 SET_EMAIL_ADDRESS; echo
if [[ $SET_EMAIL_ADDRESS =~ [Yy]$ ]]
   then
      read -p "Enter new full e-mail address (xxx@domain.com): " INFO_EMAIL_NEW
fi

##########################################################################################
## Main
##########################################################################################
## THEN THE SCRIPT SHOULD FIRST BACKUP AND THEN REPLACE IN ANY KNOWN CONFIG FILE WHERE WE CHANGED E_MAIL
## 1. DOMAIN
## 2. SERVER.SUPPORT

if [[ $SET_EMAIL_DOMAIN =~ [Yy]$ ]]
   then
      show_info "Setting e-mail domain to $EMAIL_DOMAIN_NEW"
   else
      show_warn "e-mail domain will not be changed." 
fi

if [[ $SET_EMAIL_ADDRESS =~ [Yy]$ ]]
   then
      show_info "Setting e-mail address to $INFO_EMAIL_NEW"
   else
      show_warn "e-mail address will not be changed." 
fi

##########################################################################################
## RKHunter configuration
##########################################################################################

CONF1_ORG=/etc/default/rkhunter
CONF1_BACK=$BACKUPDIR/$(basename $CONF1_ORG)_$DATE

CONF2_ORG=/etc/rkhunter.conf
CONF2_BACK=$BACKUPDIR/$(basename $CONF2_ORG)_$DATE

# Backup and replace email addresses in config files

if [ -a $CONF1_ORG ]
   then
      cp -p $CONF1_ORG $CONF1_BACK && show_grey "Config file $CONF1_ORG backed up to $CONF1_BACK."
      sed -i 's/REPORT_EMAIL=.*/REPORT_EMAIL="'$INFO_EMAIL_NEW'"/ig' $CONF1_ORG >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Replacing mail address in $CONF1_ORG failed. Please check logfile and fix error manually.")
      show_grey "Mail address $INFO_EMAIL_NEW changed in $CONF1_ORG."
   else
      show_info "$CONF1_ORG doesn't exist. Nothing done."
fi

if [ -a $CONF2_ORG ]
   then
      cp -p $CONF2_ORG $CONF2_BACK && show_grey "Config file $CONF2_ORG backed up to $CONF2_BACK."
      sed -i 's/MAIL-ON-WARNING=.*/MAIL-ON-WARNING="'$INFO_EMAIL_NEW'/ig' $CONF2_ORG >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Replacing mail address in $CONF2_ORG failed. Please check logfile and fix error manually.")
      show_grey "Mail address $INFO_EMAIL_NEW changed in $CONF2_ORG."
   else
      show_info "$CONF2_ORG doesn't exist. Nothing done."
fi

##########################################################################################
# General maldet configuration
##########################################################################################

CONF3_ORG=/usr/local/maldetect/conf.maldet
CONF3_BACK=$BACKUPDIR/$(basename $CONF3_ORG)_$DATE

# Backup and replace email addresses in config files

if [ -a $CONF3_ORG ]
   then
      cp -p $CONF3_ORG $CONF3_BACK && show_grey "Config file $CONF3_ORG backed up to $CONF3_BACK."
      sed -i 's/email_addr=.*/email_addr="'$EMAIL_DOMAIN_NEW'"/ig' $CONF3_ORG >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Replacing mail address in $CONF3_ORG failed. Please check logfile and fix error manually.")
      show_grey "Mail address $INFO_EMAIL_NEW changed in $CONF3_ORG."
   else
      show_info "$CONF3_ORG doesn't exist. Nothing done."
fi

##########################################################################################
# General Fail2Ban configuration
##########################################################################################

CONF4_ORG=/etc/fail2ban/jail.conf
CONF4_BACK=$BACKUPDIR/$(basename $CONF4_ORG)_$DATE

CONF5_ORG=/etc/fail2ban/action.d/sendmail-common.local
CONF5_BACK=$BACKUPDIR/$(basename $CONF5_ORG)_$DATE

# Backup and replace email addresses in config files

if [ -a $CONF4_ORG ]
   then
      cp -p $CONF4_ORG $CONF4_BACK && show_grey "Config file $CONF4_ORG backed up to $CONF4_BACK."
      sed -i 's/destemail = .*/destemail = '$INFO_EMAIL_NEW'/ig' $CONF4_ORG >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Replacing mail address in $CONF4_ORG failed. Please check logfile and fix error manually.")
      show_grey "Mail address $INFO_EMAIL_NEW changed in $CONF4_ORG."
   else
      show_info "$CONF4_ORG doesn't exist. Nothing done."
fi

if [ -a $CONF5_ORG ]
   then
      cp -p $CONF5_ORG $CONF5_BACK && show_grey "Config file $CONF5_ORG backed up to $CONF5_BACK."
      sed -i 's/sender =.*/sender = '$EMAIL_DOMAIN_NEW'/ig' $CONF5_ORG >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Replacing domain in $CONF5_ORG failed. Please check logfile and fix error manually.")
      show_grey "Sender domain $EMAIL_DOMAIN_NEW changed in $CONF5_ORG."
   else
      show_info "$CONF5_ORG doesn't exist. Nothing done."
fi

##########################################################################################
# General ClamAV configuration
##########################################################################################

CONF6_ORG=/etc/cron.daily/vr_clamav
CONF6_BACK=$BACKUPDIR/$(basename $CONF6_ORG)_$DATE

# Backup and replace email addresses in config files

if [ -a $CONF6_ORG ]
   then
      cp -p $CONF6_ORG $CONF6_BACK && show_grey "Config file $CONF6_ORG backed up to $CONF6_BACK."
      sed -i 's/EMAIL=.*/EMAIL="'$INFO_EMAIL_NEW'"/ig' $CONF6_ORG >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Replacing mail address in $CONF6_ORG failed. Please check logfile and fix error manually.")
      show_grey "Mail address $INFO_EMAIL_NEW changed in $CONF6_ORG."
      sed -i 's/EMAIL_FROM=.*/EMAIL_FROM="clamav@'$EMAIL_DOMAIN_NEW'"/ig' $CONF6_ORG >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Replacing domain in $CONF6_ORG failed. Please check logfile and fix error manually.")
      show_grey "Domain $EMAIL_DOMAIN_NEW changed in $CONF6_ORG."
   else
      show_info "$CONF6_ORG doesn't exist. Nothing done."
fi

##########################################################################################
# General Apache + modules configuration
##########################################################################################

CONF7_ORG=/etc/apache2/mods-available/evasive.conf
CONF7_BACK=$BACKUPDIR/$(basename $CONF7_ORG)_$DATE

# Backup and replace email addresses in config files

if [ -a $CONF7_ORG ]
   then
      cp -p $CONF7_ORG $CONF7_BACK && show_grey "Config file $CONF7_ORG backed up to $CONF7_BACK."
      sed -i 's/DOSEmailNotify.*/	DOSEmailNotify	'$INFO_EMAIL_NEW'/ig' $CONF7_ORG >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Replacing mail address in $CONF7_ORG failed. Please check logfile and fix error manually.")
      show_grey "Mail address $INFO_EMAIL_NEW changed in $CONF7_ORG."
   else
      show_info "$CONF7_ORG doesn't exist. Nothing done."
fi

##########################################################################################
# Done
##########################################################################################

show_info "Customization done."
