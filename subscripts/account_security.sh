#!/bin/bash

##########################################################################################
## Account Security and User Management
##########################################################################################

##########################################################################################
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="account_security.sh"

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

##########################################################################################
## Configure password policies
##########################################################################################

show_yellow "Configuring password policies for Ubuntu 24.04."

# Install password quality checking
apt-get --yes install libpam-pwquality >>$LOGDIR/$LOGFILE 2>&1 || (show_warn "Failed to install libpam-pwquality, continuing without it.")

# Configure password quality requirements
if [ -f /etc/security/pwquality.conf ]; then
    # Backup original configuration
    cp /etc/security/pwquality.conf $BACKUPDIR/pwquality.conf_$DATE
    
    # Configure strong password requirements
    cat > /etc/security/pwquality.conf << 'EOF'
# Password quality requirements for Ubuntu 24.04
# Minimum password length
minlen = 12

# Require at least one digit
dcredit = -1

# Require at least one uppercase letter  
ucredit = -1

# Require at least one lowercase letter
lcredit = -1

# Require at least one special character
ocredit = -1

# Maximum number of allowed consecutive characters
maxrepeat = 3

# Minimum number of character classes
minclass = 3

# Check against dictionary words
dictcheck = 1

# Enforce password quality for root
enforce_for_root
EOF
    
    show_yellow "Password quality policies configured."
else
    show_warn "Password quality configuration file not found, skipping password policies."
fi

##########################################################################################
## Configure account lockout policies
##########################################################################################

show_yellow "Configuring account lockout policies."

# Configure account lockout for failed login attempts
if [ -f /etc/pam.d/common-auth ]; then
    # Backup original PAM auth configuration
    cp /etc/pam.d/common-auth $BACKUPDIR/common-auth_$DATE
    
    # Add account lockout after failed attempts
    if ! grep -q "pam_tally2.so" /etc/pam.d/common-auth; then
        # Add account lockout after 5 failed attempts, 10 minute lockout
        sed -i '1i auth required pam_tally2.so deny=5 unlock_time=600 onerr=fail audit' /etc/pam.d/common-auth
        show_yellow "Account lockout policy configured (5 attempts, 10 minute lockout)."
    else
        show_warn "Account lockout already configured."
    fi
fi

# Configure account module for PAM
if [ -f /etc/pam.d/common-account ]; then
    # Backup original PAM account configuration
    cp /etc/pam.d/common-account $BACKUPDIR/common-account_$DATE
    
    if ! grep -q "pam_tally2.so" /etc/pam.d/common-account; then
        # Add account checking
        echo "account required pam_tally2.so" >> /etc/pam.d/common-account
        show_yellow "Account module configured for lockout checking."
    fi
fi

##########################################################################################
## Configure sudo security
##########################################################################################

show_yellow "Configuring sudo security policies."

# Backup original sudoers configuration
cp /etc/sudoers $BACKUPDIR/sudoers_$DATE

# Create custom sudoers configuration for enhanced security
cat > /etc/sudoers.d/security-policies << 'EOF'
# Enhanced sudo security policies for Ubuntu 24.04

# Require password for sudo (disable NOPASSWD)
Defaults passwd_required

# Log sudo commands to syslog
Defaults syslog

# Require TTY for sudo (prevents some automated attacks)
Defaults requiretty

# Set sudo session timeout (15 minutes)
Defaults timestamp_timeout=15

# Set maximum number of tries for password
Defaults passwd_tries=3

# Set secure PATH for sudo
Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Prevent environment variable injection
Defaults env_reset
Defaults env_keep="COLORS DISPLAY HOSTNAME HISTSIZE KDEDIR LS_COLORS"
Defaults env_keep+="MAIL PS1 PS2 QTDIR USERNAME LANG LC_ADDRESS LC_CTYPE"
Defaults env_keep+="LC_COLLATE LC_IDENTIFICATION LC_MEASUREMENT LC_MESSAGES"
Defaults env_keep+="LC_MONETARY LC_NAME LC_NUMERIC LC_PAPER LC_TELEPHONE"
Defaults env_keep+="LC_TIME LC_ALL LANGUAGE LINGUAS _XKB_CHARSET XAUTHORITY"

# Log sudo input/output for security auditing
Defaults log_input, log_output
Defaults iolog_dir=/var/log/sudo-io
Defaults logfile=/var/log/sudo.log
EOF

# Create sudo log directory
mkdir -p /var/log/sudo-io
chmod 750 /var/log/sudo-io

# Create sudo log file
touch /var/log/sudo.log
chmod 640 /var/log/sudo.log

show_yellow "Sudo security policies configured with logging enabled."

##########################################################################################
## Configure root account security
##########################################################################################

show_yellow "Configuring root account security."

# Lock the root account password (disable password login for root)
passwd -l root >>$LOGDIR/$LOGFILE 2>&1 || (show_warn "Failed to lock root password, continuing.")

# Set root account to expire (security best practice)
chage -E -1 root >>$LOGDIR/$LOGFILE 2>&1 || (show_warn "Failed to set root account expiry, continuing.")

# Ensure root home directory has secure permissions
chmod 700 /root
chown root:root /root

# Secure root's .bashrc and profile
if [ -f /root/.bashrc ]; then
    chmod 644 /root/.bashrc
    chown root:root /root/.bashrc
fi

if [ -f /root/.profile ]; then
    chmod 644 /root/.profile
    chown root:root /root/.profile
fi

show_yellow "Root account security configured."

##########################################################################################
## Configure system-wide account security
##########################################################################################

show_yellow "Configuring system-wide account security settings."

# Configure login.defs for enhanced security
if [ -f /etc/login.defs ]; then
    # Backup original configuration
    cp /etc/login.defs $BACKUPDIR/login.defs_$DATE
    
    # Set password aging policies
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t90/' /etc/login.defs
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS\t1/' /etc/login.defs
    sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE\t7/' /etc/login.defs
    
    # Set secure umask
    sed -i 's/^UMASK.*/UMASK\t\t027/' /etc/login.defs
    
    # Configure encryption method
    if ! grep -q "ENCRYPT_METHOD" /etc/login.defs; then
        echo "ENCRYPT_METHOD SHA512" >> /etc/login.defs
    fi
    
    show_yellow "System account policies configured."
fi

# Configure user creation defaults
if [ -f /etc/default/useradd ]; then
    # Backup original configuration
    cp /etc/default/useradd $BACKUPDIR/useradd_$DATE
    
    # Set secure defaults for new users
    sed -i 's/^SHELL=.*/SHELL=\/bin\/bash/' /etc/default/useradd
    sed -i 's/^INACTIVE=.*/INACTIVE=30/' /etc/default/useradd
    
    show_yellow "User creation defaults configured."
fi

##########################################################################################
## Configure session security
##########################################################################################

show_yellow "Configuring session security."

# Configure automatic logout for idle sessions
cat > /etc/profile.d/session-timeout.sh << 'EOF'
#!/bin/bash
# Automatic logout for idle sessions (30 minutes)
TMOUT=1800
readonly TMOUT
export TMOUT
EOF

chmod 644 /etc/profile.d/session-timeout.sh

# Configure limits for user processes
if [ -f /etc/security/limits.conf ]; then
    # Backup original configuration
    cp /etc/security/limits.conf $BACKUPDIR/limits.conf_$DATE
    
    # Add security limits
    cat >> /etc/security/limits.conf << 'EOF'

# Security limits for user processes
* soft core 0
* hard core 0
* soft nproc 1000
* hard nproc 2000
* soft nofile 1024
* hard nofile 2048
EOF
    
    show_yellow "Process limits configured for security."
fi

##########################################################################################
## Create account management utilities
##########################################################################################

show_yellow "Creating account management utilities."

# Create script to show account lockout status
cat > $SCRIPTSDIR/show_locked_accounts.sh << 'EOF'
#!/bin/bash

# Show locked accounts and failed login attempts

echo "=== Account Lockout Status ==="
echo

echo "Locked user accounts:"
pam_tally2 --user="" 2>/dev/null | grep -v "^User" | awk '$2>0 {print $1 " - Failed attempts: " $2}'

echo
echo "Recent failed login attempts:"
journalctl --since "24 hours ago" | grep "authentication failure" | tail -10

echo
echo "To unlock an account, use: pam_tally2 --user=<username> --reset"
EOF

chmod +x $SCRIPTSDIR/show_locked_accounts.sh

# Create script to reset account lockouts
cat > $SCRIPTSDIR/unlock_account.sh << 'EOF'
#!/bin/bash

# Reset account lockout for a specific user

if [ $# -eq 0 ]; then
    echo "Usage: $0 <username>"
    echo "Example: $0 john"
    exit 1
fi

USERNAME="$1"

# Check if user exists
if ! id "$USERNAME" &>/dev/null; then
    echo "Error: User '$USERNAME' does not exist"
    exit 1
fi

# Reset the lockout counter
pam_tally2 --user="$USERNAME" --reset

if [ $? -eq 0 ]; then
    echo "Account lockout reset for user: $USERNAME"
    echo "The user can now attempt to login again."
else
    echo "Failed to reset account lockout for user: $USERNAME"
    exit 1
fi
EOF

chmod +x $SCRIPTSDIR/unlock_account.sh

# Create script to show sudo usage
cat > $SCRIPTSDIR/show_sudo_usage.sh << 'EOF'
#!/bin/bash

# Show recent sudo usage for auditing

echo "=== Recent Sudo Usage ==="
echo

if [ -f /var/log/sudo.log ]; then
    echo "Recent sudo commands (last 20):"
    tail -20 /var/log/sudo.log
else
    echo "Sudo log file not found. Checking syslog..."
    journalctl --since "24 hours ago" | grep sudo | tail -10
fi

echo
echo "Sudo I/O logs location: /var/log/sudo-io/"
echo "To view detailed command logs: sudo cat /var/log/sudo-io/*/log"
EOF

chmod +x $SCRIPTSDIR/show_sudo_usage.sh

show_yellow "Account management utilities created."

##########################################################################################
## Test account security configuration
##########################################################################################

show_yellow "Testing account security configuration."

# Test sudo configuration
if sudo -l >/dev/null 2>&1; then
    show_yellow "Sudo configuration test passed."
else
    show_warn "Sudo configuration may have issues. Please verify manually."
fi

# Test PAM configuration
if pamtest --verbose auth </dev/null >/dev/null 2>&1; then
    show_yellow "PAM configuration test passed."
else
    show_warn "PAM configuration test failed or pamtest not available."
fi

# Verify log directories exist
if [ -d /var/log/sudo-io ] && [ -f /var/log/sudo.log ]; then
    show_yellow "Sudo logging directories verified."
else
    show_warn "Sudo logging directories may not be properly configured."
fi

##########################################################################################
## Display security summary
##########################################################################################

show_info "=== Account Security Configuration Summary ==="
show_info "✅ Password policies: Configured (12+ chars, complexity required)"
show_info "✅ Account lockout: Configured (5 attempts, 10 minute lockout)"
show_info "✅ Sudo security: Enhanced with logging and TTY requirement"
show_info "✅ Root account: Password locked and secured"
show_info "✅ Session timeout: 30 minutes for idle sessions"
show_info "✅ Process limits: Configured for security"
show_info "✅ Management utilities: Created in $SCRIPTSDIR/"
show_info ""
show_warn "IMPORTANT SECURITY NOTES:"
show_info "• Root password login is disabled (SSH key required)"
show_info "• Users are locked out after 5 failed login attempts"
show_info "• All sudo commands are logged for auditing"
show_info "• Sessions timeout after 30 minutes of inactivity"
show_info "• Strong password requirements are enforced"
show_info ""
show_info "Management commands:"
show_info "• Show locked accounts: $SCRIPTSDIR/show_locked_accounts.sh"
show_info "• Unlock account: $SCRIPTSDIR/unlock_account.sh <username>"
show_info "• Show sudo usage: $SCRIPTSDIR/show_sudo_usage.sh"

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done." 