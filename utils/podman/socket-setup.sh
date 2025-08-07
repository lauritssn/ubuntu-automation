#!/bin/bash
# Socket setup script for Podman systemd socket-activated containers
# Creates IPv4 socket listeners (IPv6 commented out due to kernel limitations)
# Special handling for Traefik which requires separate socket files per entrypoint

# Default usage function
show_usage() {
    echo "Usage: $0 <service-name> <port> [additional-ports...]"
    echo "       $0 --help"
    echo ""
    echo "Creates systemd socket units for socket-activated containers"
    echo "Automatically creates IPv4 listeners for each port (IPv6 commented out)"
    echo ""
    echo "Special Traefik Support:"
    echo "  When service-name is 'traefik', creates separate socket files for each entrypoint:"
    echo "  - web.socket (port 80)"
    echo "  - websecure.socket (port 443)"
    echo "  - traefik.socket (port 8080)"
    echo ""
    echo "Arguments:"
    echo "  service-name     Name of the service/container"
    echo "  port            Primary port number"
    echo "  additional-ports Additional port numbers (optional)"
    echo ""
    echo "Examples:"
    echo "  $0 traefik 80 443 8080  # Creates separate web.socket, websecure.socket, traefik.socket"
    echo "  $0 nginx 80             # Creates single nginx.socket with port 80"
    echo "  $0 myapp 3000           # Creates single myapp.socket with port 3000"
    echo ""
    echo "Output:"
    echo "  Normal services: ~/.config/systemd/user/<service-name>.socket"
    echo "  Traefik: ~/.config/systemd/user/{web,websecure,traefik}.socket"
    echo "  Supports: IPv4 listeners for all specified ports (IPv6 commented out)"
    echo ""
    echo "Next steps after running this script:"
    echo "  Normal services:"
    echo "    1. Create <service-name>.container file in ~/.config/containers/systemd/"
    echo "    2. Run: systemctl --user daemon-reload"
    echo "    3. Run: systemctl --user enable <service-name>.socket"
    echo "    4. Run: systemctl --user start <service-name>.socket"
    echo ""
    echo "  Traefik:"
    echo "    1. Create traefik.container file in ~/.config/containers/systemd/"
    echo "    2. Run: systemctl --user daemon-reload"
    echo "    3. Run: systemctl --user enable web.socket websecure.socket traefik.socket"
    echo "    4. Run: systemctl --user start web.socket websecure.socket traefik.socket"
}

# Check for help flag
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_usage
    exit 0
fi

# Validate arguments
if [ $# -lt 2 ]; then
    echo "Error: Insufficient arguments"
    echo ""
    show_usage
    exit 1
fi

SERVICE_NAME="$1"
shift
PORTS=("$@")

# Validate service name (only alphanumeric, hyphens, underscores)
if [[ ! "$SERVICE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Service name '$SERVICE_NAME' contains invalid characters"
    echo "Only alphanumeric characters, hyphens, and underscores are allowed"
    exit 1
fi

# Validate ports
for port in "${PORTS[@]}"; do
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo "Error: Invalid port number '$port'"
        echo "Port must be a number between 1 and 65535"
        exit 1
    fi
done

# Ensure we're running as the podman user
if [ "$(whoami)" != "podman" ]; then
    echo "Error: This script must be run as the podman user"
    echo "Use: sudo su - podman"
    echo "Then run: $0 $SERVICE_NAME ${PORTS[*]}"
    exit 1
fi

# Set up environment
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# Create systemd user directory if it doesn't exist
mkdir -p ~/.config/systemd/user

# Function to create a single socket file
create_socket_file() {
    local socket_name="$1"
    local port="$2"
    local description="$3"

    local socket_file="$HOME/.config/systemd/user/${socket_name}.socket"

    echo "Creating socket unit: $socket_file"

    cat >"$socket_file" <<EOF
[Unit]
Description=$description

[Socket]
ListenStream=0.0.0.0:$port
# ListenStream=[::]:$port # IPv6 will not work
FreeBind=true

[Install]
WantedBy=sockets.target
EOF
}

# Special handling for Traefik
if [ "$SERVICE_NAME" = "traefik" ]; then
    echo "🎯 Detected Traefik - creating single socket with multiple entrypoints"
    echo ""

    # Validate that we have exactly the expected ports for Traefik
    if [ ${#PORTS[@]} -ne 3 ]; then
        echo "Warning: Traefik typically uses 3 ports (80, 443, 8080)"
        echo "You provided: ${PORTS[*]}"
        echo "Continuing with provided ports..."
        echo ""
    fi

    # Create the single Traefik socket file
    SOCKET_FILE="$HOME/.config/systemd/user/traefik.socket"

    echo "Creating socket unit: $SOCKET_FILE"

    cat >"$SOCKET_FILE" <<EOF
[Unit]
Description=Traefik socket activation

[Socket]
ListenStream=0.0.0.0:80
ListenStream=0.0.0.0:443
ListenStream=0.0.0.0:8080
FileDescriptorName=web
FreeBind=true

[Install]
WantedBy=sockets.target
EOF

    echo ""
    echo "✅ Traefik socket unit created successfully!"
    echo ""
    echo "Socket configuration:"
    echo "- Service: $SERVICE_NAME"
    echo "- Ports: ${PORTS[*]} (using 80, 443, 8080 for optimal configuration)"
    echo "- Socket file: traefik.socket"
    echo "- FileDescriptorName: web"
    echo "- IPv4 listeners created for all ports"
    echo ""
    echo "📋 Next steps:"
    echo "1. Create container unit file:"
    echo "   ~/.config/containers/systemd/traefik.container"
    echo "   (Make sure After=traefik.socket and Requires=traefik.socket)"
    echo ""
    echo "2. Reload systemd configuration:"
    echo "   systemctl --user daemon-reload"
    echo ""
    echo "3. Enable the socket service:"
    echo "   systemctl --user enable traefik.socket"
    echo ""
    echo "   Note: Do NOT enable traefik.service - it will be auto-generated"
    echo ""
    echo "4. Start the socket listener:"
    echo "   systemctl --user start traefik.socket"
    echo ""
    echo "5. Verify socket status:"
    echo "   systemctl --user status traefik.socket"
    echo ""
    echo "ℹ️  The container will start automatically when the first connection arrives"
    echo "   on any of the configured ports (80, 443, 8080)."

else
    # Standard single-socket approach for non-Traefik services
    echo "Creating standard socket configuration for $SERVICE_NAME"
    echo ""

    # Create the socket unit file
    SOCKET_FILE="$HOME/.config/systemd/user/${SERVICE_NAME}.socket"

    echo "Creating socket unit: $SOCKET_FILE"

    cat >"$SOCKET_FILE" <<EOF
[Unit]
Description=$SERVICE_NAME socket

[Socket]
EOF

    # Add listening addresses for each port (IPv4 only, IPv6 commented out)
    for port in "${PORTS[@]}"; do
        echo "ListenStream=0.0.0.0:$port" >>"$SOCKET_FILE"
        echo "# ListenStream=[::]:$port # IPv6 will not work" >>"$SOCKET_FILE"
    done

    # Add FreeBind for socket reliability
    echo "FreeBind=true" >>"$SOCKET_FILE"

    # Add Install section
    cat >>"$SOCKET_FILE" <<EOF

[Install]
WantedBy=sockets.target
EOF

    echo ""
    echo "✅ Socket unit created successfully: $SOCKET_FILE"
    echo ""
    echo "Socket configuration:"
    echo "- Service: $SERVICE_NAME"
    echo "- Ports: ${PORTS[*]}"
    echo "- IPv4 listeners created for each port (IPv6 commented out)"
    echo ""
    echo "📋 Next steps:"
    echo "1. Create container unit file:"
    echo "   ~/.config/containers/systemd/$SERVICE_NAME.container"
    echo ""
    echo "2. Reload systemd configuration:"
    echo "   systemctl --user daemon-reload"
    echo ""
    echo "3. Enable the socket service:"
    echo "   systemctl --user enable $SERVICE_NAME.socket"
    echo ""
    echo "   Note: Do NOT enable $SERVICE_NAME.service - it will be auto-generated"
    echo ""
    echo "4. Start the socket listener:"
    echo "   systemctl --user start $SERVICE_NAME.socket"
    echo ""
    echo "5. Verify socket status:"
    echo "   systemctl --user status $SERVICE_NAME.socket"
    echo ""
    echo "ℹ️  The container will start automatically when the first connection arrives"
    echo "   on any of the configured ports."
fi
