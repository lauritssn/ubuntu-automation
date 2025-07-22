#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################
DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="maldet_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/srv/apps/logs
fi

LOGFILE=$SUBSCRIPT-$DATE.log
MALDET_PKG="maldetect-current.tar.gz" # maldetect-current.tar.gz

##########################################################################################
# General maldet configuration
##########################################################################################

CONF_ORG=/usr/local/maldetect/conf.maldet
CONF_BACK=$BACKUPDIR/$(basename $CONF_ORG)_$DATE

##########################################################################################
## Info
##########################################################################################
show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Install Maldet from the newest source.
##########################################################################################

cd /tmp
apt-get --yes install inotify-tools >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Installation of inotify-tools failed. Please check logfile and fix error manually.")
wget https://www.rfxn.com/downloads/$MALDET_PKG >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Download of maldet failed. Please check logfile and fix error manually.")
show_yellow "Maldet downloaded successfully."
tar xfz $MALDET_PKG >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Extraction of maldet package failed. Please check logfile and fix error manually.")
show_yellow "Maldet package successfully extracted."
rm -f maldetect-current.tar.gz
show_yellow "Maldet tar package successfully removed."
cd maldetect-*
./install.sh >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Installation of maldet failed. Please check logfile and fix error manually.")
show_yellow "Maldet installed successfully."

# Clean up extracted maldet directory after installation
cd /tmp
rm -rf maldetect-* >>$LOGDIR/$LOGFILE 2>&1
show_yellow "Maldet installation directory cleaned up from /tmp."

##########################################################################################
# Backup and deploy default config
##########################################################################################

cp -p $CONF_ORG $CONF_BACK && show_yellow "Config file $CONF_ORG backed up to $CONF_BACK."

##########################################################################################
# Configure Maldet to optionally use ClamAV engine
##########################################################################################

sed -i 's/email_alert=.*/email_alert=1/ig' $CONF_ORG
sed -i 's/email_addr=.*/email_addr=\"'${INFO_EMAIL}'\"/ig' $CONF_ORG
sed -i 's/email_alert=.*/email_alert=1/ig' $CONF_ORG
sed -i 's/quar_hits=.*/quar_hits=1/ig' $CONF_ORG
sed -i 's/quar_clean=.*/quar_clean=1/ig' $CONF_ORG
sed -i 's/quar_susp=.*/quar_susp=0/ig' $CONF_ORG
sed -i 's/quar_susp_minuid=.*/quar_susp_minuid=500/ig' $CONF_ORG

# Configure Maldet to optionally use ClamAV engine while keeping Maldet's own scanner active
sed -i 's/scan_clamscan=.*/scan_clamscan=1/ig' $CONF_ORG
sed -i 's/scan_clamscan_engine=.*/scan_clamscan_engine=1/ig' $CONF_ORG

# Use ClamAV daemon for efficiency but keep Maldet's internal scanner as backup
sed -i 's/scan_clamscan_daemon=.*/scan_clamscan_daemon=1/ig' $CONF_ORG

# Keep Maldet's internal scanner enabled for comprehensive coverage
sed -i 's/scan_hex_only=.*/scan_hex_only=1/ig' $CONF_ORG
sed -i 's/scan_hexdepth=.*/scan_hexdepth=3/ig' $CONF_ORG

# Ensure automatic updates are enabled for Maldet signatures
sed -i 's/autoupdate_signatures=.*/autoupdate_signatures=1/ig' $CONF_ORG
sed -i 's/autoupdate_version=.*/autoupdate_version=1/ig' $CONF_ORG

show_yellow "Maldet configured to optionally use ClamAV engine while maintaining independent scanning capability."

##########################################################################################
# Download Maldet signatures with robust error handling
##########################################################################################

show_yellow "Downloading Maldet signature databases..."

MALDET_SIG_DIR="/usr/local/maldetect/sigs"

# Ensure signature directory exists
if [ ! -d "$MALDET_SIG_DIR" ]; then
    show_yellow "Creating Maldet signature directory..."
    mkdir -p "$MALDET_SIG_DIR"
fi

# Try to download signatures with multiple attempts and better error handling
SIGNATURE_DOWNLOAD_SUCCESS=false

if command -v maldet >/dev/null 2>&1; then
    show_yellow "Attempting to download Maldet signatures (this may take several minutes)..."

    # Update Maldet version first
    show_yellow "Updating Maldet version database..."
    if maldet --update-ver >>$LOGDIR/$LOGFILE 2>&1; then
        show_yellow "Maldet version update completed successfully."
    else
        show_warn "Maldet version update failed, but continuing with signature download..."
    fi

    # Try signature download with retries
    for attempt in 1 2 3; do
        show_yellow "Signature download attempt $attempt of 3..."

        if timeout 600 maldet --update-sigs >>$LOGDIR/$LOGFILE 2>&1; then
            show_yellow "Maldet signature download completed successfully on attempt $attempt."
            SIGNATURE_DOWNLOAD_SUCCESS=true
            break
        else
            show_warn "Maldet signature download attempt $attempt failed."
            if [ $attempt -lt 3 ]; then
                show_yellow "Waiting 30 seconds before retry..."
                sleep 30
            fi
        fi
    done

    if [ "$SIGNATURE_DOWNLOAD_SUCCESS" = false ]; then
        show_warn "All Maldet signature download attempts failed."
        show_warn "This is common due to network issues or server unavailability."
        show_warn "Maldet will work without additional signatures, and signatures can be updated later."
    fi
else
    show_warn "Maldet command not found - signature download skipped"
fi

# Verify what signature files we actually have
SIG_COUNT=$(find "$MALDET_SIG_DIR" -name "*.hdb" -o -name "*.ndb" -o -name "*.ldb" 2>/dev/null | wc -l)
show_yellow "Found $SIG_COUNT signature files in $MALDET_SIG_DIR"

if [ "$SIG_COUNT" -eq 0 ]; then
    show_warn "No Maldet signature files found after download attempts."
    show_warn "Creating minimal signature file to avoid ClamAV integration issues..."

    # Create a minimal placeholder signature file to prevent integration failures
    touch "$MALDET_SIG_DIR/custom.hex.dat"
    echo "# Minimal placeholder signature file created during installation" >"$MALDET_SIG_DIR/README.txt"
    echo "# Run 'maldet --update-sigs' to download actual signatures" >>"$MALDET_SIG_DIR/README.txt"

    show_yellow "Created placeholder files. Signatures can be downloaded later with: maldet --update-sigs"
else
    show_yellow "Maldet signature download completed. Found $SIG_COUNT signature files."
fi

show_yellow "Maldet configuration completed. Maldet will run independently with optional ClamAV engine support."

# Configure scan paths for temporary directories to reduce false positives
# Enable scanning of temporary paths but with reduced sensitivity for false positives
# This helps with targeted malware detection in high-risk temporary areas
# Comment out the next line if you experience too many false positives in /tmp
sed -i 's/scan_tmpdir_paths=.*/scan_tmpdir_paths="\/tmp \/var\/tmp"/ig' $CONF_ORG

# Disable scanning of /dev/shm to reduce false positives from systemd and applications
# sed -i 's/scan_tmpdir_paths=.*/scan_tmpdir_paths="\/tmp \/var\/tmp"/ig' $CONF_ORG

show_yellow "Maldet temporary directory scanning configured to reduce false positives."

##########################################################################################
## Summary and next steps
##########################################################################################

show_info "Maldet installation completed with the following status:"

# Show final status
FINAL_SIG_COUNT=$(find "$MALDET_SIG_DIR" -name "*.hdb" -o -name "*.ndb" -o -name "*.ldb" | grep -v "custom.hex.dat" | wc -l)

echo "  - Maldet signature files: $FINAL_SIG_COUNT"
echo "  - Maldet scanning: Independent with optional ClamAV engine support"

if [ "$FINAL_SIG_COUNT" -gt 0 ]; then
    show_info "Maldet signatures successfully downloaded and ready for independent scanning."
else
    show_warn "Maldet signatures not downloaded during installation."
    show_info "To download signatures later, run:"
    show_info "  sudo maldet --update-sigs"
fi

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
