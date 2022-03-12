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
MALDET_PKG="maldetect-current.tar.gz" # maldetect-current.tar.gz


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
show_yellow "Maldet downloaded successfully."
tar xfz $MALDET_PKG >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Extraction of maldet package failed. Please check logfile and fix error manually.")
show_yellow "Maldet package successfully extracted."
rm -f maldetect-current.tar.gz
show_yellow "Maldet tar package successfully removed."
cd maldetect-*
./install.sh >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Installation of maldet failed. Please check logfile and fix error manually.")
show_yellow "Maldet installed successfully."

##########################################################################################
# Backup and deploy default config
##########################################################################################

cp -p $CONF_ORG $CONF_BACK && show_yellow "Config file $CONF_ORG backed up to $CONF_BACK."

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
show_yellow "Maldet configuration successfully customized."

## @TODO
## Include the scanning of known temporary world-writable paths for
 ## -a|--al and -r|--recent scan types.
 #scan_tmpdir_paths="/tmp /var/tmp /dev/shm /var/fcgi_ipc"

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
