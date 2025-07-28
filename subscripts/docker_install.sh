#!/bin/bash

##########################################################################################
## Source shared helper functions
##########################################################################################

# Set BASEDIR early for shared functions to use
export BASEDIR="${BASEDIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source the shared helper functions
if [ -f "$BASEDIR/utils/shared_functions.sh" ]; then
    source "$BASEDIR/utils/shared_functions.sh"
else
    echo "❌ ERROR: Shared functions script not found at $BASEDIR/utils/shared_functions.sh"
    echo "Please run this script from the ubuntu-automation directory or set BASEDIR environment variable"
    exit 1
fi

# Fallback function definitions if shared functions aren't available
if ! command -v show_info &>/dev/null; then
    show_info() { echo "INFO: $1"; }
    show_warn() { echo "WARN: $1"; }
    show_err() {
        echo "ERROR: $1"
        exit 1
    }
    show_yellow() { echo "STATUS: $1"; }
fi

##########################################################################################
## Docker Installation and Configuration
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
GPG_FINGERPRINT=$(gpg --show-keys --with-fingerprint /etc/apt/keyrings/docker.asc 2>/dev/null | grep -E "Key fingerprint" | sed 's/.*= //' | tr -d ' ' || true)
if [ -n "$GPG_FINGERPRINT" ]; then
    show_yellow "Docker GPG key fingerprint found: $GPG_FINGERPRINT"
    show_yellow "Please verify this matches Docker's official fingerprint."
else
    show_yellow "GPG key fingerprint verification skipped, proceeding with installation..."
fi

# Add repository using new format for Ubuntu 24.04
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

apt-get update >>$LOGDIR/$LOGFILE 2>&1

show_yellow "Installing Docker from official repository."
apt-get --yes install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Installation of Docker failed. Please check logfile and fix error manually.")

show_yellow "Stop Docker service."
systemctl stop docker

# Debug: Show Docker configuration variables
show_yellow "Docker configuration: DOCKER_ROOTLESS=$DOCKER_ROOTLESS, DOCKER_DATA_ROOT=$DOCKER_DATA_ROOT"

if [[ $DOCKER_ROOTLESS =~ [Yy]$ ]]; then
    show_yellow "Setting up Docker rootless mode."

    # Install rootless extras
    apt-get --yes install uidmap dbus-user-session >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Installation of rootless dependencies failed. Please check logfile and fix error manually.")

    # Disable system Docker daemon for rootless mode
    systemctl disable docker.service docker.socket
    systemctl stop docker.service docker.socket

    # For rootless mode, default to creating a dedicated user unless explicitly disabled
    if [[ "${DOCKER_DEDICATED_USER:-Y}" =~ [Yy]$ ]]; then
        # Use "dockerrootless" as the default user name for rootless installations
        DOCKER_USER_NAME="${DOCKER_USER_NAME:-dockerrootless}"
        show_yellow "Creating dedicated Docker user: $DOCKER_USER_NAME"

        # Create dedicated user for Docker
        if ! id "$DOCKER_USER_NAME" &>/dev/null; then
            useradd -m -s /bin/bash "$DOCKER_USER_NAME"
            show_yellow "Created user: $DOCKER_USER_NAME"
        else
            show_yellow "User $DOCKER_USER_NAME already exists"
        fi

        DOCKER_USER="$DOCKER_USER_NAME"
    elif [ -n "$SUDO_USER" ]; then
        DOCKER_USER="$SUDO_USER"
        show_yellow "Using existing user for Docker: $DOCKER_USER"
    else
        show_yellow "No user specified for Docker rootless setup."
        show_yellow "Set DOCKER_DEDICATED_USER=Y to create a dedicated user, or run as non-root user."
    fi

    # Setup rootless Docker for the determined user
    if [ -n "$DOCKER_USER" ]; then
        show_yellow "Setting up Docker rootless for user: $DOCKER_USER"

        # Ensure user has proper shell and home directory
        usermod -s /bin/bash "$DOCKER_USER" 2>/dev/null || true

        # Run setup as the actual user, not root
        sudo -u "$DOCKER_USER" dockerd-rootless-setuptool.sh install >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Rootless setup failed - user may need to run manually"

        # Add PATH and Docker configuration for the user
        sudo -u "$DOCKER_USER" bash -c 'echo "export PATH=\$PATH:/usr/bin" >> ~/.bashrc'
        sudo -u "$DOCKER_USER" bash -c 'echo "export DOCKER_HOST=unix://\$XDG_RUNTIME_DIR/docker.sock" >> ~/.bashrc'

        # Enable user lingering for systemd user services
        loginctl enable-linger "$DOCKER_USER" 2>/dev/null || show_warn "Could not enable lingering for $DOCKER_USER"

        show_yellow "Docker rootless setup completed for $DOCKER_USER."
        show_yellow "To test Docker, switch to user $DOCKER_USER and run: docker run hello-world"

        if [[ "${DOCKER_DEDICATED_USER:-Y}" =~ [Yy]$ ]]; then
            show_yellow "Switch to Docker user with: sudo su - $DOCKER_USER"
        else
            show_yellow "User $DOCKER_USER should log out and back in for changes to take effect."
        fi
    else
        show_yellow "Docker rootless setup will be completed manually by the user."
        show_yellow "Run as your user (not root): dockerd-rootless-setuptool.sh install"
        show_yellow "Then add to ~/.bashrc:"
        show_yellow "  export PATH=\$PATH:/usr/bin"
        show_yellow "  export DOCKER_HOST=unix://\$XDG_RUNTIME_DIR/docker.sock"
    fi

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
    if [[ -n "$DOCKER_DATA_ROOT" && "$DOCKER_DATA_ROOT" != "/var/lib/docker" ]]; then
        show_yellow "Configuring custom Docker data directory: $DOCKER_DATA_ROOT"
        mkdir -p "$DOCKER_DATA_ROOT"
        chown root:root "$DOCKER_DATA_ROOT"
        chmod 755 "$DOCKER_DATA_ROOT"

        # Add data-root to daemon.json using proper JSON handling
        if command -v safe_json_insert >/dev/null 2>&1; then
            safe_json_insert "$CONF_ORG" "data-root" "$DOCKER_DATA_ROOT" "docker_backup"
        else
            # Fallback: Use jq if available for proper JSON handling
            if command -v jq >/dev/null 2>&1; then
                jq --arg dataroot "$DOCKER_DATA_ROOT" '. + {"data-root": $dataroot}' "$CONF_ORG" >"${CONF_ORG}.tmp" && mv "${CONF_ORG}.tmp" "$CONF_ORG"
            else
                # Last resort: safer sed with proper JSON structure
                sed -i '1s/{/{\n  "data-root": "'"$DOCKER_DATA_ROOT"'",/' "$CONF_ORG"
            fi
        fi
    else
        # Remove any empty data-root entries if using default path
        if command -v jq >/dev/null 2>&1; then
            jq 'del(.["data-root"]) | del(."data-root")' "$CONF_ORG" >"${CONF_ORG}.tmp" && mv "${CONF_ORG}.tmp" "$CONF_ORG"
        else
            # Remove empty data-root lines with sed
            sed -i '/^[[:space:]]*"data-root":[[:space:]]*"[[:space:]]*"[,]*$/d' "$CONF_ORG"
        fi
    fi

    ##########################################################################################
    ## Add current user to docker group for permission management
    ##########################################################################################

    # Add the user who will use Docker to the docker group
    if [ -n "$SUDO_USER" ]; then
        show_yellow "Adding user $SUDO_USER to docker group."
        usermod -aG docker "$SUDO_USER"
    elif [ -n "$USER" ] && [ "$USER" != "root" ]; then
        show_yellow "Adding user $USER to docker group."
        usermod -aG docker "$USER"
    else
        show_warn "No non-root user detected. Docker group membership will need to be set manually."
        show_warn "Run: sudo usermod -aG docker <username>"
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
## Update RKHunter configuration if installed
##########################################################################################

if command -v rkhunter >/dev/null 2>&1 && [ -f /etc/rkhunter.conf ]; then
    show_yellow "RKHunter detected. Updating configuration to whitelist Docker."

    # Check if the commented docker entry exists
    if grep -q "^#SCRIPTWHITELIST=/usr/bin/docker" /etc/rkhunter.conf; then
        # Uncomment the docker SCRIPTWHITELIST entry
        sed -i 's/^#SCRIPTWHITELIST=\/usr\/bin\/docker.*$/SCRIPTWHITELIST=\/usr\/bin\/docker/' /etc/rkhunter.conf
        show_yellow "Docker added to RKHunter SCRIPTWHITELIST."

        # Update RKHunter file properties to include the new docker binary
        show_yellow "Updating RKHunter file properties for Docker."
        rkhunter --propupd --cronjob >/dev/null 2>&1 || show_warn "RKHunter property update failed - this may cause warnings during scans."
    elif ! grep -q "^SCRIPTWHITELIST=/usr/bin/docker" /etc/rkhunter.conf; then
        # Add docker to SCRIPTWHITELIST if not present
        echo "SCRIPTWHITELIST=/usr/bin/docker" >>/etc/rkhunter.conf
        show_yellow "Docker added to RKHunter SCRIPTWHITELIST."

        # Update RKHunter file properties
        show_yellow "Updating RKHunter file properties for Docker."
        rkhunter --propupd --cronjob >/dev/null 2>&1 || show_warn "RKHunter property update failed - this may cause warnings during scans."
    else
        show_yellow "Docker already whitelisted in RKHunter configuration."
    fi
else
    show_yellow "RKHunter not detected. Skipping RKHunter configuration update."
fi

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
