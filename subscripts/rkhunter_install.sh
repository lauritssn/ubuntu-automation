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
## RKHunter Rootkit Scanner Installation and Configuration
##########################################################################################

##########################################################################################
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="rkhunter_install.sh"

if [ -n "$LOGDIR" ]; then
   LOGDIR=$LOGDIR
else
   LOGDIR=/srv/apps/logs
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
## Helper functions are available via parent script (install.sh or run_subscript.sh)
##########################################################################################

# Note: Script template helper functions are available through shared_functions.sh
# which is already sourced by the parent script (install.sh or run_subscript.sh)

##########################################################################################
## RKHunter configuration
##########################################################################################

CONF1_ORG=/etc/default/rkhunter
CONF1_BACK=$BACKUPDIR/$(basename $CONF1_ORG)_$DATE
CONF1_GIT=$BASEDIR/configs/rkhunter/rkhunter

CONF2_ORG=/etc/rkhunter.conf
CONF2_BACK=$BACKUPDIR/$(basename $CONF2_ORG)_$DATE
CONF2_GIT=$BASEDIR/configs/rkhunter/rkhunter.conf

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
## Install RKHunter
##########################################################################################

apt-get --yes install rkhunter mailutils >>$LOGDIR/$LOGFILE 2>&1 || (show_err "rkhunter installation failed. Please check logfile and fix error manually.")
show_yellow "rkhunter installation done."

##########################################################################################
## Copy RKHunter configs
##########################################################################################

if [ -a $CONF1_ORG ]; then
   cp -p $CONF1_ORG $CONF1_BACK && show_yellow "RKHunter file $CONF1_ORG backed up to $CONF1_BACK."
   cp $CONF1_GIT $CONF1_ORG && show_yellow "Default RKHunter configuration deployed."
else
   cp $CONF1_GIT $CONF1_ORG && show_yellow "Default RKHunter configuration deployed."
fi

if [ -a $CONF2_ORG ]; then
   cp -p $CONF2_ORG $CONF2_BACK && show_yellow "RKHunter file $CONF2_ORG backed up to $CONF2_BACK."
   cp $CONF2_GIT $CONF2_ORG && show_yellow "Default RKHunter scan configuration deployed."
else
   cp $CONF2_GIT $CONF2_ORG && show_yellow "Default RKHunter scan configuration deployed."
fi

##########################################################################################
## Reconfigure E-mails and WEB_CMD
##########################################################################################

# Use the helper function to replace template variables properly
replace_script_variables "$CONF1_ORG"
replace_script_variables "$CONF2_ORG"

# Ensure WEB_CMD is commented out to allow remote updates
show_yellow "Ensuring WEB_CMD is disabled to allow remote database updates."

# Use safe function for commenting out WEB_CMD patterns
if command -v safe_comment_pattern >/dev/null 2>&1; then
   safe_comment_pattern "$CONF2_ORG" "WEB_CMD=" "rkhunter_backup"
else
   # Fallback to safer sed operations
   sed -i 's/^WEB_CMD=/#WEB_CMD=/' "$CONF2_ORG" 2>/dev/null || true
   # Fix the malformed regex - properly comment lines starting with WEB_CMD="
   sed -i 's/^WEB_CMD="/#&/' "$CONF2_ORG" 2>/dev/null || true
fi

# Verify WEB_CMD is properly commented
if grep -q '^WEB_CMD=' "$CONF2_ORG" 2>/dev/null; then
   show_warn "WEB_CMD is still uncommented in $CONF2_ORG - this will prevent remote updates"
else
   show_yellow "WEB_CMD properly commented out - remote updates enabled"
fi

# Verify that all placeholders were replaced correctly
verify_script_template "$CONF1_ORG" "RKHunter Default Config"
verify_script_template "$CONF2_ORG" "RKHunter Main Config"

##########################################################################################
## Update rkhunter - exit'ing disabled due to weird but OK exit codes from RKHunter
##########################################################################################

rkhunter --update --skip-keypress >>$LOGDIR/$LOGFILE 2>&1 && show_yellow "RKHunter updated."
rkhunter --propupd --skip-keypress >>$LOGDIR/$LOGFILE 2>&1 && show_yellow "RKHunter properties updated."
rkhunter --check --skip-keypress >>$LOGDIR/$LOGFILE 2>&1 || show_yellow "RKHunter check done - check log file $LOGDIR/$LOGFILE."

##########################################################################################
## Note: RKHunter scheduling now handled by systemd timers
##########################################################################################

show_yellow "RKHunter scanning and updates will be configured via systemd timers."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
