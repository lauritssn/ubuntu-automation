#!/bin/bash
# https://www.cloudbooklet.com/developer/how-to-install-and-setup-sendmail-on-ubuntu

##########################################################################################
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="sendmail_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Update system packages
##########################################################################################

show_yellow "Updating system packages..."
apt-get --yes update >>$LOGDIR/$LOGFILE 2>&1 || (show_err "System update failed. Please check logfile and fix error manually.")
apt-get --yes upgrade >>$LOGDIR/$LOGFILE 2>&1 || (show_err "System upgrade failed. Please check logfile and fix error manually.")

##########################################################################################
## Install Sendmail
##########################################################################################

show_yellow "Installing Sendmail..."
apt-get --yes install sendmail >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Installation of sendmail failed. Please check logfile and fix error manually.")

##########################################################################################
## Configure SMTP
##########################################################################################

show_yellow "Configuring SMTP..."

# Create auth directory with proper permissions
mkdir -p /etc/mail/authinfo
chmod -R 700 /etc/mail/authinfo

# Create SMTP auth file
cat >/etc/mail/authinfo/smtp-auth <<EOF
AuthInfo: "U:root" "I:${SMTP_USER}" "P:${SMTP_PASS}"
EOF

# Create hash database map
cd /etc/mail/authinfo
makemap hash smtp-auth <smtp-auth

# Configure sendmail.mc
cd /etc/mail
cat >>sendmail.mc <<EOF

define(\`SMART_HOST',\`[${SMTP_HOST}]')dnl
define(\`RELAY_MAILER_ARGS', \`TCP \$h 587')dnl
define(\`ESMTP_MAILER_ARGS', \`TCP \$h 587')dnl
define(\`confAUTH_OPTIONS', \`A p')dnl
TRUST_AUTH_MECH(\`EXTERNAL DIGEST-MD5 CRAM-MD5 LOGIN PLAIN')dnl
define(\`confAUTH_MECHANISMS', \`EXTERNAL GSSAPI DIGEST-MD5 CRAM-MD5 LOGIN PLAIN')dnl
FEATURE(\`authinfo',\`hash -o /etc/mail/authinfo/smtp-auth.db')dnl
EOF

##########################################################################################
## Rebuild and restart Sendmail
##########################################################################################

show_yellow "Rebuilding Sendmail configuration..."
cd /etc/mail
make >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Rebuilding sendmail configuration failed. Please check logfile and fix error manually.")

show_yellow "Restarting Sendmail..."
/etc/init.d/sendmail restart >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Restarting sendmail failed. Please check logfile and fix error manually.")

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
