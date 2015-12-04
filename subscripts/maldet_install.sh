#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################
DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="maldet_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log
MALDET_PKG="maldetect-1.4.2.tar.gz" # maldetect-current.tar.gz


##########################################################################################
# General maldet configuration
##########################################################################################

CONF_ORG=/usr/local/maldetect/conf.maldet 
CONF_BACK=$BACKUPDIR/$(basename $CONF_ORG)_$DATE

##########################################################################################
## Info
##########################################################################################
show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
#Install Maldet from the newest source.
##########################################################################################

cd /tmp  
wget http://www.rfxn.com/downloads/$MALDET_PKG >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Download of maldet failed. Please check logfile and fix error manually.")
show_grey "Maldet downloaded successfully."
tar xfz $MALDET_PKG >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Extraction of maldet package failed. Please check logfile and fix error manually.")
show_grey "Maldet package successfully extracted."
cd maldetect-*
./install.sh >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Installation of maldet failed. Please check logfile and fix error manually.")
show_grey "Maldet installed successfully."

##########################################################################################
# Backup and deploy default config
##########################################################################################

cp -p $CONF_ORG $CONF_BACK && show_grey "Config file $CONF_ORG backed up to $CONF_BACK."

##########################################################################################
# Change Maldet configuration
##########################################################################################

sed -i 's/email_alert=.*/email_alert=1/ig' $CONF_ORG
sed -i 's/email_addr=.*/email_addr=\"'${INFO_EMAIL}'\"/ig' $CONF_ORG
sed -i 's/email_alert=.*/email_alert=1/ig' $CONF_ORG
sed -i 's/quar_hits=.*/quar_hits=1/ig' $CONF_ORG
sed -i 's/quar_clean=.*/quar_clean=1/ig' $CONF_ORG
sed -i 's/quar_susp=.*/quar_susp=0/ig' $CONF_ORG
sed -i 's/quar_susp_minuid=.*/quar_susp_minuid=500/ig' $CONF_ORG
show_grey "Maldet configuration successfully customized."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
