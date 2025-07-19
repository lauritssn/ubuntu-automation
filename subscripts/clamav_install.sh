#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="clamav_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
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

apt-get --yes install clamav clamav-daemon clamav-freshclam >$LOGDIR/$LOGFILE 2>&1 || (show_err "ClamAV installation failed. Please check logfile and fix error manually.")
show_yellow "ClamAV installation successfull."

##########################################################################################
## Update ClamAV
##########################################################################################

show_yellow "Updating ClamAV (this may take a while!)."
systemctl stop clamav-freshclam.service >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Stopping freshclam service failed. Please check logfile and fix error manually.")
freshclam >>$LOGDIR/$LOGFILE 2>&1 || (show_err "ClamAV update failed. Please check logfile and fix error manually.")
systemctl start clamav-freshclam.service >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Starting freshclam service failed. Please check logfile and fix error manually.")
show_yellow "ClamAV update done."

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

systemctl restart clamav-daemon >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Restarting ClamAV failed. Please check logfile and fix error manually.")
show_yellow "ClamAV restarted."

##########################################################################################
## DONE
##########################################################################################

show_info "$SUBSCRIPT done."
