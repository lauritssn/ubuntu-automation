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
## Cleanup function for error handling
##########################################################################################

cleanup_on_error() {
    local exit_code=$?
    show_err "Installation failed at line $1. Cleaning up..."

    # Remove podman user if it was created during this installation
    if [ -n "$PODMAN_USER_CREATED" ] && id "$PODMAN_USER" &>/dev/null; then
        show_warn "Removing created user: $PODMAN_USER"
        userdel -r "$PODMAN_USER" 2>/dev/null || true
    fi

    # Remove any partial configurations
    if [ -d "/home/$PODMAN_USER/.config/containers" ]; then
        show_warn "Removing partial container configurations"
        rm -rf "/home/$PODMAN_USER/.config/containers" 2>/dev/null || true
    fi

    exit $exit_code
}

# Set up error trap
trap 'cleanup_on_error ${LINENO}' ERR

##########################################################################################
## Podman Installation and Configuration
##########################################################################################

##########################################################################################
## Set variables
##########################################################################################
DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="podman_install.sh"

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
## Install Podman rootless
##########################################################################################

show_yellow "Installing Podman in rootless mode."

# Update package lists
apt-get update >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Package update failed. Please check logfile and fix error manually.")

# Check available packages and show versions
show_info "Checking available Podman packages..."
if apt-cache policy podman >/dev/null 2>&1; then
    PODMAN_VERSION=$(apt-cache policy podman | grep Candidate | awk '{print $2}' || echo "unknown")
    show_info "Installing Podman version: $PODMAN_VERSION"
fi

show_yellow "Installing Podman and required dependencies."
# Install core packages
apt-get --yes install podman uidmap dbus-user-session crun >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Installation of core Podman packages failed. Please check logfile and fix error manually.")

# Install additional useful tools
show_yellow "Installing additional container tools."
apt-get --yes install buildah skopeo >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Some additional tools failed to install - continuing with core installation"

# Try to install podman-compose if available
if apt-cache show podman-compose >/dev/null 2>&1; then
    show_yellow "Installing podman-compose."
    apt-get --yes install podman-compose >>$LOGDIR/$LOGFILE 2>&1 || show_warn "podman-compose installation failed - Docker Compose alternative may not be available"
else
    show_warn "podman-compose package not available in repositories"
fi

##########################################################################################
## Create dedicated podman user
##########################################################################################

PODMAN_USER="podman"
show_yellow "Creating dedicated Podman user: $PODMAN_USER"

# Create dedicated user for Podman
if ! id "$PODMAN_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$PODMAN_USER"
    show_yellow "Created user: $PODMAN_USER"
    export PODMAN_USER_CREATED="yes" # Mark for cleanup if needed

    # Set up user directories
    sudo -u "$PODMAN_USER" mkdir -p "/home/$PODMAN_USER/.config/containers"

    # Enable user lingering for systemd user services
    loginctl enable-linger "$PODMAN_USER" 2>/dev/null || show_warn "Could not enable lingering for $PODMAN_USER"
else
    show_yellow "User $PODMAN_USER already exists"
fi

##########################################################################################
## Configure Podman for rootless operation
##########################################################################################

show_yellow "Configuring Podman for rootless operation."

# Ensure subuid and subgid are configured for the podman user
if ! grep -q "^$PODMAN_USER:" /etc/subuid; then
    echo "$PODMAN_USER:100000:65536" >>/etc/subuid
    echo "$PODMAN_USER:100000:65536" >>/etc/subgid
    show_yellow "Configured subuid/subgid for $PODMAN_USER"
fi

# Create containers.conf for the podman user with network optimization
sudo -u "$PODMAN_USER" bash -c "cat > /home/$PODMAN_USER/.config/containers/containers.conf << 'EOF'
[containers]
# Use crun as the OCI runtime for better performance
default_runtime = \"crun\"

# Set default log driver
log_driver = \"journald\"

# Enable systemd integration
init = true

[network]
# Use netavark for better networking (default in newer versions)
network_backend = \"netavark\"

# Configure for socket activation and real IP passthrough
# Socket activation preserves original client IPs without NAT
# This is optimal for Traefik to log real user IP addresses
default_network = \"netavark\"

# Enable IPv6 for full socket activation support
enable_ipv6 = true

[engine]
# Runtime configuration
runtime = \"crun\"

# Enable user namespace mapping
enable_fuse_overlayfs = true

# Set events logger
events_logger = \"journald\"

# Socket activation configuration
# These settings optimize for socket-activated containers
service_timeout = 0

# Enable proper signal handling for socket activation
stop_timeout = 10

# Network settings for real IP preservation
# When using socket activation, containers receive direct connections
# which preserves the original client IP addresses
EOF"

# Create storage.conf for optimized storage
sudo -u "$PODMAN_USER" bash -c "cat > /home/$PODMAN_USER/.config/containers/storage.conf << 'EOF'
[storage]
# Use overlay driver for best performance
driver = \"overlay\"
runroot = \"/run/user/\$UID/containers\"
graphroot = \"/home/$PODMAN_USER/.local/share/containers/storage\"

[storage.options]
# Use fuse-overlayfs for rootless operations
mount_program = \"/usr/bin/fuse-overlayfs\"

[storage.options.overlay]
# Simplified overlay configuration - let fuse-overlayfs handle defaults
mount_program = \"/usr/bin/fuse-overlayfs\"
EOF"

##########################################################################################
## Configure networking for real IP forwarding
##########################################################################################

show_yellow "Configuring networking for real IP forwarding (Traefik compatibility)."

# Enable IP forwarding in sysctl (required for container networking)
if ! grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >>/etc/sysctl.conf
    show_yellow "Enabled IPv4 forwarding in sysctl.conf"
fi

if ! grep -q "^net.ipv6.conf.all.forwarding" /etc/sysctl.conf; then
    echo "net.ipv6.conf.all.forwarding=1" >>/etc/sysctl.conf
    show_yellow "Enabled IPv6 forwarding in sysctl.conf"
fi

# Apply sysctl changes immediately
sysctl -p >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to apply sysctl changes"

# Create systemd directories for socket activation
sudo -u "$PODMAN_USER" bash -c "mkdir -p /home/$PODMAN_USER/.config/systemd/user"
sudo -u "$PODMAN_USER" bash -c "mkdir -p /home/$PODMAN_USER/.config/containers/systemd"

# Configure socket activation support for containers
show_yellow "Configuring socket activation for containers."

# Create helper script for socket-activated container management
sudo -u "$PODMAN_USER" bash -c "cat > /home/$PODMAN_USER/.config/containers/socket-setup.sh << 'EOF'
#!/bin/bash
# Helper script to set up socket-activated containers
# Usage: ./socket-setup.sh <service-name> <port> [additional-ports...]

if [ \$# -lt 2 ]; then
    echo \"Usage: \$0 <service-name> <port> [additional-ports...]\"
    echo \"Example: \$0 traefik 80 443\"
    exit 1
fi

SERVICE_NAME=\"\$1\"
shift
PORTS=(\"\$@\")

# Create socket unit
cat > ~/.config/systemd/user/\${SERVICE_NAME}.socket << EOL
[Unit]
Description=\${SERVICE_NAME} socket
Requires=\${SERVICE_NAME}.service

[Socket]
EOL

# Add listening ports
for port in \"\${PORTS[@]}\"; do
    echo \"ListenStream=0.0.0.0:\$port\" >> ~/.config/systemd/user/\${SERVICE_NAME}.socket
done

cat >> ~/.config/systemd/user/\${SERVICE_NAME}.socket << EOL

[Install]
WantedBy=sockets.target
EOL

echo \"Socket unit created: ~/.config/systemd/user/\${SERVICE_NAME}.socket\"
echo \"Next steps:\"
echo \"1. Create your \${SERVICE_NAME}.container file in ~/.config/containers/systemd/\"
echo \"2. Run: systemctl --user daemon-reload\"
echo \"3. Run: systemctl --user enable \${SERVICE_NAME}.socket\"
echo \"4. Run: systemctl --user start \${SERVICE_NAME}.socket\"
EOF"

chmod +x "/home/$PODMAN_USER/.config/containers/socket-setup.sh"

##########################################################################################
## Set up environment and aliases
##########################################################################################

show_yellow "Setting up environment for $PODMAN_USER."

# Add useful aliases and environment variables
sudo -u "$PODMAN_USER" bash -c 'cat >> ~/.bashrc << "EOF"

# Podman aliases for Docker compatibility
alias docker="podman"
if command -v podman-compose >/dev/null 2>&1; then
    alias docker-compose="podman-compose"
else
    # Fallback to podman compose plugin if podman-compose not available
    alias docker-compose="podman compose"
fi

# Environment variables for optimal operation
export BUILDAH_ISOLATION=chroot
export CONTAINER_HOST="unix:///run/user/$UID/podman/podman.sock"

# Function to check if podman socket is running
check_podman_socket() {
    if ! systemctl --user is-active --quiet podman.socket; then
        echo "Starting Podman socket service..."
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user start podman.socket
        systemctl --user enable podman.socket
    fi
}

# Auto-start socket on login
check_podman_socket 2>/dev/null || true
EOF'

##########################################################################################
## Initialize Podman for the user
##########################################################################################

show_yellow "Initializing Podman for user $PODMAN_USER."

# Initialize Podman and start services as the podman user
sudo -u "$PODMAN_USER" bash -c '
    # Set proper environment
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    
    # Create runtime directory if it does not exist
    mkdir -p "$XDG_RUNTIME_DIR/podman"
    
    # Generate systemd user directory
    mkdir -p ~/.config/systemd/user
    
    # Initialize podman to create necessary files
    podman system migrate 2>/dev/null || true
    
    # Reload systemd user daemon
    systemctl --user daemon-reload 2>/dev/null || true
    
    # Start and enable podman socket with better error handling
    if systemctl --user start podman.socket 2>/dev/null; then
        systemctl --user enable podman.socket 2>/dev/null || true
        echo "✅ Podman socket started successfully"
        
        # Test socket connectivity
        sleep 2
        if podman version >/dev/null 2>&1; then
            echo "✅ Podman socket connectivity confirmed"
        else
            echo "⚠️ Socket started but connectivity test failed"
        fi
    else
        echo "⚠️ Socket start failed, trying manual service"
        
        # Try manual service start
        podman system service --time=0 unix:///run/user/$(id -u)/podman/podman.sock &
        sleep 3
        
        if podman version >/dev/null 2>&1; then
            echo "✅ Podman manual service started successfully"
        else
            echo "❌ Manual service start also failed"
        fi
    fi
'

##########################################################################################
## Create management scripts
##########################################################################################

show_yellow "Creating Podman management scripts."

# Create a script to easily manage containers as the podman user
cat >/usr/local/bin/podman-user <<'EOF'
#!/bin/bash
# Script to run podman commands as the podman user
if [ "$#" -eq 0 ]; then
    echo "Usage: podman-user <podman-command>"
    echo "Example: podman-user ps -a"
    echo "Example: podman-user run -d --name traefik ..."
    exit 1
fi

# Ensure podman socket is running before executing commands
sudo -u podman bash -c '
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    
    # Try to start socket if not running
    if ! systemctl --user is-active --quiet podman.socket 2>/dev/null; then
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user start podman.socket 2>/dev/null || true
        sleep 2
    fi
    
    # If socket still not working, try manual service
    if ! podman version >/dev/null 2>&1; then
        pkill -f "podman system service" 2>/dev/null || true
        podman system service --time=0 unix:///run/user/$(id -u)/podman/podman.sock &
        sleep 2
    fi
'

# Execute the podman command with proper environment
sudo -u podman bash -c "export XDG_RUNTIME_DIR=/run/user/\$(id -u); podman \$*" -- "$@"
EOF

chmod +x /usr/local/bin/podman-user

# Create a status check script
cat >/usr/local/bin/podman-status <<'EOF'
#!/bin/bash
echo "=== Podman User Status ==="
echo "User: podman"
echo "Home: /home/podman"
echo "Runtime Dir: /run/user/$(id -u podman 2>/dev/null || echo 'N/A')"
echo ""

echo "=== Environment Test ==="
sudo -u podman bash -c 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"; echo "XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR"'
echo ""

echo "=== Podman Service Status ==="
sudo -u podman bash -c 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"; systemctl --user status podman.socket --no-pager -l' 2>/dev/null || echo "Socket not running"
echo ""

echo "=== Socket File Check ==="
SOCKET_PATH="/run/user/$(id -u podman 2>/dev/null || echo '0')/podman/podman.sock"
if [ -S "$SOCKET_PATH" ]; then
    echo "✅ Socket file exists: $SOCKET_PATH"
else
    echo "❌ Socket file missing: $SOCKET_PATH"
fi
echo ""

echo "=== Podman Version ==="
sudo -u podman bash -c 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"; podman version --format "{{.Client.Version}}"' 2>/dev/null || echo "Version check failed"
echo ""

echo "=== Running Containers ==="
sudo -u podman bash -c 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"; podman ps' 2>/dev/null || echo "No containers or podman not accessible"
echo ""

echo "=== Network Configuration ==="
sudo -u podman bash -c 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"; podman network ls' 2>/dev/null || echo "Network info not accessible"
EOF

chmod +x /usr/local/bin/podman-status

# Create socket activation management script
cat >/usr/local/bin/podman-socket <<'EOF'
#!/bin/bash
# Script to manage socket-activated containers

show_usage() {
    echo "Usage: podman-socket <command> [service-name]"
    echo "Commands:"
    echo "  list              - List all socket units"
    echo "  status [service]  - Show status of socket service(s)" 
    echo "  start [service]   - Start specific socket service"
    echo "  stop [service]    - Stop specific socket service"
    echo "  restart [service] - Restart specific socket service"
    echo "  logs [service]    - Show logs for specific service"
    echo "  enable [service]  - Enable socket service to start on boot"
    echo "  disable [service] - Disable socket service from starting on boot"
    echo ""
    echo "Examples:"
    echo "  podman-socket list"
    echo "  podman-socket status traefik-http"
    echo "  podman-socket start traefik-http"
    echo "  podman-socket logs traefik"
}

if [ "$#" -lt 1 ]; then
    show_usage
    exit 1
fi

COMMAND="$1"
SERVICE="$2"

case "$COMMAND" in
    "list")
        echo "=== Socket Units ==="
        sudo -u podman bash -c 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"; systemctl --user list-units --type=socket --state=loaded'
        echo ""
        echo "=== Container Services ==="
        sudo -u podman bash -c 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"; systemctl --user list-units --type=service --state=loaded | grep -E "\.(service|container)"'
        ;;
    "status")
        if [ -z "$SERVICE" ]; then
            echo "=== All Socket Services Status ==="
            sudo -u podman bash -c 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"; systemctl --user status --no-pager -l *.socket' 2>/dev/null || echo "No active socket services found"
        else
            echo "=== Status for $SERVICE ==="
            sudo -u podman bash -c "export XDG_RUNTIME_DIR=\"/run/user/\$(id -u)\"; systemctl --user status --no-pager -l $SERVICE.socket" 2>/dev/null || \
            sudo -u podman bash -c "export XDG_RUNTIME_DIR=\"/run/user/\$(id -u)\"; systemctl --user status --no-pager -l $SERVICE.service" 2>/dev/null || \
            echo "Service $SERVICE not found"
        fi
        ;;
    "start")
        if [ -z "$SERVICE" ]; then
            echo "Error: Service name required for start command"
            show_usage
            exit 1
        fi
        echo "Starting socket service: $SERVICE"
        sudo -u podman bash -c "export XDG_RUNTIME_DIR=\"/run/user/\$(id -u)\"; systemctl --user start $SERVICE.socket"
        ;;
    "stop")
        if [ -z "$SERVICE" ]; then
            echo "Error: Service name required for stop command"
            show_usage
            exit 1
        fi
        echo "Stopping socket service: $SERVICE"
        sudo -u podman bash -c "export XDG_RUNTIME_DIR=\"/run/user/\$(id -u)\"; systemctl --user stop $SERVICE.socket $SERVICE.service" 2>/dev/null || true
        ;;
    "restart")
        if [ -z "$SERVICE" ]; then
            echo "Error: Service name required for restart command"
            show_usage
            exit 1
        fi
        echo "Restarting socket service: $SERVICE"
        sudo -u podman bash -c "export XDG_RUNTIME_DIR=\"/run/user/\$(id -u)\"; systemctl --user restart $SERVICE.socket"
        ;;
    "logs")
        if [ -z "$SERVICE" ]; then
            echo "Error: Service name required for logs command"
            show_usage
            exit 1
        fi
        echo "Showing logs for: $SERVICE"
        sudo -u podman bash -c "export XDG_RUNTIME_DIR=\"/run/user/\$(id -u)\"; journalctl --user -u $SERVICE.service -f" 2>/dev/null || \
        sudo -u podman bash -c "export XDG_RUNTIME_DIR=\"/run/user/\$(id -u)\"; journalctl --user -u $SERVICE.socket -f"
        ;;
    "enable")
        if [ -z "$SERVICE" ]; then
            echo "Error: Service name required for enable command"
            show_usage
            exit 1
        fi
        echo "Enabling socket service: $SERVICE"
        sudo -u podman bash -c "export XDG_RUNTIME_DIR=\"/run/user/\$(id -u)\"; systemctl --user enable $SERVICE.socket"
        ;;
    "disable")
        if [ -z "$SERVICE" ]; then
            echo "Error: Service name required for disable command"
            show_usage
            exit 1
        fi
        echo "Disabling socket service: $SERVICE"
        sudo -u podman bash -c "export XDG_RUNTIME_DIR=\"/run/user/\$(id -u)\"; systemctl --user disable $SERVICE.socket"
        ;;
    *)
        echo "Error: Unknown command '$COMMAND'"
        show_usage
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/podman-socket

##########################################################################################
## Security and permissions setup
##########################################################################################

show_yellow "Configuring security settings for rootless Podman."

# Ensure proper ownership of podman user files
chown -R "$PODMAN_USER:$PODMAN_USER" "/home/$PODMAN_USER/.config"
chown -R "$PODMAN_USER:$PODMAN_USER" "/home/$PODMAN_USER/.local" 2>/dev/null || true

# Set appropriate permissions
chmod 755 "/home/$PODMAN_USER/.config/containers"
chmod 644 "/home/$PODMAN_USER/.config/containers/containers.conf"
chmod 644 "/home/$PODMAN_USER/.config/containers/storage.conf"

##########################################################################################
## Update RKHunter configuration if installed
##########################################################################################

if command -v rkhunter >/dev/null 2>&1 && [ -f /etc/rkhunter.conf ]; then
    show_yellow "RKHunter detected. Updating configuration to whitelist Podman."

    # Check if SCRIPTWHITELIST already has any podman entries
    if grep -q "^SCRIPTWHITELIST.*podman" /etc/rkhunter.conf; then
        # Update existing entries
        if ! grep -q "^SCRIPTWHITELIST=/usr/bin/podman$" /etc/rkhunter.conf; then
            # Add specific entries if not already present
            if ! grep -q "^SCRIPTWHITELIST=/usr/bin/podman" /etc/rkhunter.conf; then
                echo "SCRIPTWHITELIST=/usr/bin/podman" >>/etc/rkhunter.conf
            fi
            if ! grep -q "^SCRIPTWHITELIST=/usr/bin/buildah" /etc/rkhunter.conf; then
                echo "SCRIPTWHITELIST=/usr/bin/buildah" >>/etc/rkhunter.conf
            fi
            if ! grep -q "^SCRIPTWHITELIST=/usr/bin/crun" /etc/rkhunter.conf; then
                echo "SCRIPTWHITELIST=/usr/bin/crun" >>/etc/rkhunter.conf
            fi
            show_yellow "Updated Podman tools in RKHunter SCRIPTWHITELIST."
        fi

        # Update RKHunter file properties to include the new podman binaries
        show_yellow "Updating RKHunter file properties for Podman."
        rkhunter --propupd --cronjob >/dev/null 2>&1 || show_warn "RKHunter property update failed - this may cause warnings during scans."
    elif ! grep -q "^SCRIPTWHITELIST=/usr/bin/podman" /etc/rkhunter.conf; then
        # Add podman binaries to SCRIPTWHITELIST if not present
        echo "SCRIPTWHITELIST=/usr/bin/podman" >>/etc/rkhunter.conf
        echo "SCRIPTWHITELIST=/usr/bin/buildah" >>/etc/rkhunter.conf
        echo "SCRIPTWHITELIST=/usr/bin/crun" >>/etc/rkhunter.conf
        show_yellow "Podman tools added to RKHunter SCRIPTWHITELIST."

        # Update RKHunter file properties
        show_yellow "Updating RKHunter file properties for Podman."
        rkhunter --propupd --cronjob >/dev/null 2>&1 || show_warn "RKHunter property update failed - this may cause warnings during scans."
    else
        show_yellow "Podman already whitelisted in RKHunter configuration."
    fi
else
    show_yellow "RKHunter not detected. Skipping RKHunter configuration update."
fi

##########################################################################################
## Test installation
##########################################################################################

show_yellow "Testing Podman installation..."

# Test basic functionality
TEST_PASSED="false"

# First ensure the socket is running with proper environment
sudo -u "$PODMAN_USER" bash -c '
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    
    # Try to start socket if not running
    if ! systemctl --user is-active --quiet podman.socket; then
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user start podman.socket 2>/dev/null || true
        sleep 3
    fi
    
    # If socket still not working, try manual service
    if ! podman version >/dev/null 2>&1; then
        pkill -f "podman system service" 2>/dev/null || true
        podman system service --time=0 unix:///run/user/$(id -u)/podman/podman.sock &
        sleep 3
    fi
'

# Test hello-world container
if sudo -u "$PODMAN_USER" bash -c 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"; timeout 60 podman run --rm hello-world' >/dev/null 2>&1; then
    show_info "✅ Podman installation test successful"
    TEST_PASSED="true"
else
    show_warn "⚠️  Podman hello-world test failed - trying version check"
    # Try a simpler test
    if sudo -u "$PODMAN_USER" bash -c 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"; podman version' >/dev/null 2>&1; then
        show_info "✅ Podman version check successful"
        show_warn "Container execution may work after user session restart or reboot"
        TEST_PASSED="partial"
    else
        show_warn "❌ Podman basic functionality test failed"
        show_warn "Try running the fix script: ./utils/podman_fix.sh"
    fi
fi

# Test socket connectivity
show_yellow "Testing Podman socket..."
if sudo -u "$PODMAN_USER" bash -c 'export XDG_RUNTIME_DIR="/run/user/$(id -u)"; podman system connection list' >/dev/null 2>&1; then
    show_info "✅ Podman socket connectivity test successful"
else
    show_warn "⚠️  Podman socket test failed - service may start on first use"
fi

# Show installation summary
if [ "$TEST_PASSED" = "true" ]; then
    show_info "🎉 Podman installation completed successfully and tested!"
elif [ "$TEST_PASSED" = "partial" ]; then
    show_info "✅ Podman installation completed with minor issues"
else
    show_warn "⚠️  Podman installation completed but requires manual verification"
fi

##########################################################################################
## Final setup and information
##########################################################################################

show_yellow "Podman rootless installation completed for user: $PODMAN_USER"
show_info ""
show_info "📋 PODMAN USAGE INFORMATION:"
show_info "• Switch to podman user: sudo su - podman"
show_info "• Run commands as podman user: podman-user <command>"
show_info "• Check status: podman-status"
show_info "• Manage socket services: podman-socket <command>"
show_info "• Test installation: podman-user run --rm hello-world"
show_info ""
show_info "🌐 SOCKET ACTIVATION FOR CONTAINERS:"
show_info "• Socket activation preserves real client IP addresses"
show_info "• No NAT layer means applications see true user IPs in logs"
show_info "• Use systemd socket units for automatic container startup"
show_info "• Create socket-activated services with the helper script"
show_info "• Example socket activation setup:"
show_info "  sudo su - podman"
show_info "  ~/.config/containers/socket-setup.sh myapp 80 443"
show_info "• Then create myapp.container file in ~/.config/containers/systemd/"
show_info ""
show_info "🔧 CONFIGURATION FILES:"
show_info "• Containers config: /home/podman/.config/containers/containers.conf"
show_info "• Storage config: /home/podman/.config/containers/storage.conf"
show_info "• Socket setup script: /home/podman/.config/containers/socket-setup.sh"
show_info "• Systemd user units: /home/podman/.config/systemd/user/"
show_info "• Container units: /home/podman/.config/containers/systemd/"
show_info ""

##########################################################################################
## Podman detection helper function
##########################################################################################

check_podman_installed() {
    if command -v podman >/dev/null 2>&1 && id "$PODMAN_USER" &>/dev/null; then
        return 0 # Podman is installed with dedicated user
    else
        return 1 # Podman is not properly installed
    fi
}

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
