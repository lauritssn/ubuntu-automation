#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################

DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="php_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log

CONF_ORG_1=/etc/php5/apache2/php.ini
CONF_BACK_1=$BACKUPDIR/$(basename $CONF_ORG_1)_$DATE
CONF_GIT_1=$BASEDIR/configs/php5/apache2/php.ini

CONF_ORG_2=/etc/php5/cli/php.ini
CONF_BACK_2=$BACKUPDIR/$(basename $CONF_ORG_2)_$DATE
CONF_GIT_2=$BASEDIR/configs/php5/cli/php.ini

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Install PHP
##########################################################################################

sudo apt-get --yes --force-yes install libapache2-mod-php5 php5-pgsql php5-sqlite php5-mysql php5-intl php5-curl php5-gd php5-geoip php5-mcrypt php5-memcache php5-memcached php5-xsl php5-redis php-pear php5-mcrypt mcrypt > $LOGDIR/$LOGFILE 2>&1 || ( show_error "Installation of PHP failed. Please check logfile and fix error manually.")
show_grey "Installation of PHP done."

##########################################################################################
# Backup and deploy default config
##########################################################################################

cp -p $CONF_ORG_1 $CONF_BACK_1 && show_grey "Config file $CONF_ORG backed up to $CONF_BACK."
cp $CONF_GIT_1 $CONF_ORG_1 && show_grey "Default PHP(apache2) config file deployed."

cp -p $CONF_ORG_2 $CONF_BACK_2 && show_grey "Config file $CONF_ORG backed up to $CONF_BACK."
cp $CONF_GIT_2 $CONF_ORG_2 && show_grey "Default PHP (cli) config file deployed."

##########################################################################################
# Customize php config
##########################################################################################

# Change memory_limit according to main script (php.ini)
sed -i 's/memory_limit = .*/memory_limit = '${PHP_MEMORY_LIMIT}'/ig' $CONF_ORG_1
sed -i 's/memory_limit = .*/memory_limit = '${PHP_MEMORY_LIMIT}'/ig' $CONF_ORG_2

# Change upload_max_filesize according to main script (php.ini)
sed -i 's/upload_max_filesize = .*/upload_max_filesize = '${PHP_UPLOAD_MAX_FILESIZE}'/ig' $CONF_ORG_1
sed -i 's/upload_max_filesize = .*/upload_max_filesize = '${PHP_UPLOAD_MAX_FILESIZE}'/ig' $CONF_ORG_2

# Change timezone according to main script (php.ini)
sed -i 's|date.timezone = .*|date.timezone = '${TIMEZONE}'|ig' $CONF_ORG_1
sed -i 's|date.timezone = .*|date.timezone = '${TIMEZONE}'|ig' $CONF_ORG_2

# Enable OPCode cache
php5enmod opcache > $LOGDIR/$LOGFILE 2>&1 || ( show_error "Installation of PHP OPCode cache failed. Please check logfile and fix error manually.")
show_grey "Installation of PHP OPCode cache done."

##########################################################################################
# DONE
##########################################################################################

show_info "$SUBSCRIPT done."
