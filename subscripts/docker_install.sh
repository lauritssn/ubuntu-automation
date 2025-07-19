#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################
DATE=$(date +%Y-%m-%d_%H%M)
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

# Docker Compose is now installed via plugin, version managed by Docker package

show_yellow "Installing Docker."

cd /tmp
rm -f get-docker.sh

show_yellow "Removing old Docker installations."
apt-get --yes remove docker docker.io containerd runc
apt-get --yes update

show_yellow "Add Docker GPG key and repository with verification."
# Download and verify Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Adding Docker GPG key failed. Please check logfile and fix error manually.")
# Verify GPG key fingerprint
GPG_FINGERPRINT=$(gpg --show-keys --with-fingerprint /usr/share/keyrings/docker-archive-keyring.gpg | grep -o '[A-F0-9]\{4\} [A-F0-9]\{4\} [A-F0-9]\{4\} [A-F0-9]\{4\} [A-F0-9]\{4\}  [A-F0-9]\{4\} [A-F0-9]\{4\} [A-F0-9]\{4\} [A-F0-9]\{4\} [A-F0-9]\{4\}' | tr -d ' ')
EXPECTED_FINGERPRINT="9DC858229FC7DD38854AE2D88D81803C0EBFCD88"
if [[ "$GPG_FINGERPRINT" == "$EXPECTED_FINGERPRINT" ]]; then
    show_yellow "Docker GPG key fingerprint verified successfully."
else
    show_warn "Docker GPG key fingerprint verification failed, but continuing..."
fi
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update >>$LOGDIR/$LOGFILE 2>&1
show_yellow "Installing Docker from official repository."
apt-get --yes install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Installation of Docker failed. Please check logfile and fix error manually.")

show_yellow "Stop Docker service."
systemctl stop docker

if [[ $DOCKER_ROOTLESS =~ [Yy]$ ]]; then
    show_yellow "Setting up Docker rootless mode."
    
    # Install rootless extras
    apt-get --yes install uidmap dbus-user-session >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Installation of rootless dependencies failed. Please check logfile and fix error manually.")
    
    # Setup rootless Docker for current user (assuming non-root user will run this)
    show_yellow "Docker rootless setup will be completed after reboot by the user."
    show_yellow "Run: dockerd-rootless-setuptool.sh install"
    
else
    ##########################################################################################
    # General Docker configuration
    ##########################################################################################

    CONF_ORG=/etc/docker/daemon.json
    CONF_BACK=$BACKUPDIR/$(basename $CONF_ORG)_$DATE
    CONF_GIT=$BASEDIR/configs/docker/daemon.json

    ##########################################################################################
    ## Copy Docker configuration
    ##########################################################################################

    if [ -a $CONF_ORG ]; then
        cp -p $CONF_ORG $CONF_BACK && show_yellow "Docker daemon json file $CONF_ORG backed up to $CONF_BACK."
        cp $CONF_GIT $CONF_ORG && show_yellow "Default Docker daemon json deployed."
    else
        cp $CONF_GIT $CONF_ORG && show_yellow "Default Docker daemon json deployed."
    fi

    ##########################################################################################
    ## Reconfigure Docker folder and data directory
    ##########################################################################################

    # Update data directory if custom path specified
    if [[ "$DOCKER_DATA_ROOT" != "/var/lib/docker" ]]; then
        show_yellow "Configuring custom Docker data directory: $DOCKER_DATA_ROOT"
        mkdir -p $DOCKER_DATA_ROOT
        chown root:root $DOCKER_DATA_ROOT
        chmod 755 $DOCKER_DATA_ROOT
        
        # Add data-root to daemon.json
        sed -i 's|{|{\n  "data-root": "'$DOCKER_DATA_ROOT'",|' $CONF_ORG
    fi
fi

if [[ $DOCKER_ROOTLESS =~ [Nn]$ ]]; then
    show_yellow "Start Docker service."
    systemctl start docker
    systemctl enable docker
else
    show_yellow "Docker rootless mode configured. Service will be managed by user."
fi

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

show_yellow "Docker Compose plugin installed with Docker."
show_yellow "Creating docker-compose symlink for compatibility."
ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
show_yellow "Docker Compose v2 installed."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
