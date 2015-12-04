#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################

DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="apache_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
# General Apache + modules configuration
##########################################################################################

CONF_ORG_1=/etc/apache2/apache2.conf
CONF_BACK_1=$BACKUPDIR/$(basename $CONF_ORG_1)_$DATE
CONF_GIT_1=$BASEDIR/configs/apache2/apache2.conf

CONF_ORG_2=/etc/apache2/conf-available/security.conf
CONF_BACK_2=$BACKUPDIR/$(basename $CONF_ORG_2)_$DATE
CONF_GIT_2=$BASEDIR/configs/apache2/security.conf

CONF_ORG_3=/etc/apache2/conf-available/rewrite.conf
CONF_BACK_3=$BACKUPDIR/$(basename $CONF_ORG_3)_$DATE
CONF_GIT_3=$BASEDIR/configs/apache2/rewrite.conf

CONF_ORG_4=/etc/apache2/mods-available/evasive.conf
CONF_BACK_4=$BACKUPDIR/$(basename $CONF_ORG_4)_$DATE
CONF_GIT_4=$BASEDIR/configs/apache2/evasive.conf

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Install apache2
##########################################################################################

apt-get --yes --force-yes install apache2 >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Installation of apache2 failed. Please check logfile and fix error manually.")
show_grey "Installation of apache2 done."

##########################################################################################
## Install mod_evasive
##########################################################################################

apt-get --yes --force-yes install libapache2-mod-evasive >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Installation of mod_evasive failed. Please check logfile and fix error manually.")
show_grey "Installation of mod_evasive done."

##########################################################################################
## Enable rewrite, headers and disable indexing 
##########################################################################################

for ENAB_MODULE in rewrite headers rewrite evasive
   do
       a2enmod $ENAB_MODULE >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Enabling $ENAB_MODULE module failed. Please check logfile and fix error manually.")
       show_grey "$ENAB_MODULE module enabled." 
   done

for DISAB_MODULE in autoindex dav dav_fs info include cgi
   do
      a2dismod $DISAB_MODULE >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Disabling $DISAB_MODULE module failed. Please check logfile and fix error manually.")
      show_grey "$DISAB_MODULE module disabled."
   done

##########################################################################################
## Backup and deploy config
##########################################################################################

cp -p $CONF_ORG_1 $CONF_BACK_1 && show_grey "Config file $CONF_ORG_1 backed up to $CONF_BACK_1."
cp $CONF_GIT_1 $CONF_ORG_1 && show_grey "Default apache2.conf file deployed."

cp -p $CONF_ORG_2 $CONF_BACK_2 && show_grey "Config file $CONF_ORG_2 backed up to $CONF_BACK_2."
cp $CONF_GIT_2 $CONF_ORG_2 && show_grey "Default security.conf file deployed."

if [ -a $CONF_ORG_3 ]
   then
      cp -p $CONF_ORG_3 $CONF_BACK_3 && show_grey "Config file $CONF_ORG_3 backed up to $CONF_BACK_3."
      cp $CONF_GIT_3 $CONF_ORG_3 && show_grey "Default rewrite.conf file deployed."
   else
      cp $CONF_GIT_3 $CONF_ORG_3 && show_grey "Default rewrite.conf file deployed."
fi 

cp -p $CONF_ORG_4 $CONF_BACK_4 && show_grey "Config file $CONF_ORG_4 backed up to $CONF_BACK_4."
cp $CONF_GIT_4 $CONF_ORG_4 && show_grey "Default evasive.conf file deployed."


##########################################################################################
## UFW allow access
##########################################################################################

# Port 80 (HTTP)
if [[ UFW_ALLOW_PUBLIC_HTTP =~ [Yy]$ ]]
   then
      echo "ufw allow 80 # World to http" >> $CRONDIR/ufw.sh
      show_grey "ufw rule to allow accesss to http from world added."
   else
      echo "ufw allow proto tcp from $SECURE_SUBNET to any port 80 # $SECURE_SUBNET_DESC to http" >> $CRONDIR/ufw.sh
      show_grey "ufw rule to allow access to http from $SECURE_SUBNET_DESC($SECURE_SUBNET) added."
fi

# Port 443 (HTTPS)
if [[ UFW_ALLOW_PUBLIC_HTTPS =~ [Yy]$ ]]
   then
      echo "ufw allow 443 # World to https" >> $CRONDIR/ufw.sh
      show_grey "ufw rule to allow access to https from world added."
   else
      echo "ufw allow proto tcp from $SECURE_SUBNET to any port 443 # $SECURE_SUBNET_DESC to https" >> $CRONDIR/ufw.sh
      show_grey "ufw rule to allow access to https from $SECURE_SUBNET_DESC($SECURE_SUBNET) added."
fi

##########################################################################################
## Replace INFO_MAIL in evasive.conf
##########################################################################################

sed -i 's/INFO_EMAIL/'${INFO_EMAIL}'/ig' $CONF_ORG_4

##########################################################################################
## Restart apache2
##########################################################################################

service apache2 restart >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Restarting apache2 failed. Please check logfile and fix error manually.")
show_grey "Apache2 restarted."

##########################################################################################
## DONE
##########################################################################################

show_info "$SUBSCRIPT done."
