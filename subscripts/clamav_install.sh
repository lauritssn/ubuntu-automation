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
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="clamav_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/srv/apps/logs
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
# General ClamAV configuration
##########################################################################################

SCRIPT_ORG=/usr/local/bin/clamav-scan.sh
SCRIPT_BACK=$BACKUPDIR/$(basename $SCRIPT_ORG)_$DATE
SCRIPT_GIT=$BASEDIR/utils/monitoring/scripts/clamav-scan.sh

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Pre-installation checks for Ubuntu 24.04
##########################################################################################

# Check available disk space (ClamAV databases need ~300MB+)
AVAILABLE_SPACE=$(df /var | awk 'NR==2 {print $4}')
if [ "$AVAILABLE_SPACE" -lt 500000 ]; then
    show_warn "Low disk space detected (less than 500MB available). ClamAV databases require significant space."
fi

# Update package list first
apt-get update >>$LOGDIR/$LOGFILE 2>&1

##########################################################################################
## Install ClamAV
##########################################################################################

if ! apt-get --yes install clamav clamav-daemon clamav-freshclam >>$LOGDIR/$LOGFILE 2>&1; then
    show_err "ClamAV installation failed. Please check logfile and fix error manually."
    exit 1
fi
show_yellow "ClamAV installation successful."

##########################################################################################
## Update ClamAV
##########################################################################################

show_yellow "Updating ClamAV (this may take a while!)."

# Ensure proper permissions for ClamAV directories
mkdir -p /var/log/clamav
mkdir -p /var/lib/clamav
chown clamav:clamav /var/log/clamav
chown clamav:clamav /var/lib/clamav
chmod 755 /var/log/clamav
chmod 755 /var/lib/clamav

# Stop services before updating
systemctl stop clamav-freshclam.service >>$LOGDIR/$LOGFILE 2>&1 || true
systemctl stop clamav-daemon.service >>$LOGDIR/$LOGFILE 2>&1 || true

# Configure freshclam to avoid log conflicts and Ubuntu 24.04 issues
if [ -f /etc/clamav/freshclam.conf ]; then
    # Fix Ubuntu 24.04 startup issue - comment out Example line
    sed -i 's/^Example/#Example/' /etc/clamav/freshclam.conf >>$LOGDIR/$LOGFILE 2>&1 || true

    # Fix log file size and rotation settings
    sed -i 's/^LogFileMaxSize.*/LogFileMaxSize 10M/' /etc/clamav/freshclam.conf >>$LOGDIR/$LOGFILE 2>&1 || true
    sed -i 's/^LogRotate.*/LogRotate true/' /etc/clamav/freshclam.conf >>$LOGDIR/$LOGFILE 2>&1 || true

    # Ensure log file is properly configured
    if ! grep -q "^UpdateLogFile" /etc/clamav/freshclam.conf; then
        echo "UpdateLogFile /var/log/clamav/freshclam.log" >>/etc/clamav/freshclam.conf
    fi

    show_yellow "Fixed freshclam log configuration."
fi

# Configure ClamAV daemon
if [ -f /etc/clamav/clamd.conf ]; then
    # Fix Ubuntu 24.04 startup issue - comment out Example line
    sed -i 's/^Example/#Example/' /etc/clamav/clamd.conf >>$LOGDIR/$LOGFILE 2>&1 || true

    # Ensure main DatabaseDirectory is set correctly
    if ! grep -q "^DatabaseDirectory /var/lib/clamav" /etc/clamav/clamd.conf; then
        sed -i 's/^DatabaseDirectory.*/DatabaseDirectory \/var\/lib\/clamav/' /etc/clamav/clamd.conf >>$LOGDIR/$LOGFILE 2>&1 || true
    fi

    # Fix log configuration
    sed -i 's/^LogFileMaxSize.*/LogFileMaxSize 10M/' /etc/clamav/clamd.conf >>$LOGDIR/$LOGFILE 2>&1 || true
    sed -i 's/^LogRotate.*/LogRotate true/' /etc/clamav/clamd.conf >>$LOGDIR/$LOGFILE 2>&1 || true

    # Optimize performance settings
    sed -i 's/^MaxDirectoryRecursion.*/MaxDirectoryRecursion 25/' /etc/clamav/clamd.conf >>$LOGDIR/$LOGFILE 2>&1 || true
    sed -i 's/^StreamMaxLength.*/StreamMaxLength 100M/' /etc/clamav/clamd.conf >>$LOGDIR/$LOGFILE 2>&1 || true
    sed -i 's/^MaxScanTime.*/MaxScanTime 300000/' /etc/clamav/clamd.conf >>$LOGDIR/$LOGFILE 2>&1 || true
    sed -i 's/^MaxScanSize.*/MaxScanSize 500M/' /etc/clamav/clamd.conf >>$LOGDIR/$LOGFILE 2>&1 || true
    sed -i 's/^MaxFileSize.*/MaxFileSize 100M/' /etc/clamav/clamd.conf >>$LOGDIR/$LOGFILE 2>&1 || true

    show_yellow "Fixed ClamAV daemon configuration."
fi

# Create socket directory
mkdir -p /var/run/clamav
chown clamav:clamav /var/run/clamav
chmod 755 /var/run/clamav

# Update ClamAV databases with manual freshclam to avoid conflicts
show_yellow "Downloading ClamAV virus signature databases..."
if ! freshclam --log=/var/log/clamav/freshclam_install.log >>$LOGDIR/$LOGFILE 2>&1; then
    show_err "ClamAV signature database download failed. Please check logfile and fix error manually."
    exit 1
fi

# Verify that essential ClamAV databases were downloaded (including bytecode)
DATABASES_OK=true

if [ ! -f "/var/lib/clamav/main.cvd" ] && [ ! -f "/var/lib/clamav/main.cld" ]; then
    show_err "ClamAV main signature database not found after download. Installation failed."
    DATABASES_OK=false
fi

if [ ! -f "/var/lib/clamav/daily.cvd" ] && [ ! -f "/var/lib/clamav/daily.cld" ]; then
    show_err "ClamAV daily signature database not found after download. Installation failed."
    DATABASES_OK=false
fi

if [ ! -f "/var/lib/clamav/bytecode.cvd" ] && [ ! -f "/var/lib/clamav/bytecode.cld" ]; then
    show_warn "ClamAV bytecode signature database not found - this may affect detection capabilities."
fi

if [ "$DATABASES_OK" = false ]; then
    show_err "Essential ClamAV signature databases are missing. Installation failed."
    exit 1
fi

show_yellow "ClamAV signature databases downloaded successfully."

# Ensure all files in ClamAV directory are owned by clamav user
chown -R clamav:clamav /var/lib/clamav/ 2>/dev/null || true

# Verify we still have the essential ClamAV signature files
if [ ! -f "/var/lib/clamav/main.cvd" ] && [ ! -f "/var/lib/clamav/main.cld" ]; then
    show_err "Essential ClamAV signature files are missing. Installation incomplete."
    exit 1
fi

show_yellow "ClamAV database directory setup completed successfully."

# Function to wait for service to be active with timeout
wait_for_service() {
    local service=$1
    local timeout=${2:-30}
    local count=0

    while [ $count -lt $timeout ]; do
        if systemctl is-active --quiet "$service"; then
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    return 1
}

# Start services in proper order
systemctl start clamav-freshclam.service >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Starting freshclam service failed. Please check logfile and fix error manually.")

# Wait for freshclam to be ready instead of fixed sleep
if wait_for_service clamav-freshclam 30; then
    show_yellow "ClamAV freshclam service started successfully."
else
    show_warn "ClamAV freshclam service took longer than expected to start."
fi

# Verify ClamAV daemon can start with current database files
show_yellow "Starting ClamAV daemon..."
if ! systemctl start clamav-daemon.service >>$LOGDIR/$LOGFILE 2>&1; then
    show_warn "ClamAV daemon failed to start on first attempt. Attempting additional cleanup..."

    # Capture detailed error information
    echo "=== ClamAV Daemon First Startup Failure ===" >>$LOGDIR/$LOGFILE
    echo "systemctl status clamav-daemon.service:" >>$LOGDIR/$LOGFILE
    systemctl status clamav-daemon.service >>$LOGDIR/$LOGFILE 2>&1 || true

    echo "journalctl -u clamav-daemon.service --no-pager -n 10:" >>$LOGDIR/$LOGFILE
    journalctl -u clamav-daemon.service --no-pager -n 10 >>$LOGDIR/$LOGFILE 2>&1 || true

    # Additional cleanup - ensure clean database state
    show_yellow "Performing additional database cleanup..."

    # Stop daemon to ensure clean state
    systemctl stop clamav-daemon.service >>$LOGDIR/$LOGFILE 2>&1 || true

    # Ensure proper ownership of all files
    chown -R clamav:clamav /var/lib/clamav/

    # Attempt to start again
    show_yellow "Attempting to start ClamAV daemon after cleanup..."
    if ! systemctl start clamav-daemon.service >>$LOGDIR/$LOGFILE 2>&1; then
        show_err "ClamAV daemon failed to start even after cleanup. Capturing diagnostics..."

        echo "=== ClamAV Daemon Second Startup Failure ===" >>$LOGDIR/$LOGFILE
        echo "Contents of /var/lib/clamav/ after cleanup:" >>$LOGDIR/$LOGFILE
        ls -la /var/lib/clamav/ >>$LOGDIR/$LOGFILE 2>&1 || true

        echo "ClamAV configuration check:" >>$LOGDIR/$LOGFILE
        grep -E "^(DatabaseDirectory|LocalSocket|User)" /etc/clamav/clamd.conf >>$LOGDIR/$LOGFILE 2>&1 || true

        echo "Final error logs:" >>$LOGDIR/$LOGFILE
        journalctl -u clamav-daemon.service --no-pager -n 10 >>$LOGDIR/$LOGFILE 2>&1 || true

        show_err "ClamAV daemon failed to start after cleanup. Check 'systemctl status clamav-daemon' and logfile for details."
        exit 1
    fi

    show_yellow "ClamAV daemon started successfully after cleanup."
fi

# Verify daemon is actually running and functional using wait function
if wait_for_service clamav-daemon 30; then
    show_yellow "ClamAV daemon started successfully and is running."
else
    show_err "ClamAV daemon is not running after startup attempt."

    # Additional diagnostics
    echo "=== Post-startup Daemon Status ===" >>$LOGDIR/$LOGFILE
    systemctl status clamav-daemon.service >>$LOGDIR/$LOGFILE 2>&1 || true
    journalctl -u clamav-daemon.service --no-pager -n 10 >>$LOGDIR/$LOGFILE 2>&1 || true

    show_err "Installation failed. Check logfile for detailed diagnostics."
    exit 1
fi

# Enable services to start at boot
systemctl enable clamav-freshclam.service >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Enabling freshclam service failed. Please check logfile and fix error manually.")
systemctl enable clamav-daemon.service >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Enabling clamav-daemon service failed. Please check logfile and fix error manually.")

show_yellow "ClamAV update done and daemon configured."

##########################################################################################
## Deploy optimized ClamAV scan script with false positive reduction
##########################################################################################

show_yellow "Deploying optimized ClamAV scan script with false positive reduction."

# Copy the optimized scan script from our configs
cp $SCRIPT_GIT $SCRIPT_ORG >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Copying ClamAV scan script failed. Please check logfile and fix error manually.")

# Replace email placeholders in the deployed script using safe functions
source "$SCRIPTDIR/../utils/helpers/sed_helpers.sh"

replace_email_placeholder "$SCRIPT_ORG" "INFO_EMAIL@EMAIL_DOMAIN" "$INFO_EMAIL"
replace_email_placeholder "$SCRIPT_ORG" "EMAIL_DOMAIN" "$EMAIL_DOMAIN"
replace_email_placeholder "$SCRIPT_ORG" "clamav@EMAIL_DOMAIN" "clamav@$EMAIL_DOMAIN"

show_yellow "ClamAV scan script deployed with false positive reduction enabled."

##########################################################################################
## Deploy ClamAV exclusion helper script
##########################################################################################

# Copy the exclusion helper script
cp $BASEDIR/utils/helpers/clamav-exclude-helper.sh /usr/local/bin/clamav-exclude-helper.sh >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Copying ClamAV exclusion helper failed. Please check logfile and fix error manually.")
chmod +x /usr/local/bin/clamav-exclude-helper.sh >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Making ClamAV exclusion helper executable failed. Please check logfile and fix error manually.")

show_yellow "ClamAV exclusion helper installed at /usr/local/bin/clamav-exclude-helper.sh"
show_yellow "Run 'clamav-exclude-helper.sh' anytime to optimize exclusions for your software stack."

##########################################################################################
## Note: ClamAV scheduling now handled by systemd timers
##########################################################################################

show_yellow "ClamAV scanning will be configured via systemd timers."

##########################################################################################
## Make the file executable.
##########################################################################################

chmod +x $SCRIPT_ORG >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Making ClamAV scan script $SCRIPT_ORG executable failed. Please check logfile and fix error manually.")
show_yellow "ClamAV scan script $SCRIPT_ORG made executable."

##########################################################################################
## Restart ClamAV
##########################################################################################

# Restart services in proper order to ensure they're running
systemctl daemon-reload >>$LOGDIR/$LOGFILE 2>&1
systemctl restart clamav-freshclam >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Restarting ClamAV freshclam failed. Please check logfile and fix error manually.")

# Wait for freshclam to be ready before starting daemon
if wait_for_service clamav-freshclam 30; then
    show_yellow "ClamAV freshclam restarted successfully."
else
    show_warn "ClamAV freshclam restart took longer than expected."
fi

systemctl restart clamav-daemon >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Restarting ClamAV daemon failed. Please check logfile and fix error manually.")

# Verify services are running with improved checks
if wait_for_service clamav-daemon 30; then
    show_yellow "ClamAV daemon is running successfully."
else
    show_warn "ClamAV daemon may not be running properly. Check 'systemctl status clamav-daemon' for details."
fi

if systemctl is-active --quiet clamav-freshclam; then
    show_yellow "ClamAV freshclam service is running successfully."
else
    show_warn "ClamAV freshclam service may not be running properly. Check 'systemctl status clamav-freshclam' for details."
fi

##########################################################################################
## Integration Notes
##########################################################################################

if command -v maldet >/dev/null 2>&1; then
    show_info "Maldet is detected on this system."
    show_info "ClamAV and Maldet will run as separate, independent scanning processes."
    show_info "Maldet can optionally use the ClamAV engine while maintaining its own signatures."
else
    show_info "Install Maldet for additional independent malware scanning coverage."
fi

##########################################################################################
## DONE
##########################################################################################

show_info "$SUBSCRIPT done."
