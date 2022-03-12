#!/bin/bash

printf "############################################\n"
printf "# Ubuntu 20.04 Install Automation #\n"
printf "############################################\n\n"

##########################################################################################
## Set bash options
##########################################################################################
set -e # Exit on error
#set -x # Enable debugging

##########################################################################################
## Define helper functions
##########################################################################################

genpasswd() {
	local l=$1
       	[ "$l" == "" ] && l=16
      	tr -dc A-Za-z0-9_ < /dev/urandom | head -c ${l} | xargs
}

##########################################################################################
## Define variables with default variables
##########################################################################################

export COMPANY=some_name
export BASEDIR=`pwd`
export LOGDIR='/tmp'
export DATE=`date +%Y-%m-%d_%H%M`
export MONITORIX_PASS=`genpasswd`
export ADMINISTRATOR_PASS=`genpasswd`
export CRONJOBS_PASS=`genpasswd`
export CRONDIR="/srv/$COMPANY/cronscripts"
export DEPLOYDIR="/srv/$COMPANY/deploy"
export BACKUPDIR="/srv/$COMPANY/deploy/automation-backup"
export DEBIAN_FRONTEND=noninteractive # Make apt-get install non-interactive

# Create crondir if it doesn't exist
if [ ! -d $CRONDIR ]
   then
      mkdir $CRONDIR
fi

# Create automation-backup dir if it doesn't exist - also creates ($DEPLOYDIR)
if [ ! -d $BACKUPDIR ]
   then
      mkdir -p $BACKUPDIR
fi


# Write to secret file
echo $DATE >> $CRONDIR/pswd

export DO_CHANGE_TIMEZONE=N 
export DO_SYSTEM_UPDATE=N
export DO_SWAPFILE_INSTALL=N
export DO_EXTRAS_INSTALL=N
export DO_GENERAL_SERVER_SETTINGS=N
export DO_MONITORIX_INSTALL=N
export DO_NETDATA_INSTALL=N
export DO_DOCKER_INSTALL=N
export DO_UFW_INSTALL=N
export DO_DIGITAL_OCEAN_INSTALL=N

export UFW_ALLOW_PUBLIC_HTTP=N
export UFW_ALLOW_PUBLIC_HTTPS=N
export UFW_ALLOW_POSTHOG=N
export UFW_ALLOW_NETDATA=N
export UFW_ALLOW_MONITORIX=N

export TIMEZONE="Europe/Copenhagen"

export IP=`ifconfig eth0 | grep "inet addr"| cut -d ":" -f2 | cut -d " " -f1` ## NB Several IP Addresses!!!

export EMAIL_DOMAIN="mydomain.com"
export INFO_EMAIL="my.server.email@${EMAIL_DOMAIN}"

export SECURE_SUBNET="MYIPRANGE/28"
export SECURE_SUBNET_DESC="MY subnet"

# Build UFW_HEADER
UFW_HEADER="#!/bin/bash
# UFW_HEADER START
ufw --force reset
ufw allow proto tcp from $SECURE_SUBNET to any port 22 # $SECURE_SUBNET_DESC to SSH
# UFW_HEADER END
"

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
## Check if cronscripts folder exists and create it if it doesn't
##########################################################################################

if [ ! -d $CRONDIR ]
then
   mkdir -p $CRONDIR
fi

##########################################################################################
## Get input
##########################################################################################

# Change timezone?
read -p "Do You want to change timezone (default: $TIMEZONE) (Y/N)?" -n 1 DO_CHANGE_TIMEZONE; echo

# Change timezone
if [[ $DO_CHANGE_TIMEZONE =~ [Yy]$ ]]
   then
      read -p "Enter timezone (i.e. 'Europe/Copenhagen'): " TIMEZONE
fi

read -p "Do You want to change e-mail domain? (default is $EMAIL_DOMAIN) (Y/N)?" -n 1 SET_EMAIL_DOMAIN; echo
if [[ $SET_EMAIL_DOMAIN =~ [Yy]$ ]]
   then
   read -p "Enter e-mail domain (only domain part of e-mail address): " EMAIL_DOMAIN
fi

read -p "Do You want to change e-mail address? (default is $INFO_EMAIL) (Y/N)?" -n 1 SET_EMAIL_ADDRESS; echo
if [[ $SET_EMAIL_ADDRESS =~ [Yy]$ ]]
   then
   read -p "Enter full e-mail address (xxx@domain.com): " EMAIL_ADDRESS
fi

# System update
read -p "Do You want to update system (Y/N)?" -n 1 DO_SYSTEM_UPDATE; echo

# General server settings install
read -p "Do You want to install general server settings (Y/N)?" -n 1 DO_GENERAL_SERVER_SETTINGS; echo

# Is this a Digital Ocean server install
read -p "Is this server on Digital Ocean (Y/N)?" -n 1 DO_DIGITAL_OCEAN_INSTALL; echo

# Monitorix install
read -p "Do You want to install Monitorix (Y/N)?" -n 1 DO_MONITORIX_INSTALL; echo

# Netdata install
read -p "Do You want to install Netdata (Y/N)?" -n 1 DO_NETDATA_INSTALL; echo

# Docker install
read -p "Do You want to install Docker (Y/N)?" -n 1 DO_DOCKER_INSTALL; echo

# UFW install
read -p "Do You want to install UFW (Y/N)?" -n 1 DO_UFW_INSTALL; echo

# Ask for UFW port openings
if [[ $DO_APACHE_PHP_MC_INSTALL =~ [Yy]$ && $DO_UFW_INSTALL =~ [Yy]$ ]]
   then
      read -p "Do You want to allow port 80 (http) to World (Y/N)?" -n 1 UFW_ALLOW_PUBLIC_HTTP; echo
      read -p "Do You want to allow port 443 (https) to World (Y/N)?" -n 1 UFW_ALLOW_PUBLIC_HTTPS; echo
      read -p "Do You want to allow port 8443 (Posthog) to World (Y/N)?" -n 1 UFW_ALLOW_POSTHOG; echo
      read -p "Do You want to allow port 8081 (Monitorix) to World (Y/N)?" -n 1 UFW_ALLOW_MONITORIX; echo
      read -p "Do You want to allow port 19999 (Netdata) to World (Y/N)?" -n 1 UFW_ALLOW_NETDATA; echo
fi

##########################################################################################
## Prepare ufw.sh
##########################################################################################

if [[ $DO_UFW_INSTALL =~ [Yy]$ ]]
   then
      echo "$UFW_HEADER" > $CRONDIR/ufw.sh
fi

##########################################################################################
## Execute subscripts
##########################################################################################

printf "\n-----------------------------------------------------------\n"
printf "\nWill now execute subscripts based on Your previous choices.\n"

read -p "Do You want to continue (Y/N)?" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
   then
       printf "\n\n--------------------\n"
       show_norm "Executing subscripts"
       printf "\n--------------------\n"
   else
       printf "\n\n------------------\n"
       show_warn "Exiting gracefully" 
       printf "\n------------------\n"
       exit 0
fi

# Start timer
START_TIME=`date +%s`

# Set timezone
if [[ $DO_SET_TIMEZONE =~ [Yy]$ ]]
   then
      cp -p /usr/share/zoneinfo/$TIMEZONE /etc/localtime
      echo "${TIMEZONE}" > /etc/timezone 
      show_grey "Timezone set to $TIMEZONE"
fi

printf "\n--------------------\n"

# System update
if [[ $DO_SYSTEM_UPDATE =~ [Yy]$ ]]
   then
       source $BASEDIR/subscripts/system_update.sh
   else
       show_warn "System update will not be performed"
fi

printf "\n--------------------\n"

# General server settings install
if [[ $DO_GENERAL_SERVER_SETTINGS =~ [Yy]$ ]]
   then
       source $BASEDIR/subscripts/administrator_install.sh
       printf "\n--------------------\n"
       source $BASEDIR/subscripts/general_system_settings.sh
       printf "\n--------------------\n"
       source $BASEDIR/subscripts/secure_shared_memory_install.sh
       printf "\n--------------------\n"
       source $BASEDIR/subscripts/sysctl_install.sh
       printf "\n--------------------\n"
       source $BASEDIR/subscripts/maldet_install.sh
       printf "\n--------------------\n"
       source $BASEDIR/subscripts/rkhunter_install.sh
       printf "\n--------------------\n"
       source $BASEDIR/subscripts/clamav_install.sh
       printf "\n--------------------\n"
       source $BASEDIR/subscripts/fail2ban_install.sh
       printf "\n--------------------\n"
       ## source $BASEDIR/subscripts/sendmail_install.sh # @TODO - Aliases could perhaps be used for e-mail forwarding as I asked about
   else
      show_warn "General server settings will not be installed" 
fi

printf "\n--------------------\n"

# Redis install
if [[ $DO_REDIS_INSTALL =~ [Yy]$ ]]
   then
       source $BASEDIR/subscripts/redis_install.sh
   else
       show_warn "Redis will not be installed" 
fi

# Digital Ocean install
if [[ $DO_DIGITAL_OCEAN_INSTALL =~ [Yy]$ ]]
   then
       source $BASEDIR/subscripts/digitalocean_install.sh
   else
       show_warn "Digital Ocean not selected."
fi

printf "\n--------------------\n"

# Docker install
if [[ $DO_DOCKER_INSTALL =~ [Yy]$ ]]
   then
       source $BASEDIR/subscripts/docker_install.sh
   else
       show_warn "Docker will not be installed"
fi

printf "\n--------------------\n"

# Netdata install
if [[ $DO_NETDATA_INSTALL =~ [Yy]$ ]]
   then
       source $BASEDIR/subscripts/netdata_install.sh
   else
       show_warn "Netdata will not be installed"
fi

printf "\n--------------------\n"

# Monitorix install / MUST BE DONE SECOND LAST DUE TO MONITORING BEING ALTERED ACCORDING TO INSTALLATION
if [[ $DO_MONITORIX_INSTALL =~ [Yy]$ ]]
   then
       source $BASEDIR/subscripts/monitorix_install.sh
   else
       show_warn "Monitorix will not be installed"
fi

printf "\n--------------------\n"

# UFW script install / MUST BE DONE LAST DUE TO UFW BEING ALTERED ACCORDING TO INSTALLATION
if [[ $DO_UFW_INSTALL =~ [Yy]$ ]]
   then
       ufw status numbered >> $BACKUPDIR/ufw

       echo "ufw enable" >> $CRONDIR/ufw.sh
       source $BASEDIR/subscripts/ufw_install.sh
   else
       show_warn "UFW script will not be installed" 
fi

printf "\n--------------------\n"

# Write to pswd and secure file
echo "" >> $CRONDIR/pswd
chmod 0600 $CRONDIR/pswd

# End timer
END_TIME=`date +%s`

# Say bye
show_norm "Installation done (took `expr $END_TIME - $START_TIME` seconds). Have a nice day."
