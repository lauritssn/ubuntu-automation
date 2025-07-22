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

# Add Maldet signature path to ClamAV
CLAMAV_CONF="/etc/clamav/clamd.conf"
if [ -f "$CLAMAV_CONF" ]; then
    if ! grep -q "/usr/local/maldetect/sigs" "$CLAMAV_CONF"; then
        echo "DatabaseDirectory /usr/local/maldetect/sigs" >>"$CLAMAV_CONF"
        show_yellow "Added Maldet signatures to ClamAV configuration."
    fi
fi

# Create symbolic link for Maldet signatures in ClamAV directory
CLAMAV_DB_DIR="/var/lib/clamav"
if [ -d "$CLAMAV_DB_DIR" ] && [ -d "/usr/local/maldetect/sigs" ]; then
    ln -sf /usr/local/maldetect/sigs/*.{hdb,ndb,ldb} "$CLAMAV_DB_DIR/" 2>/dev/null || true
    show_yellow "Linked Maldet signatures to ClamAV database directory."
fi

show_yellow "Maldet configuration successfully customized for ClamAV integration."

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
