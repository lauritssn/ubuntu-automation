#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################

DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="composer_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log

CONF_LOCAL=/etc/cron.d/vr_composer
CONF_GIT=$BASEDIR/configs/composer/vr_composer

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Install Composer
##########################################################################################

cd /tmp 
rm -rf /tmp/composer.phar >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Composer delete file in tmp failed. Please check logfile and fix error manually.")
curl -sS https://getcomposer.org/installer | php  > $LOGDIR/$LOGFILE 2>&1 || ( show_err "Composer installation failed. Please check logfile and fix error manually.")
rm -rf /usr/local/bin/composer >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Composer delete file in /usr/local/bin failed. Please check logfile and fix error manually.")
mv composer.phar /usr/local/bin/composer >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Composer file move failed. Please check logfile and fix error manually.")
show_grey "Composer installed."

composer selfupdate >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Composer self update failed. Please check logfile and fix error manually.")
show_grey "Composer selfupdated."

##########################################################################################
## Deploy default composer cron file
##########################################################################################

cp $CONF_GIT $CONF_LOCAL >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Deploying default composer cron file failed. Please check logfile and fix error manually.")
show_grey "Default composer cron file deployed to $CONF_LOCAL."

##########################################################################################
## Make the file executable.
##########################################################################################

chmod +x $CONF_LOCAL

##########################################################################################
## Restart Cron
##########################################################################################

service cron restart >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Restarting cron failed. Please check logfile and fix error manually.")
show_grey "Cron restarted."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
