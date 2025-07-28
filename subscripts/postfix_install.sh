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
SUBSCRIPT="postfix_install.sh"

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
## Install Postfix
##########################################################################################

show_yellow "Installing Postfix..."

# Install Postfix non-interactively
debconf-set-selections <<<"postfix postfix/mailname string $(hostname -f)"
debconf-set-selections <<<"postfix postfix/main_mailer_type string 'Internet Site'"

apt-get --yes install postfix mailutils >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Installation of Postfix failed. Please check logfile and fix error manually.")

show_yellow "Postfix installed successfully."

##########################################################################################
## Configure Postfix
##########################################################################################

show_yellow "Configuring Postfix..."

# Backup original configuration
CONF_ORG=/etc/postfix/main.cf
CONF_BACK=$BACKUPDIR/$(basename $CONF_ORG)_$DATE

if [ -a $CONF_ORG ]; then
    cp -p $CONF_ORG $CONF_BACK && show_yellow "Postfix config file $CONF_ORG backed up to $CONF_BACK."
fi

# Configure basic Postfix settings
postconf -e "myhostname = $(hostname -f)"
postconf -e "mydomain = $EMAIL_DOMAIN"
postconf -e "myorigin = \$mydomain"
postconf -e "inet_interfaces = loopback-only"
postconf -e "mydestination = localhost"
postconf -e "relayhost = "
postconf -e "mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128"
postconf -e "mailbox_size_limit = 0"
postconf -e "recipient_delimiter = +"
postconf -e "inet_protocols = ipv4"

# Configure for local mail delivery and system notifications
postconf -e "local_recipient_maps = unix:passwd.byname \$alias_maps"
postconf -e "alias_maps = hash:/etc/aliases"
postconf -e "alias_database = hash:/etc/aliases"

# Security settings
postconf -e "smtpd_banner = \$myhostname ESMTP"
postconf -e "disable_vrfy_command = yes"
postconf -e "smtpd_helo_required = yes"

show_yellow "Postfix configuration updated."

##########################################################################################
## Configure aliases
##########################################################################################

show_yellow "Configuring mail aliases..."

# Ensure root mail goes to the info email
if ! grep -q "root:" /etc/aliases; then
    echo "root: $INFO_EMAIL" >>/etc/aliases
else
    # Use safe function for alias replacement to handle special characters in email
    if command -v safe_alias_replace >/dev/null 2>&1; then
        safe_alias_replace "/etc/aliases" "root" "$INFO_EMAIL"
    else
        # Fallback to safer sed with alternate separator
        sed -i "s|^root:.*|root: ${INFO_EMAIL}|" /etc/aliases
    fi
fi

# Rebuild alias database
newaliases >>$LOGDIR/$LOGFILE 2>&1

show_yellow "Mail aliases configured."

##########################################################################################
## Start and enable Postfix
##########################################################################################

show_yellow "Starting Postfix service..."

systemctl restart postfix >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Restarting Postfix failed. Please check logfile and fix error manually.")
systemctl enable postfix >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Enabling Postfix failed. Please check logfile and fix error manually.")

show_yellow "Postfix service started and enabled."

##########################################################################################
## Test configuration
##########################################################################################

show_yellow "Testing Postfix configuration..."

# Test configuration
postfix check >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Postfix configuration check returned warnings. Check logfile for details."

show_yellow "Postfix setup completed successfully."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
