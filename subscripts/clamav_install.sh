#!/bin/bash

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
SCRIPT_GIT=$BASEDIR/configs/clamav/clamav

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Install ClamAV
##########################################################################################

if ! apt-get --yes install clamav clamav-daemon clamav-freshclam >$LOGDIR/$LOGFILE 2>&1; then
    show_err "ClamAV installation failed. Please check logfile and fix error manually."
    exit 1
fi
show_yellow "ClamAV installation successfull."

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

# Configure freshclam to avoid log conflicts
if [ -f /etc/clamav/freshclam.conf ]; then
    # Fix log file size and rotation settings
    sed -i 's/^LogFileMaxSize.*/LogFileMaxSize 10M/' /etc/clamav/freshclam.conf >>$LOGDIR/$LOGFILE 2>&1 || true
    sed -i 's/^LogRotate.*/LogRotate true/' /etc/clamav/freshclam.conf >>$LOGDIR/$LOGFILE 2>&1 || true
    show_yellow "Fixed freshclam log configuration."
fi

# Configure ClamAV daemon
if [ -f /etc/clamav/clamd.conf ]; then
    # Remove duplicate DatabaseDirectory entries (keep only the main one)
    sed -i '/^DatabaseDirectory \/usr\/local\/maldetect\/sigs/d' /etc/clamav/clamd.conf >>$LOGDIR/$LOGFILE 2>&1 || true

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

    show_yellow "Fixed ClamAV daemon configuration and removed duplicate database directories."
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

# Verify that basic ClamAV databases were downloaded
if [ ! -f "/var/lib/clamav/main.cvd" ] && [ ! -f "/var/lib/clamav/main.cld" ]; then
    show_err "ClamAV main signature database not found after download. Installation failed."
    exit 1
fi

if [ ! -f "/var/lib/clamav/daily.cvd" ] && [ ! -f "/var/lib/clamav/daily.cld" ]; then
    show_err "ClamAV daily signature database not found after download. Installation failed."
    exit 1
fi

show_yellow "ClamAV signature databases downloaded successfully."

# Clean up any problematic Maldet integration before starting daemon
show_yellow "Cleaning up ClamAV database directory..."

# Remove all Maldet signature links during ClamAV installation
# This ensures clean ClamAV startup - Maldet integration will be handled separately
show_yellow "Removing any Maldet signature links to ensure clean ClamAV startup..."
find /var/lib/clamav -name "maldet_*" -type l -delete 2>/dev/null || true

# Also remove any signature files that ended up directly in clamav directory with wrong ownership
# These should come from Maldet via symbolic links only, never be copied directly
find /var/lib/clamav -name "rfxn.*" -user root -delete 2>/dev/null || true
find /var/lib/clamav -name "*.hdb" -user root -delete 2>/dev/null || true
find /var/lib/clamav -name "*.ndb" -user root -delete 2>/dev/null || true

# Remove any Maldet-related files that might cause conflicts
find /var/lib/clamav -name "*maldet*" -not -path "*/main.cvd" -not -path "*/daily.cvd" -not -path "*/bytecode.cvd" -delete 2>/dev/null || true

# Ensure all files in ClamAV directory are owned by clamav user
chown -R clamav:clamav /var/lib/clamav/ 2>/dev/null || true

# Verify we still have the essential ClamAV signature files
if [ ! -f "/var/lib/clamav/main.cvd" ] && [ ! -f "/var/lib/clamav/main.cld" ]; then
    show_err "Essential ClamAV signature files are missing after cleanup. This should not happen."
    exit 1
fi

show_yellow "Database directory cleanup completed successfully."

# Start services in proper order
systemctl start clamav-freshclam.service >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Starting freshclam service failed. Please check logfile and fix error manually.")
sleep 5

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

    # Additional cleanup - remove any remaining problematic links or files
    show_yellow "Performing additional database cleanup..."
    
    # Stop daemon to ensure clean state
    systemctl stop clamav-daemon.service >>$LOGDIR/$LOGFILE 2>&1 || true
    
    # Remove ALL symbolic links in the ClamAV directory (they can be recreated later)
    find /var/lib/clamav -type l -delete 2>/dev/null || true
    
    # Remove any files that are not core ClamAV databases
    find /var/lib/clamav -type f ! -name "*.cvd" ! -name "*.cld" ! -name "freshclam.dat" -delete 2>/dev/null || true
    
    # Ensure proper ownership
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

# Verify daemon is actually running and functional
sleep 3
if ! systemctl is-active --quiet clamav-daemon.service; then
    show_err "ClamAV daemon is not running after startup attempt."

    # Additional diagnostics
    echo "=== Post-startup Daemon Status ===" >>$LOGDIR/$LOGFILE
    systemctl status clamav-daemon.service >>$LOGDIR/$LOGFILE 2>&1 || true
    journalctl -u clamav-daemon.service --no-pager -n 10 >>$LOGDIR/$LOGFILE 2>&1 || true

    show_err "Installation failed. Check logfile for detailed diagnostics."
    exit 1
fi

show_yellow "ClamAV daemon started successfully and is running."

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

# Replace email placeholders in the deployed script
sed -i 's/INFO_EMAIL@EMAIL_DOMAIN/'${INFO_EMAIL}'/g' $SCRIPT_ORG
sed -i 's/EMAIL_DOMAIN/'${EMAIL_DOMAIN}'/g' $SCRIPT_ORG
sed -i 's/clamav@EMAIL_DOMAIN/clamav@'${EMAIL_DOMAIN}'/g' $SCRIPT_ORG

show_yellow "ClamAV scan script deployed with false positive reduction enabled."

##########################################################################################
## Deploy ClamAV exclusion helper script
##########################################################################################

# Copy the exclusion helper script
cp $BASEDIR/configs/clamav/clamav-exclude-helper.sh /usr/local/bin/clamav-exclude-helper.sh >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Copying ClamAV exclusion helper failed. Please check logfile and fix error manually.")
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
sleep 3
systemctl restart clamav-daemon >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Restarting ClamAV daemon failed. Please check logfile and fix error manually.")

# Verify services are running
if systemctl is-active --quiet clamav-daemon; then
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
    if [ -x "/usr/local/bin/update-maldet-clamav-links.sh" ]; then
        show_info "To integrate Maldet signatures with ClamAV, run:"
        show_info "  sudo /usr/local/bin/update-maldet-clamav-links.sh update"
    else
        show_info "Install systemd timers to enable proper Maldet-ClamAV integration."
    fi
else
    show_info "Install Maldet for additional signature coverage."
fi

##########################################################################################
## DONE
##########################################################################################

show_info "$SUBSCRIPT done."
