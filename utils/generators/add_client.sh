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
DNS = 1.1.1.1

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