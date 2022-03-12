# https://www.hackerxone.com/2021/08/30/step-by-step-to-setup-monitorix-monitoring-tool-on-ubuntu-20-04-lts/
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

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
# Override configuration
##########################################################################################

CONF_ORG=/etc/monitorix/conf.d/00-debian.conf
CONF_BACK=$BACKUPDIR/$(basename $CONF_ORG)_$DATE
CONF_GIT=$BASEDIR/configs/monitorix/00-debian.conf

##########################################################################################
## Install Monitorix
##########################################################################################

apt-get --yes install monitorix >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Monitorix installation failed. Please check logfile and fix error manually.")
show_yellow "Monitorix installed."

# Create password for monitorix
show_yellow "Create Monitorix password."
apt-get --yes install apache2-utils >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Monitorix apache2-utils installation failed. Please check logfile and fix error manually.")
htpasswd -d -c -b /var/lib/monitorix/htpasswd monitorix "$MONITORIX_PASS"  >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Monitorix admin password installation failed. Please check logfile and fix error manually.")
show_yellow "Monitorix password created."

##########################################################################################
## Copy override configuration
##########################################################################################

cp -p $CONF_ORG $CONF_BACK && show_yellow "Config file $CONF_ORG backed up to $CONF_BACK."
cp $CONF_GIT $CONF_ORG && show_yellow "Debian Monitorix config file deployed."

# Replace HOST_NAME
show_yellow "Replace Monitorix config."
sed -i 's/HOST_NAME/'${HOSTNAME}'/ig' $CONF_ORG

show_yellow "Replaced Monitorix config."

show_yellow "Monitorix password installed."
show_yellow "Monitorix user: monitorix"
show_yellow "Monitorix password: $MONITORIX_PASS"

systemctl restart monitorix

##########################################################################################
## Create UFW rule
##########################################################################################

echo "ufw allow proto tcp from $SECURE_SUBNET to any port 8081 # $SECURE_SUBNET_DESC to Monitorix" >> $CRONDIR/ufw.sh || ( show_err "Monitorix UFW rule installation failed. Please check logfile and fix error manually.")
show_yellow "ufw rule to allow access to Monitorix from $SECURE_SUBNET_DESC($SECURE_SUBNET) added."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
