#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################
DATE=`date +%Y-%m-%d_%H%M`
SUBSCRIPT="docker_install.sh"

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
## Install Docker from the newest source.
##########################################################################################

DOCKER_COMPOSE_VERSION=1.29.2

show_yellow "Installing Docker."

cd /tmp
rm -f get-docker.sh

show_yellow "Removing old Docker installations."
apt-get --yes remove docker docker.io containerd runc
apt-get --yes update

show_yellow "Download new Docker installation script."
curl -fsSL https://get.docker.com -o get-docker.sh >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Download of Docker failed. Please check logfile and fix error manually.")
sh get-docker.sh

show_yellow "Stop Docker service."
service docker stop

##########################################################################################
# General Docker configuration
##########################################################################################

CONF_ORG=/etc/docker/daemon.json
CONF_BACK=$BACKUPDIR/$(basename $CONF_ORG)_$DATE
CONF_GIT=$BASEDIR/configs/docker/daemon.json

##########################################################################################
## Copy Docker configuration
##########################################################################################

if [ -a $CONF_ORG ]
   then
      cp -p $CONF_ORG $CONF_BACK && show_yellow "Docker daemon json file $CONF_ORG backed up to $CONF_BACK."
      cp $CONF_GIT $CONF_ORG && show_yellow "Default Docker daemon json deployed."
   else
      cp $CONF_GIT $CONF_ORG && show_yellow "Default Docker daemon json deployed."
fi

##########################################################################################
## Reconfigure Docker folder
##########################################################################################

sed -i 's/COMPANY/'${COMPANY}'/ig' $CONF_ORG

show_yellow "Start Docker service."
service docker start

#show_yellow "Check and create docker group."
#if grep "docker" /etc/group; then
#    show_yellow "Docker group exists."
#else
#    show_yellow "Create Docker group."
#    newgrp docker
#fi
#
#show_yellow "Add $USER to docker group."
#groupadd docker
#
#usermod -aG docker $USER

show_yellow "Docker installed."

show_yellow "Installing docker-compose."

curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose  >> $LOGDIR/$LOGFILE 2>&1 || ( show_err "Download of docker-compose failed. Please check logfile and fix error manually.")
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

show_yellow "Docker-compose installed."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."