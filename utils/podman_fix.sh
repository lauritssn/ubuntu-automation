#!/bin/bash

##########################################################################################
## Podman Installation Fix Script
##########################################################################################

echo "🔧 Fixing Podman installation issues..."

PODMAN_USER="podman"

##########################################################################################
## Fix 1: Fix storage.conf TOML syntax error
##########################################################################################

echo "📝 Fixing storage.conf syntax error..."

# Create corrected storage.conf
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

echo "✅ Fixed storage.conf syntax"

##########################################################################################
## Fix 2: Fix podman-user script permissions and functionality
##########################################################################################

echo "🔧 Fixing podman-user script..."

# Create improved podman-user script
cat > /usr/local/bin/podman-user << 'EOF'
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

echo "✅ Fixed podman-user script permissions and functionality"

##########################################################################################
## Fix 3: Initialize Podman properly
##########################################################################################

echo "🚀 Initializing Podman properly..."

sudo -u "$PODMAN_USER" bash -c '
    # Set proper environment
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    
    # Create runtime directory if it doesn't exist
    mkdir -p "$XDG_RUNTIME_DIR/podman"
    
    # Generate systemd user directory
    mkdir -p ~/.config/systemd/user
    
    # Initialize podman to create necessary files
    podman system migrate 2>/dev/null || true
    
    # Reload systemd user daemon
    systemctl --user daemon-reload 2>/dev/null || true
    
    # Stop any running services first
    systemctl --user stop podman.socket 2>/dev/null || true
    pkill -f "podman system service" 2>/dev/null || true
    
    # Start podman socket
    if systemctl --user start podman.socket 2>/dev/null; then
        systemctl --user enable podman.socket 2>/dev/null || true
        echo "✅ Podman socket started successfully"
        
        # Test connectivity
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
## Fix 4: Update podman-status script
##########################################################################################

echo "📊 Updating podman-status script..."

cat > /usr/local/bin/podman-status << 'EOF'
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

echo "✅ Updated podman-status script"

##########################################################################################
## Test the fixes
##########################################################################################

echo ""
echo "🧪 Testing fixes..."

# Test podman-user script
echo "Testing podman-user version command..."
if podman-user version >/dev/null 2>&1; then
    echo "✅ podman-user script works!"
else
    echo "⚠️ podman-user script still has issues"
fi

# Test basic functionality
echo "Testing hello-world container..."
if timeout 30 podman-user run --rm hello-world >/dev/null 2>&1; then
    echo "🎉 Hello-world test successful!"
else
    echo "⚠️ Hello-world test failed - may need user session restart"
fi

echo ""
echo "🔧 Podman fixes completed!"
echo ""
echo "📋 Next steps:"
echo "• Test with: podman-user version"
echo "• Check status: podman-status"
echo "• Test container: podman-user run --rm hello-world"
echo ""
echo "If issues persist, try:"
echo "• Reboot the system"
echo "• Or run: sudo loginctl enable-linger podman"