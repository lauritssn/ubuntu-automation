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

# Disable Maldet's internal scanner to avoid duplication
sed -i 's/scan_hex_only=.*/scan_hex_only=0/ig' $CONF_ORG
sed -i 's/scan_hexdepth=.*/scan_hexdepth=0/ig' $CONF_ORG

show_yellow "Maldet configured to work with ClamAV as backend engine."

##########################################################################################
# Configure ClamAV to use Maldet signatures
##########################################################################################

# Instead of modifying clamd.conf, create symbolic links in the main database directory
# This avoids duplicate DatabaseDirectory entries that can cause conflicts
CLAMAV_DB_DIR="/var/lib/clamav"
MALDET_SIG_DIR="/usr/local/maldetect/sigs"

if [ -d "$CLAMAV_DB_DIR" ] && [ -d "$MALDET_SIG_DIR" ]; then
    show_yellow "Integrating Maldet signatures with ClamAV database directory."

    # First, ensure Maldet has updated signatures
    show_yellow "Updating Maldet signatures before linking..."
    if command -v maldet >/dev/null 2>&1; then
        maldet --update-ver >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Maldet version update reported issues - continuing with existing signatures"
    fi

    # Remove any existing broken Maldet links
    rm -f "$CLAMAV_DB_DIR"/maldet_* 2>/dev/null || true

    # Create symbolic links for Maldet signatures in ClamAV's main database directory
    # This way ClamAV can access Maldet signatures without duplicate database directories
    LINKED_SIGNATURES=0
    for sig_type in hdb ndb ldb; do
        if ls "$MALDET_SIG_DIR"/*.$sig_type >/dev/null 2>&1; then
            for sig_file in "$MALDET_SIG_DIR"/*.$sig_type; do
                if [ -f "$sig_file" ] && [ -s "$sig_file" ]; then
                    sig_basename=$(basename "$sig_file")
                    # Create link with maldet prefix to avoid naming conflicts
                    if ln -sf "$sig_file" "$CLAMAV_DB_DIR/maldet_$sig_basename" 2>/dev/null; then
                        LINKED_SIGNATURES=$((LINKED_SIGNATURES + 1))
                    fi
                fi
            done
            show_yellow "Processed Maldet .$sig_type signature files."
        else
            show_yellow "No Maldet .$sig_type signature files found in $MALDET_SIG_DIR"
        fi
    done

    # Ensure proper permissions for ClamAV to read the linked signatures
    if [ $LINKED_SIGNATURES -gt 0 ]; then
        chown -h clamav:clamav "$CLAMAV_DB_DIR"/maldet_* 2>/dev/null || true
        show_yellow "Maldet signatures successfully integrated via symbolic links ($LINKED_SIGNATURES files)."
        
        # Only reload ClamAV daemon if it's running and we actually linked signatures
        if systemctl is-active --quiet clamav-daemon.service; then
            show_yellow "Reloading ClamAV daemon to recognize new Maldet signatures..."
            systemctl reload clamav-daemon.service >>$LOGDIR/$LOGFILE 2>&1 || show_warn "ClamAV daemon reload failed - restart may be needed"
        fi
    else
        show_warn "No Maldet signature files were linked. ClamAV will work with standard signatures only."
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
SCRIPT_TEMPLATE_DIR="$(dirname "$0")/../configs/script-templates"
MALDET_LINK_SCRIPT="/usr/local/bin/update-maldet-clamav-links.sh"

if [ -f "$SCRIPT_TEMPLATE_DIR/update-maldet-clamav-links.sh" ]; then
    cp "$SCRIPT_TEMPLATE_DIR/update-maldet-clamav-links.sh" "$MALDET_LINK_SCRIPT" >>$LOGDIR/$LOGFILE 2>&1
    chmod +x "$MALDET_LINK_SCRIPT" >>$LOGDIR/$LOGFILE 2>&1
    show_yellow "Deployed Maldet signature link update script to $MALDET_LINK_SCRIPT"

    # Run the script to establish initial signature links
    show_yellow "Running initial signature link update..."
    "$MALDET_LINK_SCRIPT" update >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Initial signature link update reported issues. Check log for details."
else
    show_warn "Maldet signature link update script template not found at $SCRIPT_TEMPLATE_DIR/update-maldet-clamav-links.sh"
fi

show_yellow "Maldet configuration successfully customized for ClamAV integration without config conflicts."

# Configure scan paths for temporary directories to reduce false positives
# Enable scanning of temporary paths but with reduced sensitivity for false positives
# This helps with targeted malware detection in high-risk temporary areas
# Comment out the next line if you experience too many false positives in /tmp
sed -i 's/scan_tmpdir_paths=.*/scan_tmpdir_paths="\/tmp \/var\/tmp"/ig' $CONF_ORG

# Disable scanning of /dev/shm to reduce false positives from systemd and applications
# sed -i 's/scan_tmpdir_paths=.*/scan_tmpdir_paths="\/tmp \/var\/tmp"/ig' $CONF_ORG

show_yellow "Maldet temporary directory scanning configured to reduce false positives."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
