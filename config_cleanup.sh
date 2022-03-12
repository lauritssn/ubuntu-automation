#!/bin/bash

printf "##################################\n"
printf "# Config Cleanup #\n"
printf "##################################\n\n"

##########################################################################################
## Set variables
##########################################################################################

DATE=`date +%Y-%m-%d_%H%M`
SCRIPTNAME="config_cleanup.sh"

#LOGDIR=/some/other/path # Set the log directory to a different directory than /tmp

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

BACKUPDIR="/var/deploy/automation-backup"

DO_CONFIG_CLEANUP=N

CONFIG_FILES=( /etc/cron.daily/$COMPANY_clamav /etc/sysctl.conf /etc/fail2ban/jail.conf /etc/fail2ban/action.d/sendmail-common.local /usr/local/maldetect/conf.maldet /etc/monitorix/monitorix.conf /etc/monitorix/conf.d/00-debian.conf /etc/default/rkhunter /etc/rkhunter.conf /etc/fstab /var/cronscripts/ufw.sh )


# Create /var/deploy/automation-backup if it doesn't exist - also creates /var/deploy ($DEPLOYDIR)
if [ ! -d $BACKUPDIR ]
   then
      mkdir -p $BACKUPDIR
fi

##########################################################################################
## Message/logging functions
##########################################################################################

# Grey
show_yellow () {
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
## Main
##########################################################################################

show_info "These are the are the mv commands that will be run:"

for CONFIG_FILE in "${CONFIG_FILES[@]}"
   do
      if [ -f "$CONFIG_FILE"_* ]
         then
            show_yellow "mv $CONFIG_FILE"_*" $BACKUPDIR"
      fi
   done     

read -p "Do You want to perform config cleanup (Y/N)?" -n 1 DO_CONFIG_CLEANUP; echo
if [[ $DO_CONFIG_CLEANUP =~ ^[Yy]$ ]]
   then
      for CONFIG_FILE in "${CONFIG_FILES[@]}"
      do
         if [ -f "$CONFIG_FILE"_* ]
            then
               show_yellow `mv -v "$CONFIG_FILE"_* $BACKUPDIR`
         fi
      done  
   else
     show_err "Exiting."; exit 1
fi


##########################################################################################
## Main
##########################################################################################

show_info "Config cleanup done."
