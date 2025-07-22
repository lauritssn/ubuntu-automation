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
# Change Maldet configuration for ClamAV integration
##########################################################################################

sed -i 's/email_alert=.*/email_alert=1/ig' $CONF_ORG
sed -i 's/email_addr=.*/email_addr=\"'${INFO_EMAIL}'\"/ig' $CONF_ORG
sed -i 's/email_alert=.*/email_alert=1/ig' $CONF_ORG
sed -i 's/quar_hits=.*/quar_hits=1/ig' $CONF_ORG
sed -i 's/quar_clean=.*/quar_clean=1/ig' $CONF_ORG
sed -i 's/quar_susp=.*/quar_susp=0/ig' $CONF_ORG
sed -i 's/quar_susp_minuid=.*/quar_susp_minuid=500/ig' $CONF_ORG

# Configure Maldet to use ClamAV as scanning engine
sed -i 's/scan_clamscan=.*/scan_clamscan=1/ig' $CONF_ORG
sed -i 's/scan_clamscan_engine=.*/scan_clamscan_engine=1/ig' $CONF_ORG

# Ensure ClamAV daemon is used for scanning (more efficient than clamscan binary)
sed -i 's/scan_clamscan_daemon=.*/scan_clamscan_daemon=1/ig' $CONF_ORG

# Disable Maldet's internal scanner to avoid duplication
sed -i 's/scan_hex_only=.*/scan_hex_only=0/ig' $CONF_ORG
sed -i 's/scan_hexdepth=.*/scan_hexdepth=0/ig' $CONF_ORG

# Ensure automatic updates are enabled for Maldet signatures
sed -i 's/autoupdate_signatures=.*/autoupdate_signatures=1/ig' $CONF_ORG
sed -i 's/autoupdate_version=.*/autoupdate_version=1/ig' $CONF_ORG

show_yellow "Maldet configured to use ClamAV daemon as primary scanning engine with auto-updates enabled."

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
    echo "# Run 'maldet --update-sigs' or '/usr/local/bin/update-maldet-clamav-links.sh update' to download actual signatures" >>"$MALDET_SIG_DIR/README.txt"

    show_yellow "Created placeholder files. Signatures can be downloaded later with: maldet --update-sigs"
else
    show_yellow "Maldet signature download completed. Found $SIG_COUNT signature files."
fi

##########################################################################################
# Configure ClamAV integration (only if signature files exist)
##########################################################################################

CLAMAV_DB_DIR="/var/lib/clamav"

if [ -d "$CLAMAV_DB_DIR" ] && [ -d "$MALDET_SIG_DIR" ]; then
    show_yellow "Setting up Maldet-ClamAV integration..."

    # Always remove any existing broken Maldet links first
    show_yellow "Cleaning up any existing Maldet signature links..."
    rm -f "$CLAMAV_DB_DIR"/maldet_* 2>/dev/null || true

    # Only create links if we have actual signature files (not just placeholders)
    ACTUAL_SIG_COUNT=$(find "$MALDET_SIG_DIR" -name "*.hdb" -o -name "*.ndb" -o -name "*.ldb" | grep -v "custom.hex.dat" | wc -l)

    if [ "$ACTUAL_SIG_COUNT" -gt 0 ]; then
        show_yellow "Creating symbolic links for $ACTUAL_SIG_COUNT Maldet signature files..."

        LINKED_SIGNATURES=0
        for sig_type in hdb ndb ldb; do
            if ls "$MALDET_SIG_DIR"/*.$sig_type >/dev/null 2>&1; then
                for sig_file in "$MALDET_SIG_DIR"/*.$sig_type; do
                    # Skip placeholder files
                    if [[ "$(basename "$sig_file")" == "custom.hex.dat" ]]; then
                        continue
                    fi

                    if [ -f "$sig_file" ] && [ -s "$sig_file" ]; then
                        sig_basename=$(basename "$sig_file")
                        link_target="$CLAMAV_DB_DIR/maldet_$sig_basename"

                        # Create link with maldet prefix to avoid naming conflicts
                        if ln -sf "$sig_file" "$link_target" 2>/dev/null; then
                            # Ensure the link is owned by clamav user
                            chown -h clamav:clamav "$link_target" 2>/dev/null || true
                            LINKED_SIGNATURES=$((LINKED_SIGNATURES + 1))
                            show_yellow "Linked: maldet_$sig_basename -> $sig_file"
                        else
                            show_warn "Failed to create link: maldet_$sig_basename"
                        fi
                    else
                        show_warn "Skipping empty or missing signature file: $sig_file"
                    fi
                done
            fi
        done

        if [ $LINKED_SIGNATURES -gt 0 ]; then
            show_yellow "Successfully linked $LINKED_SIGNATURES Maldet signature files to ClamAV."

            # Only reload ClamAV daemon if it's running and we actually linked signatures
            if systemctl is-active --quiet clamav-daemon.service; then
                show_yellow "Reloading ClamAV daemon to recognize new Maldet signatures..."
                systemctl reload clamav-daemon.service >>$LOGDIR/$LOGFILE 2>&1 || show_warn "ClamAV daemon reload failed - restart may be needed"
            fi
        else
            show_warn "No signature files were successfully linked."
        fi
    else
        show_yellow "No downloadable Maldet signature files found - skipping symbolic link creation."
        show_yellow "ClamAV will work with standard signatures only until Maldet signatures are downloaded."
        show_yellow "To download signatures later, run: maldet --update-sigs && /usr/local/bin/update-maldet-clamav-links.sh update"
    fi

else
    if [ ! -d "$CLAMAV_DB_DIR" ]; then
        show_warn "ClamAV database directory ($CLAMAV_DB_DIR) not found. Install ClamAV first."
    fi
    if [ ! -d "$MALDET_SIG_DIR" ]; then
        show_warn "Maldet signature directory ($MALDET_SIG_DIR) not found. Maldet may not be properly installed."
    fi
fi

# Deploy the separate Maldet signature link update script
SCRIPT_TEMPLATE_DIR="$BASEDIR/configs/script-templates"
MALDET_LINK_SCRIPT="/usr/local/bin/update-maldet-clamav-links.sh"

if [ -f "$SCRIPT_TEMPLATE_DIR/update-maldet-clamav-links.sh" ]; then
    cp "$SCRIPT_TEMPLATE_DIR/update-maldet-clamav-links.sh" "$MALDET_LINK_SCRIPT" >>$LOGDIR/$LOGFILE 2>&1
    chmod +x "$MALDET_LINK_SCRIPT" >>$LOGDIR/$LOGFILE 2>&1
    show_yellow "Deployed Maldet signature link update script to $MALDET_LINK_SCRIPT"

    # Only run the initial signature link update if we have actual signatures
    ACTUAL_SIG_COUNT=$(find "$MALDET_SIG_DIR" -name "*.hdb" -o -name "*.ndb" -o -name "*.ldb" | grep -v "custom.hex.dat" | wc -l)

    if [ "$ACTUAL_SIG_COUNT" -gt 0 ]; then
        show_yellow "Running initial signature link update..."
        "$MALDET_LINK_SCRIPT" update >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Initial signature link update reported issues. Check log for details."
    else
        show_yellow "Skipping initial signature link update - no signatures available yet."
        show_yellow "Run '$MALDET_LINK_SCRIPT update' after downloading signatures."
    fi
else
    show_warn "Maldet signature link update script template not found at $SCRIPT_TEMPLATE_DIR/update-maldet-clamav-links.sh"
fi

show_yellow "Maldet configuration completed. ClamAV integration will work with or without additional signatures."

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
FINAL_LINK_COUNT=$(ls "$CLAMAV_DB_DIR"/maldet_* 2>/dev/null | wc -l)

echo "  - Maldet signature files: $FINAL_SIG_COUNT"
echo "  - ClamAV signature links: $FINAL_LINK_COUNT"

if [ "$FINAL_SIG_COUNT" -gt 0 ]; then
    show_info "Maldet signatures successfully downloaded and integrated with ClamAV."
else
    show_warn "Maldet signatures not downloaded during installation."
    show_info "To download signatures later, run:"
    show_info "  1. sudo maldet --update-sigs"
    show_info "  2. sudo /usr/local/bin/update-maldet-clamav-links.sh update"
    show_info "  3. sudo systemctl reload clamav-daemon.service"
fi

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
