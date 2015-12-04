#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################

DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="mysql_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log
CONF_ORG=/etc/mysql/my.cnf
CONF_BACK=$BACKUPDIR/$(basename $CONF_ORG)_$DATE

##########################################################################################
## write passwords to file
##########################################################################################

echo "mysql_root:${MYSQL_PASS}" >> $CRONDIR/pswd
echo "mysql_backup:${MYSQL_BACKUP_PASS}" >> $CRONDIR/pswd
echo "mysql_monitorix:${MONITORIX_PASS}" >> $CRONDIR/pswd

##########################################################################################
## debconf
##########################################################################################

debconf-set-selections <<< 'mysql-server-5.1 mysql-server/root_password password '$MYSQL_PASS''
debconf-set-selections <<< 'mysql-server-5.1 mysql-server/root_password_again password '$MYSQL_PASS''

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Install MySQL
##########################################################################################

apt-get --yes --force-yes install mysql-server > $LOGDIR/$LOGFILE 2>&1 || ( show_err "MySQL installation failed. Please check logfile and fix error manually.")
show_grey "MySQL installation done."

# Get MySQL location
MYSQL=`which mysql`

##########################################################################################
## Create UFW rule
##########################################################################################

echo "ufw allow proto tcp from $SECURE_SUBNET to any port 3306 # $SECURE_SUBNET_DESC to MySQL" >> $CRONDIR/ufw.sh || ( show_err "MySQL UFW rule installation failed. Please check logfile and fix error manually.")
show_grey "ufw rule to allow acces to mysql from $SECURE_SUBNET_DESC($SECURE_SUBNET) added."

##########################################################################################
## Copy my.cnf
##########################################################################################

cp -p $CONF_ORG $CONF_BACK && show_grey "Config file $CONF_ORG backed up to $CONF_BACK."
cp $BASEDIR/configs/mysql/my.cnf $CONF_ORG && show_grey "Default MySQL config file deployed."

##########################################################################################
## Customize MySQL config
##########################################################################################

#$MYSQL -uroot -e "UPDATE mysql.user SET Password=PASSWORD('"$MYSQL_PASS"') WHERE User='root'; FLUSH PRIVILEGES;" >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Setting MySQL password failed. Please check logfile and fix error manually." )
show_grey "MySQL password set to: `show_info "$MYSQL_PASS"`"

$MYSQL -uroot -p$MYSQL_PASS -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '"$MYSQL_PASS"'; FLUSH PRIVILEGES;" >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Granting MySQL root access failed. Please check logfile and fix error manually." )
show_grey "MySQL root access granted."

#sed -i "s/\(bind-address[\t ]*\)=.*/\1= $IP/" /etc/mysql/my.cnf

##########################################################################################
## Restart MySQL
##########################################################################################

service mysql restart >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "MySQL restart failed. Please check logfile and fix error manually." )
show_grey "MySQL restarted."

##########################################################################################
## create MySQL backup user
##########################################################################################

show_grey "MySQL user backup will be created with password: `show_info "$MYSQL_BACKUP_PASS"`"
Q1="CREATE USER 'backup'@'%' IDENTIFIED BY '"$MYSQL_BACKUP_PASS"';"
Q2="FLUSH PRIVILEGES;"
SQL="${Q1}${Q2}"
    
$MYSQL -uroot -p$MYSQL_PASS -e "$SQL" >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Creating backup MySQL user failed. Please check logfile and fix error manually." )

$MYSQL -uroot -p$MYSQL_PASS -e "GRANT ALL PRIVILEGES ON *.* TO 'backup'@'%' IDENTIFIED BY '"$MYSQL_BACKUP_PASS"'; FLUSH PRIVILEGES;" >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Granting MySQL backup access failed. Please check logfile and fix error manually." )
show_grey "MySQL backup access granted."


##########################################################################################
## If monitorix is installed - create MySQL monitorix user
##########################################################################################

if [[ $DO_MONITORIX_INSTALL =~ [Yy]$ ]]
   then
       show_grey "MySQL user monitorix will be created with password: `show_info "$MONITORIX_PASS"`"
       Q1="CREATE USER 'monitorix'@'localhost' IDENTIFIED BY '"$MONITORIX_PASS"';"
       Q2="FLUSH PRIVILEGES;"
       SQL="${Q1}${Q2}"
    
       $MYSQL -uroot -p$MYSQL_PASS -e "$SQL" >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Creating monitorix MySQL user failed. Please check logfile and fix error manually." )
   else
       show_grey "Monitorix MySQL user will not be created." 
fi


##########################################################################################
## Install Percona Xtrabackup
##########################################################################################

echo "deb http://repo.percona.com/apt trusty main" > /etc/apt/sources.list.d/xtrabackup.list
echo "deb-src http://repo.percona.com/apt trusty main" >> /etc/apt/sources.list.d/xtrabackup.list
show_grey "percona-xtrabackup repository added."
cd /tmp
apt-key adv --keyserver keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Adding repository key for percona-xtrabackup repository failed. Please check logfile and fix error manually.")
show_grey "percona-xtrabackup repository key added."

apt-get update >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "apt-get update failed. Please check logfile and fix error manually.")
show_grey "apt-get update done."
apt-get --yes --force-yes install percona-xtrabackup >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "percona-xtrabackup installation failed. Please check logfile and fix error manually.")
show_grey "percona-xtrabackup installation done."


##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
