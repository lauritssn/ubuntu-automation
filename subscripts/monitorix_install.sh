#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################
DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="monitorix_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log
MONITORIX_PKG="monitorix_3.7.0-izzy1_all.deb"

##########################################################################################
# General monitorix configuration
##########################################################################################

CONF_ORG_1=/etc/monitorix/monitorix.conf 
CONF_BACK_1=$BACKUPDIR/$(basename $CONF_ORG_1)_$DATE
CONF_GIT_1=$BASEDIR/configs/monitorix/monitorix.conf

##########################################################################################
# Special Ubuntu / Debian MySQL configuration
##########################################################################################

CONF_ORG_2=/etc/monitorix/conf.d/00-debian.conf 
CONF_BACK_2=$BACKUPDIR/$(basename $CONF_ORG_2)_$DATE
CONF_GIT_2=$BASEDIR/configs/monitorix/00-debian.conf

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Install Monitorix
##########################################################################################

apt-get --yes --force-yes install rrdtool perl libwww-perl libmailtools-perl libmime-lite-perl librrds-perl libhttp-server-simple-perl libxml-simple-perl libconfig-general-perl > $LOGDIR/$LOGFILE 2>&1 || ( show_err "Monitorix pre-dependencies installation failed. Please check logfile and fix error manually.")
show_grey "apt-get install of dependencies done."

cd /tmp
wget http://www.monitorix.org/$MONITORIX_PKG >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Monitorix download failed. Please check logfile and fix error manually.")
show_grey "Monitorix package ($MONITORIX_PKG) downloaded"
dpkg -i --force-depends /tmp/$MONITORIX_PKG >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Monitorix installation failed. Please check logfile and fix error manually.")
apt-get --yes --force-yes -f install >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Monitorix post-dependencies installation failed. Please check logfile and fix error manually.")
show_grey "Monitorix installed."
rm /tmp/$MONITORIX_PKG

##########################################################################################
## Create UFW rule
##########################################################################################

echo "ufw allow proto tcp from $SECURE_SUBNET to any port 8080 # $SECURE_SUBNET_DESC to Monitorix" >> $CRONDIR/ufw.sh || ( show_err "Monitorix UFW rule installation failed. Please check logfile and fix error manually.")
show_grey "ufw rule to allow acces to Monitorix from $SECURE_SUBNET_DESC($SECURE_SUBNET) added."

##########################################################################################
## Copy monitorix configuration
##########################################################################################

cp -p $CONF_ORG_1 $CONF_BACK_1 && show_grey "Config file $CONF_ORG_1 backed up to $CONF_BACK_1."
cp $CONF_GIT_1 $CONF_ORG_1 && show_grey "Default Monitorix config file deployed."

###################  @TODO - DO SED HERE FOR CONFIGURATION (MySQL, PostGRESQL, ETC)
sed -i 's/HOST_NAME/'${HOSTNAME}'/ig' $CONF_ORG_1

##########################################################################################
## Copy special Ubuntu / Debian MySQL configuration
##########################################################################################

cp -p $CONF_ORG_2 $CONF_BACK_2 && show_grey "Config file $CONF_ORG_2 backed up to $CONF_BACK_2."
cp $CONF_GIT_2 $CONF_ORG_2 && show_grey "Debian Monitorix config file deployed."

##########################################################################################
## Replace MONITORIX_PASS (MySQL password) in config file
##########################################################################################

sed -i 's/MONITORIX_PASS/'${MONITORIX_PASS}'/ig' $CONF_ORG_2

##########################################################################################
## Restart Monitorix
##########################################################################################

service monitorix restart >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Monitorix restart failed. Please check logfile and fix error manually.")
show_grey "Monitorix restarted."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
