#!/bin/bash

##########################################################################################
## Set variables
##########################################################################################
DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="wireguard_install.sh"

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
## Install Wireguard
##########################################################################################

show_yellow "Installing Wireguard."

# Fix potential APT cache corruption issues
show_yellow "Cleaning APT cache to prevent corruption issues."
rm -rf /var/cache/apt/archives/partial/* >>$LOGDIR/$LOGFILE 2>&1
rm -rf /var/lib/apt/lists/* >>$LOGDIR/$LOGFILE 2>&1
apt-get clean >>$LOGDIR/$LOGFILE 2>&1

# Update package lists with retries
show_yellow "Updating package lists."
for i in {1..3}; do
    if apt-get --yes update >>$LOGDIR/$LOGFILE 2>&1; then
        show_yellow "Package lists updated successfully."
        break
    else
        show_yellow "Package update attempt $i failed, cleaning cache and retrying..."
        apt-get clean >>$LOGDIR/$LOGFILE 2>&1
        rm -rf /var/lib/apt/lists/* >>$LOGDIR/$LOGFILE 2>&1
        if [ $i -eq 3 ]; then
            show_err "Failed to update package lists after 3 attempts. Please check logfile and fix error manually."
            exit 100
        fi
        sleep 2
    fi
done

# Install Wireguard packages
show_yellow "Installing Wireguard packages."
apt-get --yes install wireguard wireguard-tools qrencode >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Installation of Wireguard failed. Please check logfile and fix error manually." && exit 100)

show_yellow "Wireguard packages installed successfully."

##########################################################################################
## Generate server keys
##########################################################################################

show_yellow "Generating Wireguard server keys."

# Create wireguard directory
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

# Generate server private and public keys
cd /etc/wireguard
wg genkey | tee server_private_key | wg pubkey > server_public_key
chmod 600 server_private_key
chmod 644 server_public_key

SERVER_PRIVATE_KEY=$(cat server_private_key)
SERVER_PUBLIC_KEY=$(cat server_public_key)

show_yellow "Server keys generated."

##########################################################################################
## Create server configuration
##########################################################################################

show_yellow "Creating Wireguard server configuration."

# Extract network details from subnet
WG_NETWORK=$(echo $WIREGUARD_SUBNET | cut -d'/' -f1)
WG_CIDR=$(echo $WIREGUARD_SUBNET | cut -d'/' -f2)
WG_SERVER_IP="${WG_NETWORK%.*}.1"

# Get the default network interface
DEFAULT_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

# Create server configuration
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = $WG_SERVER_IP/$WG_CIDR
ListenPort = 51820
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $DEFAULT_INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $DEFAULT_INTERFACE -j MASQUERADE

# Client configurations will be added here
EOF

chmod 600 /etc/wireguard/wg0.conf

show_yellow "Server configuration created."

##########################################################################################
## Enable IP forwarding
##########################################################################################

show_yellow "Enabling IP forwarding."

# Enable IP forwarding permanently
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf

# Apply immediately
sysctl -p >>$LOGDIR/$LOGFILE 2>&1

show_yellow "IP forwarding enabled."

##########################################################################################
## Create client management functions
##########################################################################################

show_yellow "Creating client management utilities."

# Create client generation script
cat > /etc/wireguard/add_client.sh << 'EOF'
#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <client_name>"
    exit 1
fi

CLIENT_NAME=$1
CLIENT_IP_NUM=$(( $(wg show wg0 peers | wc -l) + 2 ))
WG_SERVER_IP=$(grep Address /etc/wireguard/wg0.conf | awk '{print $3}' | cut -d'/' -f1)
WG_CIDR=$(grep Address /etc/wireguard/wg0.conf | awk '{print $3}' | cut -d'/' -f2)
WG_NETWORK_BASE=$(echo $WG_SERVER_IP | cut -d'.' -f1-3)
CLIENT_IP="$WG_NETWORK_BASE.$CLIENT_IP_NUM"
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/server_public_key)
SERVER_ENDPOINT="$(curl -s ifconfig.me):51820"

# Generate client keys
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

# Add client to server config
echo "" >> /etc/wireguard/wg0.conf
echo "# Client: $CLIENT_NAME" >> /etc/wireguard/wg0.conf
echo "[Peer]" >> /etc/wireguard/wg0.conf
echo "PublicKey = $CLIENT_PUBLIC_KEY" >> /etc/wireguard/wg0.conf
echo "AllowedIPs = $CLIENT_IP/32" >> /etc/wireguard/wg0.conf

# Create client config file
cat > /etc/wireguard/clients/${CLIENT_NAME}.conf << EOL
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/$WG_CIDR
DNS = $WG_SERVER_IP

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_ENDPOINT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 21
EOL

# Generate QR code for mobile clients
qrencode -t ansiutf8 < /etc/wireguard/clients/${CLIENT_NAME}.conf

echo "Client $CLIENT_NAME added successfully!"
echo "Config file: /etc/wireguard/clients/${CLIENT_NAME}.conf"
echo "Client IP: $CLIENT_IP"

# Restart Wireguard to apply changes
systemctl restart wg-quick@wg0

EOF

chmod +x /etc/wireguard/add_client.sh

# Create clients directory
mkdir -p /etc/wireguard/clients
chmod 700 /etc/wireguard/clients

show_yellow "Client management utilities created."

##########################################################################################
## Enable and start Wireguard
##########################################################################################

show_yellow "Starting Wireguard service."

systemctl enable wg-quick@wg0 >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Enabling Wireguard service failed. Please check logfile and fix error manually.")
systemctl start wg-quick@wg0 >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Starting Wireguard service failed. Please check logfile and fix error manually.")

show_yellow "Wireguard service started successfully."

##########################################################################################
## Create global WireGuard management scripts
##########################################################################################

show_yellow "Creating global WireGuard management scripts."

# Create global add-wg-client script
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

# Create global remove-wg-client script
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

show_yellow "Global WireGuard management scripts created."

##########################################################################################
## Display setup information
##########################################################################################

show_yellow "Wireguard setup completed!"
show_info "Server public key: $SERVER_PUBLIC_KEY"
show_info "Server IP: $WG_SERVER_IP/$WG_CIDR"
show_info "To add clients, run: add-wg-client <client_name>"
show_info "To remove clients, run: remove-wg-client <client_name>"

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."