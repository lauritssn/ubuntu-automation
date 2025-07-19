#!/bin/bash

##########################################################################################
## Add New User with Sudo, 2FA, and WireGuard Configuration
##########################################################################################

##########################################################################################
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="add_user.sh"

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/tmp
fi

LOGFILE=$SUBSCRIPT-$DATE.log

# Default paths (can be overridden by environment)
SCRIPTSDIR=${SCRIPTSDIR:-"/srv/apps/scripts"}

##########################################################################################
## Message/logging functions (imported from main install script)
##########################################################################################

# Yellow
show_yellow() {
    echo $(tput bold)$(tput setaf 4) $@ $(tput sgr 0)
}
# White  
show_norm() {
    echo $(tput bold)$(tput setaf 9) $@ $(tput sgr 0)
}
# Blue
show_info() {
    echo $(tput bold)$(tput setaf 4) $@ $(tput sgr 0)
}
# Green
show_warn() {
    echo $(tput bold)$(tput setaf 2) $@ $(tput sgr 0)
}
# Red
show_err() {
    echo $(tput bold)$(tput setaf 1) $@ $(tput sgr 0)
}

##########################################################################################
## Check if we're running as root
##########################################################################################

if [[ $EUID -ne 0 ]]; then
    show_err "This script must be run as root."
    exit 1
fi

##########################################################################################
## Function to validate username
##########################################################################################

validate_username() {
    local username="$1"
    
    # Check if username is provided
    if [ -z "$username" ]; then
        show_err "Username cannot be empty."
        return 1
    fi
    
    # Check username format (alphanumeric, dashes, underscores, 3-32 chars)
    if ! [[ "$username" =~ ^[a-zA-Z0-9_-]{3,32}$ ]]; then
        show_err "Username must be 3-32 characters and contain only letters, numbers, dashes, and underscores."
        return 1
    fi
    
    # Check if user already exists
    if id "$username" &>/dev/null; then
        show_err "User '$username' already exists."
        return 1
    fi
    
    return 0
}

##########################################################################################
## Function to generate secure password
##########################################################################################

generate_password() {
    # Generate a 16-character password with mixed case, numbers, and symbols
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-16
}

##########################################################################################
## Function to check if 2FA is configured on the system
##########################################################################################

check_2fa_available() {
    if ! command -v google-authenticator >/dev/null 2>&1; then
        show_warn "Google Authenticator is not installed. 2FA setup will be skipped."
        return 1
    fi
    
    if ! grep -q "pam_google_authenticator.so" /etc/pam.d/sshd 2>/dev/null; then
        show_warn "SSH 2FA is not configured on this system. 2FA setup will be skipped."
        return 1
    fi
    
    return 0
}

##########################################################################################
## Function to check if WireGuard is available
##########################################################################################

check_wireguard_available() {
    if ! command -v wg >/dev/null 2>&1; then
        show_warn "WireGuard is not installed. VPN setup will be skipped."
        return 1
    fi
    
    if [ ! -f /etc/wireguard/wg0.conf ]; then
        show_warn "WireGuard server configuration not found. VPN setup will be skipped."
        return 1
    fi
    
    return 0
}

##########################################################################################
## Function to create global WireGuard management scripts if they don't exist
##########################################################################################

create_global_wg_scripts() {
    show_yellow "Creating global WireGuard management scripts."
    
    # Create add-wg-client script
    if [ ! -f /usr/local/bin/add-wg-client ]; then
        cat > /usr/local/bin/add-wg-client << 'EOF'
#!/bin/bash

# Global WireGuard client management script
# Wrapper for the local add_client.sh script

if [ $# -ne 1 ]; then
    echo "Usage: $0 <client_name>"
    echo "Example: $0 john"
    exit 1
fi

if [ ! -f /etc/wireguard/add_client.sh ]; then
    echo "Error: WireGuard add_client.sh script not found."
    echo "Make sure WireGuard is properly installed."
    exit 1
fi

# Run the local script
/etc/wireguard/add_client.sh "$1"
EOF
        chmod +x /usr/local/bin/add-wg-client
        show_yellow "Created /usr/local/bin/add-wg-client"
    fi
    
    # Create remove-wg-client script
    if [ ! -f /usr/local/bin/remove-wg-client ]; then
        cat > /usr/local/bin/remove-wg-client << 'EOF'
#!/bin/bash

# Global WireGuard client removal script

if [ $# -ne 1 ]; then
    echo "Usage: $0 <client_name>"
    echo "Example: $0 john"
    exit 1
fi

CLIENT_NAME="$1"

if [ ! -f /etc/wireguard/wg0.conf ]; then
    echo "Error: WireGuard server configuration not found."
    exit 1
fi

# Check if client exists
if ! grep -q "# Client: $CLIENT_NAME" /etc/wireguard/wg0.conf; then
    echo "Error: Client '$CLIENT_NAME' not found in WireGuard configuration."
    exit 1
fi

echo "Removing WireGuard client: $CLIENT_NAME"

# Remove client from server config
# Remove the client block (from "# Client: name" to the next empty line or EOF)
sed -i "/# Client: $CLIENT_NAME/,/^$/d" /etc/wireguard/wg0.conf

# Remove client config file
if [ -f "/etc/wireguard/clients/${CLIENT_NAME}.conf" ]; then
    rm "/etc/wireguard/clients/${CLIENT_NAME}.conf"
    echo "Removed client config file: /etc/wireguard/clients/${CLIENT_NAME}.conf"
fi

# Restart WireGuard to apply changes
systemctl restart wg-quick@wg0

echo "Client '$CLIENT_NAME' removed successfully!"
echo "WireGuard service restarted to apply changes."
EOF
        chmod +x /usr/local/bin/remove-wg-client
        show_yellow "Created /usr/local/bin/remove-wg-client"
    fi
}

##########################################################################################
## Main user creation function
##########################################################################################

create_user() {
    local username="$1"
    local password="$2"
    local setup_2fa="$3"
    local setup_wireguard="$4"
    
    show_yellow "Creating user: $username"
    
    # Create the user with home directory
    useradd -m -s /bin/bash "$username" >>$LOGDIR/$LOGFILE 2>&1
    if [ $? -ne 0 ]; then
        show_err "Failed to create user $username. Check logfile: $LOGDIR/$LOGFILE"
        return 1
    fi
    
    show_yellow "User $username created successfully."
    
    # Set password
    echo "$username:$password" | chpasswd
    if [ $? -ne 0 ]; then
        show_err "Failed to set password for user $username."
        return 1
    fi
    
    show_yellow "Password set for user $username."
    
    # Add user to sudo group
    usermod -aG sudo "$username" >>$LOGDIR/$LOGFILE 2>&1
    if [ $? -ne 0 ]; then
        show_err "Failed to add user $username to sudo group."
        return 1
    fi
    
    show_yellow "User $username added to sudo group."
    
    # Create .ssh directory and set proper permissions
    USER_HOME="/home/$username"
    USER_SSH_DIR="$USER_HOME/.ssh"
    
    mkdir -p "$USER_SSH_DIR"
    chown "$username:$username" "$USER_SSH_DIR"
    chmod 700 "$USER_SSH_DIR"
    
    # Create authorized_keys file
    touch "$USER_SSH_DIR/authorized_keys"
    chown "$username:$username" "$USER_SSH_DIR/authorized_keys"
    chmod 600 "$USER_SSH_DIR/authorized_keys"
    
    show_yellow "SSH directory created for user $username."
    
    return 0
}

##########################################################################################
## Function to setup 2FA for user
##########################################################################################

setup_user_2fa() {
    local username="$1"
    
    show_yellow "Setting up 2FA for user: $username"
    
    # Check if 2FA setup script exists
    if [ ! -f "$SCRIPTSDIR/setup_user_2fa.sh" ]; then
        show_err "2FA setup script not found at $SCRIPTSDIR/setup_user_2fa.sh"
        return 1
    fi
    
    # Run the 2FA setup script
    "$SCRIPTSDIR/setup_user_2fa.sh" "$username"
    if [ $? -eq 0 ]; then
        show_yellow "2FA setup completed for user: $username"
        return 0
    else
        show_err "2FA setup failed for user: $username"
        return 1
    fi
}

##########################################################################################
## Function to setup WireGuard for user
##########################################################################################

setup_user_wireguard() {
    local username="$1"
    
    show_yellow "Setting up WireGuard VPN for user: $username"
    
    # Create global WireGuard scripts if they don't exist
    create_global_wg_scripts
    
    # Add WireGuard client
    if [ -f /etc/wireguard/add_client.sh ]; then
        /etc/wireguard/add_client.sh "$username" >>$LOGDIR/$LOGFILE 2>&1
        if [ $? -eq 0 ]; then
            show_yellow "WireGuard VPN configured for user: $username"
            show_info "VPN config file: /etc/wireguard/clients/${username}.conf"
            return 0
        else
            show_err "Failed to configure WireGuard for user: $username"
            return 1
        fi
    else
        show_err "WireGuard add_client.sh script not found."
        return 1
    fi
}

##########################################################################################
## Usage function
##########################################################################################

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -u, --username <name>     Username for the new user (required)"
    echo "  -p, --password <pass>     Password for the user (optional, will generate if not provided)"
    echo "  --no-2fa                  Skip 2FA setup"
    echo "  --no-wireguard           Skip WireGuard VPN setup"
    echo "  --interactive            Interactive mode (prompt for all options)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --interactive                    # Interactive mode"
    echo "  $0 -u john                         # Create user 'john' with auto-generated password"
    echo "  $0 -u jane -p mypassword           # Create user 'jane' with specific password"
    echo "  $0 -u bob --no-2fa --no-wireguard  # Create user 'bob' without 2FA or VPN"
    echo ""
}

##########################################################################################
## Interactive mode function
##########################################################################################

interactive_mode() {
    show_info "=== Interactive User Creation ==="
    echo ""
    
    # Get username
    while true; do
        read -p "Enter username for the new user: " NEW_USERNAME
        if validate_username "$NEW_USERNAME"; then
            break
        fi
        echo "Please try again."
    done
    
    # Get password option
    while true; do
        read -p "Do you want to set a custom password? (Y/N) [N]: " yn
        case ${yn:-N} in
        [Yy]*)
            while true; do
                read -s -p "Enter password for $NEW_USERNAME: " NEW_PASSWORD
                echo
                read -s -p "Confirm password for $NEW_USERNAME: " NEW_PASSWORD_CONFIRM
                echo
                if [ "$NEW_PASSWORD" = "$NEW_PASSWORD_CONFIRM" ]; then
                    break
                else
                    echo "Passwords do not match. Please try again."
                fi
            done
            break
            ;;
        [Nn]* | "")
            NEW_PASSWORD=$(generate_password)
            show_info "Auto-generated password: $NEW_PASSWORD"
            break
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
    
    # Check 2FA availability and ask
    SETUP_2FA="N"
    if check_2fa_available; then
        while true; do
            read -p "Do you want to setup 2FA for this user? (Y/N) [Y]: " yn
            case ${yn:-Y} in
            [Yy]* | "")
                SETUP_2FA="Y"
                break
                ;;
            [Nn]*)
                SETUP_2FA="N"
                break
                ;;
            *) echo "Please answer yes or no." ;;
            esac
        done
    fi
    
    # Check WireGuard availability and ask
    SETUP_WIREGUARD="N"
    if check_wireguard_available; then
        while true; do
            read -p "Do you want to setup WireGuard VPN for this user? (Y/N) [Y]: " yn
            case ${yn:-Y} in
            [Yy]* | "")
                SETUP_WIREGUARD="Y"
                break
                ;;
            [Nn]*)
                SETUP_WIREGUARD="N"
                break
                ;;
            *) echo "Please answer yes or no." ;;
            esac
        done
    fi
    
    # Summary
    echo ""
    show_info "=== Summary ==="
    echo "Username: $NEW_USERNAME"
    echo "Password: $([ ${#NEW_PASSWORD} -gt 0 ] && echo '[SET]' || echo '[AUTO-GENERATED]')"
    echo "2FA Setup: $SETUP_2FA"
    echo "WireGuard VPN: $SETUP_WIREGUARD"
    echo ""
    
    while true; do
        read -p "Continue with user creation? (Y/N): " yn
        case $yn in
        [Yy]*)
            break
            ;;
        [Nn]*)
            show_warn "User creation cancelled."
            exit 0
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
}

##########################################################################################
## Main script execution
##########################################################################################

show_info "$SUBSCRIPT is being executed. Logfile can be found at $LOGDIR/$LOGFILE."

# Default values
NEW_USERNAME=""
NEW_PASSWORD=""
SETUP_2FA="Y"
SETUP_WIREGUARD="Y"
INTERACTIVE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--username)
            NEW_USERNAME="$2"
            shift 2
            ;;
        -p|--password)
            NEW_PASSWORD="$2"
            shift 2
            ;;
        --no-2fa)
            SETUP_2FA="N"
            shift
            ;;
        --no-wireguard)
            SETUP_WIREGUARD="N"
            shift
            ;;
        --interactive)
            INTERACTIVE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            show_err "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Run interactive mode if requested or if no username provided
if [ "$INTERACTIVE" = true ] || [ -z "$NEW_USERNAME" ]; then
    interactive_mode
fi

# Validate username
if ! validate_username "$NEW_USERNAME"; then
    exit 1
fi

# Generate password if not provided
if [ -z "$NEW_PASSWORD" ]; then
    NEW_PASSWORD=$(generate_password)
    show_info "Auto-generated password: $NEW_PASSWORD"
fi

# Check system capabilities
if [ "$SETUP_2FA" = "Y" ] && ! check_2fa_available; then
    SETUP_2FA="N"
fi

if [ "$SETUP_WIREGUARD" = "Y" ] && ! check_wireguard_available; then
    SETUP_WIREGUARD="N"
fi

##########################################################################################
## Execute user creation process
##########################################################################################

show_info "=== Starting User Creation Process ==="

# Step 1: Create the user
if ! create_user "$NEW_USERNAME" "$NEW_PASSWORD" "$SETUP_2FA" "$SETUP_WIREGUARD"; then
    show_err "User creation failed. Exiting."
    exit 1
fi

# Step 2: Setup 2FA if requested
if [ "$SETUP_2FA" = "Y" ]; then
    if ! setup_user_2fa "$NEW_USERNAME"; then
        show_warn "2FA setup failed, but user was created successfully."
    fi
fi

# Step 3: Setup WireGuard if requested
if [ "$SETUP_WIREGUARD" = "Y" ]; then
    if ! setup_user_wireguard "$NEW_USERNAME"; then
        show_warn "WireGuard setup failed, but user was created successfully."
    fi
fi

##########################################################################################
## Display final information
##########################################################################################

show_info "=== User Creation Complete ==="
show_warn "User '$NEW_USERNAME' has been created successfully!"
echo ""
show_info "Login Information:"
echo "  Username: $NEW_USERNAME"
echo "  Password: $NEW_PASSWORD"
echo "  Sudo Access: YES (use 'sudo su -' for root access)"
echo ""

if [ "$SETUP_2FA" = "Y" ]; then
    show_info "SSH 2FA: CONFIGURED"
    echo "  The user can now log in using SSH key + 2FA code"
    echo "  Make sure to add the public key to: /home/$NEW_USERNAME/.ssh/authorized_keys"
else
    show_warn "SSH 2FA: NOT CONFIGURED"
    echo "  Consider running: $SCRIPTSDIR/setup_user_2fa.sh $NEW_USERNAME"
fi

echo ""

if [ "$SETUP_WIREGUARD" = "Y" ]; then
    show_info "WireGuard VPN: CONFIGURED"
    echo "  VPN config file: /etc/wireguard/clients/${NEW_USERNAME}.conf"
    echo "  Generate QR code: qrencode -t ansiutf8 < /etc/wireguard/clients/${NEW_USERNAME}.conf"
else
    show_warn "WireGuard VPN: NOT CONFIGURED"
    echo "  Consider running: add-wg-client $NEW_USERNAME"
fi

echo ""
show_warn "IMPORTANT NEXT STEPS:"
echo "1. Add the user's SSH public key to: /home/$NEW_USERNAME/.ssh/authorized_keys"
echo "2. Test SSH login in a NEW terminal session before closing this one"
if [ "$SETUP_2FA" = "Y" ]; then
    echo "3. Ensure the user scans the 2FA QR code with their authenticator app"
fi
if [ "$SETUP_WIREGUARD" = "Y" ]; then
    echo "4. Share the WireGuard config file or QR code with the user securely"
fi
echo ""

show_info "$SUBSCRIPT completed successfully." 