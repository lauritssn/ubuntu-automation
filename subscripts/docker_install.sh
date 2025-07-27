#!/bin/bash

##########################################################################################
## Ubuntu Configuration Files Modified by this Script
##########################################################################################
# This script modifies the following Ubuntu system configuration files and directories:
#
# CREATED/MODIFIED FILES:
# - /etc/apt/keyrings/docker.asc          - Docker GPG key for package verification
# - /etc/apt/sources.list.d/docker.list   - Docker official repository configuration
# - /etc/docker/daemon.json               - Docker daemon configuration (copied from configs/docker/daemon.json)
# - /usr/local/bin/docker-compose         - Symlink to Docker Compose v2 plugin for compatibility
#
# CREATED DIRECTORIES:
# - /etc/apt/keyrings/                     - Directory for APT repository signing keys (if not exists)
# - /etc/docker/                           - Docker configuration directory (if not exists)
# - $DOCKER_DATA_ROOT                      - Custom Docker data directory (if specified, default: /var/lib/docker)
#
# BACKUP FILES CREATED:
# - $BACKUPDIR/daemon.json_$DATE           - Backup of original /etc/docker/daemon.json (if exists)
#
# MODIFIED FILES (in-place):
# - /etc/docker/daemon.json               - Modified to add custom data-root path (if DOCKER_DATA_ROOT specified)
#
# PERMISSIONS SET:
# - /etc/apt/keyrings/                     - 755 (created with install command)
# - /etc/apt/keyrings/docker.asc          - a+r (world readable)
# - $DOCKER_DATA_ROOT                      - 755, root:root ownership (if custom path specified)
##########################################################################################

##########################################################################################
## Set variables
##########################################################################################
DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="docker_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/srv/apps/logs
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
## Info
##########################################################################################
show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

# Source the sed helpers for safe operations
if [ -f "$BASEDIR/utils/helpers/sed_helpers.sh" ]; then
    source "$BASEDIR/utils/helpers/sed_helpers.sh"
elif [ -f "$(dirname "$0")/../utils/helpers/sed_helpers.sh" ]; then
    source "$(dirname "$0")/../utils/helpers/sed_helpers.sh"
else
    show_warn "sed_helpers.sh not found - using legacy sed operations"
fi

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

show_yellow "Installing required packages for Docker repository setup."
apt-get --yes install ca-certificates curl gnupg >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Installation of required packages failed. Please check logfile and fix error manually.")

show_yellow "Creating keyrings directory."
install -m 0755 -d /etc/apt/keyrings

show_yellow "Add Docker GPG key and repository with verification."
# Download and verify Docker GPG key using new method
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Adding Docker GPG key failed. Please check logfile and fix error manually.")
chmod a+r /etc/apt/keyrings/docker.asc

# Verify GPG key fingerprint (updated method)
show_yellow "Verifying Docker GPG key fingerprint."
GPG_FINGERPRINT=$(gpg --show-keys --with-fingerprint /etc/apt/keyrings/docker.asc 2>/dev/null | grep -E "Key fingerprint" | sed 's/.*= //' | tr -d ' ')
if [ -n "$GPG_FINGERPRINT" ]; then
    show_yellow "Docker GPG key fingerprint found: $GPG_FINGERPRINT"
    show_yellow "Please verify this matches Docker's official fingerprint."
else
    show_warn "Could not extract GPG key fingerprint, but continuing..."
fi

# Add repository using new format for Ubuntu 24.04
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

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
        # Use safe function for JSON configuration to handle paths with special characters
        if command -v safe_json_insert >/dev/null 2>&1; then
            safe_json_insert "$CONF_ORG" "data-root" "$DOCKER_DATA_ROOT" "docker_backup"
        else
            # Fallback to safer sed with alternate separator and proper escaping
            sed -i "s|{|{\n  \"data-root\": \"${DOCKER_DATA_ROOT}\",|" "$CONF_ORG"
        fi
    fi
fi

if [[ $DOCKER_ROOTLESS =~ [Nn]$ ]]; then
    show_yellow "Start Docker service."
    systemctl start docker
    systemctl enable docker
else
    show_yellow "Docker rootless mode configured. Service will be managed by user."
fi

show_yellow "Docker installed."

show_yellow "Docker Compose plugin installed with Docker."
show_yellow "Creating docker-compose symlink for compatibility."
ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
show_yellow "Docker Compose v2 installed."

##########################################################################################
## Docker detection helper function
##########################################################################################

check_docker_installed() {
    if command -v docker >/dev/null 2>&1 || systemctl list-unit-files | grep -q docker.service; then
        return 0 # Docker is installed
    else
        return 1 # Docker is not installed
    fi
}

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
