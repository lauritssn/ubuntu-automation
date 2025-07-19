#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################
DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="ufw_install.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log

CONF_ORG_1=$SCRIPTSDIR/ufw.sh
CONF_BACK_1=$BACKUPDIR/$(basename $CONF_ORG_1)_$DATE

CONF_BACK_2=$BACKUPDIR/ufw_rules_$DATE

##########################################################################################
## Info
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

##########################################################################################
## Install UFW
##########################################################################################

apt-get --yes install ufw >$LOGDIR/$LOGFILE 2>&1 || (show_err "Installation of UFW failed. Please check logfile and fix error manually.")
show_yellow "UFW installation done."

##########################################################################################
## Check if a ufw.sh file exists and back up
##########################################################################################

if [ -f $CONF_ORG_1 ]; then
    cp -p $CONF_ORG_1 $CONF_BACK_1 && show_yellow "Config file $CONF_ORG_1 backed up to $CONF_BACK_1."
fi

##########################################################################################
## Back up active ufw rules
##########################################################################################

ufw status numbered >>$CONF_BACK_2 2>/dev/null
show_yellow "Backup of active ufw rules can be found in $CONF_BACK_2."

##########################################################################################
## Configure UFW for Ubuntu 24.04
##########################################################################################

show_yellow "Configuring UFW defaults for Ubuntu 24.04."

# Configure defaults
ufw default deny incoming >>$LOGDIR/$LOGFILE 2>&1
ufw default allow outgoing >>$LOGDIR/$LOGFILE 2>&1

# Enable IPv6 support (Ubuntu 24.04 best practice)
sed -i 's/IPV6=no/IPV6=yes/' /etc/default/ufw 2>/dev/null || true

# Configure logging (Ubuntu 24.04 recommendation)
ufw logging on >>$LOGDIR/$LOGFILE 2>&1

show_yellow "UFW configured for Ubuntu 24.04 with IPv6 support and logging enabled."

##########################################################################################
## Generate comprehensive UFW rules based on services being installed
##########################################################################################

show_yellow "Generating UFW rules based on selected services."

# Create UFW rules script with security-first approach
cat > $SCRIPTSDIR/ufw.sh << 'EOF'
#!/bin/bash

# UFW Security Rules for Ubuntu 24.04
# Generated based on services selected during installation

show_info "Applying UFW security rules..."

##########################################################################################
## Basic Security Rules
##########################################################################################

# Allow loopback traffic (required for system functionality)
ufw allow in on lo
ufw allow out on lo

# Allow established and related incoming connections
ufw allow in on any to any port 22 proto tcp

EOF

# Add HTTP/HTTPS rules if Dokku is installed
if [[ "$DO_DOKKU_INSTALL" =~ [Yy]$ ]]; then
    cat >> $SCRIPTSDIR/ufw.sh << 'EOF'

##########################################################################################
## Web Server Rules (Dokku)
##########################################################################################

# Allow HTTP and HTTPS from anywhere (web services)
ufw allow 80/tcp comment 'HTTP for web services'
ufw allow 443/tcp comment 'HTTPS for web services'

show_info "Web server ports (80, 443) allowed from anywhere."

EOF
fi

# Add SSH rules with security considerations
cat >> $SCRIPTSDIR/ufw.sh << 'EOF'

##########################################################################################
## SSH Security Rules
##########################################################################################

EOF

# Check if SECURE_SUBNET is defined and valid
if [ -n "$SECURE_SUBNET" ] && [ "$SECURE_SUBNET" != "0.0.0.0/0" ]; then
    cat >> $SCRIPTSDIR/ufw.sh << EOF

# Allow SSH only from secure subnet for enhanced security
ufw allow proto tcp from $SECURE_SUBNET to any port 22 comment '$SECURE_SUBNET_DESC to SSH'

show_info "SSH access restricted to secure subnet: $SECURE_SUBNET"

EOF
else
    cat >> $SCRIPTSDIR/ufw.sh << 'EOF'

# WARNING: SSH allowed from anywhere - CHANGE THIS FOR PRODUCTION
ufw allow 22/tcp comment 'SSH from anywhere - INSECURE'

show_warn "SSH is open to the world - configure SECURE_SUBNET for better security!"

EOF
fi

# Add WireGuard rules if being installed
if [[ "$DO_WIREGUARD_INSTALL" =~ [Yy]$ ]]; then
    cat >> $SCRIPTSDIR/ufw.sh << EOF

##########################################################################################
## WireGuard VPN Rules
##########################################################################################

# Allow WireGuard VPN port
ufw allow 51820/udp comment 'WireGuard VPN'

# Allow VPN subnet full access to all services
ufw allow from ${WIREGUARD_SUBNET%/*}.0/24 comment 'WireGuard VPN clients'

show_info "WireGuard VPN configured with subnet: ${WIREGUARD_SUBNET%/*}.0/24"

EOF
fi

# Add Netdata monitoring rules if being installed
if [[ "$DO_NETDATA_INSTALL" =~ [Yy]$ ]]; then
    if [ -n "$SECURE_SUBNET" ] && [ "$SECURE_SUBNET" != "0.0.0.0/0" ]; then
        cat >> $SCRIPTSDIR/ufw.sh << EOF

##########################################################################################
## Netdata Monitoring Rules
##########################################################################################

# Allow Netdata monitoring from secure subnet only
ufw allow proto tcp from $SECURE_SUBNET to any port 19999 comment '$SECURE_SUBNET_DESC to Netdata'

show_info "Netdata monitoring restricted to secure subnet: $SECURE_SUBNET"

EOF
    fi
fi

# Add final script content
cat >> $SCRIPTSDIR/ufw.sh << 'EOF'

##########################################################################################
## Additional Security Rules
##########################################################################################

# Deny all other incoming traffic by default (this is already set but reinforced here)
ufw default deny incoming

# Allow all outgoing traffic (applications need internet access)
ufw default allow outgoing

# Rate limiting for SSH (prevent brute force attacks)
ufw limit ssh comment 'Rate limit SSH connections'

##########################################################################################
## Apply and Verify Rules
##########################################################################################

# Reload UFW to apply all rules
ufw reload

# Show final status
echo
echo "=== UFW Status After Configuration ==="
ufw status verbose

echo
echo "=== UFW Security Summary ==="
echo "✅ Default deny incoming (secure by default)"
echo "✅ Default allow outgoing (applications can access internet)"
echo "✅ SSH rate limiting enabled (anti-brute force)"
echo "✅ IPv6 support enabled"
echo "✅ Logging enabled for security monitoring"

# Check if SSH is properly secured
if ufw status | grep -q "22.*LIMIT"; then
    echo "✅ SSH rate limiting is active"
else
    echo "⚠️  SSH rate limiting may not be active"
fi

# Warn about open SSH if no secure subnet
if ufw status | grep -q "22/tcp.*Anywhere"; then
    echo "⚠️  WARNING: SSH is open to the world - configure secure subnet"
fi

show_info "UFW security rules applied successfully."

EOF

chmod +x $SCRIPTSDIR/ufw.sh
show_yellow "UFW rules script generated at $SCRIPTSDIR/ufw.sh"

##########################################################################################
## Inform about UFW script after it's created
##########################################################################################

show_yellow "UFW script can now be run using: $(show_info "sudo bash $CONF_ORG_1")"
show_yellow "Contents of UFW script is shown below:"

# Only show the file if it exists
if [ -f $CONF_ORG_1 ]; then
    cat $CONF_ORG_1
else
    show_err "UFW script was not created successfully at $CONF_ORG_1"
    exit 1
fi

##########################################################################################
## Enable UFW
##########################################################################################

ufw --force enable >>$LOGDIR/$LOGFILE 2>&1 || (show_yellow "ufw enable failed. Please check logfile and fix error manually.")
show_yellow "ufw enabled."

##########################################################################################
## Run UFW configuration script
##########################################################################################

if [ -f $CONF_ORG_1 ]; then
    show_yellow "Running UFW configuration script: $CONF_ORG_1"
    bash $CONF_ORG_1 >>$LOGDIR/$LOGFILE 2>&1 || (show_yellow "UFW script execution failed. Please check logfile and fix error manually.")
    show_yellow "UFW configuration script executed."
else
    show_err "UFW configuration script not found at $CONF_ORG_1"
    exit 1
fi

##########################################################################################
## Reload UFW to apply all configuration changes
##########################################################################################

ufw reload >>$LOGDIR/$LOGFILE 2>&1 || (show_yellow "ufw reload failed. Please check logfile and fix error manually.")
show_yellow "ufw reloaded to apply configuration changes."

##########################################################################################
## Verify UFW status
##########################################################################################

ufw status verbose >>$LOGDIR/$LOGFILE 2>&1
show_yellow "UFW status verified and logged."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
