# Docker Removal Guide

This guide provides comprehensive instructions for completely removing Docker from Ubuntu 24.04 systems that were installed using the `docker_install.sh` script from this automation suite.

## ⚠️ WARNING

**Before proceeding:**

- **Backup all important containers and data** - This process will permanently remove all Docker containers, images, volumes, and networks
- **Stop all running containers** - Ensure no critical services are running in Docker
- **Document container configurations** - You may need to recreate containers later

## 🔍 Detect Installation Type

First, determine how Docker was installed on your system:

```bash
# Check if Docker is installed in rootless mode
if systemctl --user is-enabled docker.service 2>/dev/null || [ -f ~/.config/systemd/user/docker.service ]; then
    echo "Docker rootless installation detected"
elif systemctl is-enabled docker.service 2>/dev/null; then
    echo "Standard Docker installation detected"
else
    echo "Docker installation type unclear - check both methods"
fi
```

## 📋 Pre-Removal Checklist

### 1. List All Docker Resources

```bash
# List running containers
docker ps -a

# List images
docker images -a

# List volumes
docker volume ls

# List networks
docker network ls
```

### 2. Backup Important Data

```bash
# Backup container data (example)
docker cp container_name:/path/to/data ./backup/

# Export container configurations
docker inspect container_name > container_name_config.json

# Save images (if needed)
docker save -o image_name.tar image_name:tag
```

### 3. Stop All Containers

```bash
# Stop all running containers
docker stop $(docker ps -q) 2>/dev/null || true

# Remove all containers
docker rm $(docker ps -aq) 2>/dev/null || true
```

## 🗑️ Standard Docker Removal

For systems with standard (system-level) Docker installation:

### Step 1: Stop Docker Services

```bash
sudo systemctl stop docker.service
sudo systemctl stop docker.socket
sudo systemctl disable docker.service
sudo systemctl disable docker.socket
```

### Step 2: Remove Docker Packages

```bash
# Remove Docker packages installed by docker_install.sh
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Remove dependencies that may no longer be needed
sudo apt-get autoremove -y
```

### Step 3: Remove Docker Repository and GPG Key

```bash
# Remove Docker repository
sudo rm -f /etc/apt/sources.list.d/docker.list

# Remove Docker GPG key
sudo rm -f /etc/apt/keyrings/docker.asc

# Update package cache
sudo apt-get update
```

### Step 4: Remove Docker Data and Configuration

```bash
# Remove Docker data directory (default location)
sudo rm -rf /var/lib/docker

# Remove custom Docker data directory (if configured)
# Check /etc/docker/daemon.json for custom data-root path
if [ -f /etc/docker/daemon.json ]; then
    CUSTOM_ROOT=$(grep -o '"data-root"[[:space:]]*:[[:space:]]*"[^"]*"' /etc/docker/daemon.json | cut -d'"' -f4)
    if [ -n "$CUSTOM_ROOT" ] && [ "$CUSTOM_ROOT" != "/var/lib/docker" ]; then
        echo "Removing custom Docker data directory: $CUSTOM_ROOT"
        sudo rm -rf "$CUSTOM_ROOT"
    fi
fi

# Remove Docker configuration
sudo rm -rf /etc/docker

# Remove containerd data
sudo rm -rf /var/lib/containerd
```

### Step 5: Remove Docker Compose Symlink

```bash
# Remove docker-compose symlink created by installation script
sudo rm -f /usr/local/bin/docker-compose
```

### Step 6: Clean Up User Groups

```bash
# Remove users from docker group (replace 'username' with actual usernames)
# Check who is in the docker group first
getent group docker

# Remove users from docker group
sudo gpasswd -d username docker

# Remove the docker group entirely
sudo groupdel docker 2>/dev/null || true
```

## 🏠 Rootless Docker Removal

For systems with rootless Docker installation:

### Step 1: Identify Rootless User

```bash
# Find users with rootless Docker setup
grep -l "DOCKER_HOST.*docker.sock" /home/*/.*bashrc 2>/dev/null || true

# Check for dedicated Docker user (common names: dockerrootless)
id dockerrootless 2>/dev/null && echo "Dedicated Docker user found: dockerrootless"
```

### Step 2: Stop Rootless Docker Services

```bash
# For each user with rootless Docker (replace 'username' with actual username)
sudo -u username systemctl --user stop docker.service 2>/dev/null || true
sudo -u username systemctl --user stop docker.socket 2>/dev/null || true
sudo -u username systemctl --user disable docker.service 2>/dev/null || true
sudo -u username systemctl --user disable docker.socket 2>/dev/null || true

# If using dedicated dockerrootless user:
sudo -u dockerrootless systemctl --user stop docker.service 2>/dev/null || true
sudo -u dockerrootless systemctl --user stop docker.socket 2>/dev/null || true
sudo -u dockerrootless systemctl --user disable docker.service 2>/dev/null || true
sudo -u dockerrootless systemctl --user disable docker.socket 2>/dev/null || true
```

### Step 3: Remove Rootless Docker Installation

```bash
# For each rootless user, uninstall rootless Docker
sudo -u username dockerd-rootless-setuptool.sh uninstall 2>/dev/null || true

# If using dedicated dockerrootless user:
sudo -u dockerrootless dockerd-rootless-setuptool.sh uninstall 2>/dev/null || true
```

### Step 4: Remove User Data and Configuration

```bash
# Remove rootless Docker data for each user
sudo rm -rf /home/username/.local/share/docker
sudo rm -rf /home/username/.config/docker

# For dedicated dockerrootless user:
sudo rm -rf /home/dockerrootless/.local/share/docker
sudo rm -rf /home/dockerrootless/.config/docker
```

### Step 5: Clean Up User Environment

```bash
# Remove Docker environment variables from user's bashrc
sudo -u username sed -i '/export.*DOCKER_HOST.*docker\.sock/d' ~/.bashrc 2>/dev/null || true
sudo -u username sed -i '/export PATH.*\/usr\/bin/d' ~/.bashrc 2>/dev/null || true

# For dedicated dockerrootless user:
sudo -u dockerrootless sed -i '/export.*DOCKER_HOST.*docker\.sock/d' ~/.bashrc 2>/dev/null || true
sudo -u dockerrootless sed -i '/export PATH.*\/usr\/bin/d' ~/.bashrc 2>/dev/null || true
```

### Step 6: Remove Dedicated User (Optional)

```bash
# Only if you used a dedicated dockerrootless user and want to remove it completely
sudo userdel -r dockerrootless 2>/dev/null || true

# Disable lingering for the user
sudo loginctl disable-linger dockerrootless 2>/dev/null || true
```

### Step 7: Remove System Packages

```bash
# Remove packages (same as standard installation)
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo apt-get purge -y uidmap dbus-user-session  # Rootless-specific dependencies
sudo apt-get autoremove -y
```

### Step 8: Remove Repository and Keys

```bash
# Same as standard installation
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /etc/apt/keyrings/docker.asc
sudo apt-get update
```

## 🛡️ RKHunter Configuration Cleanup

If RKHunter is installed, clean up Docker-related whitelist entries:

```bash
# Check if RKHunter is installed
if command -v rkhunter >/dev/null 2>&1 && [ -f /etc/rkhunter.conf ]; then
    echo "Cleaning up RKHunter configuration..."

    # Remove Docker whitelist entries
    sudo sed -i '/^SCRIPTWHITELIST=\/usr\/bin\/docker$/d' /etc/rkhunter.conf

    # Update RKHunter file properties
    sudo rkhunter --propupd --cronjob >/dev/null 2>&1 || echo "RKHunter property update completed"

    echo "RKHunter configuration cleaned up"
else
    echo "RKHunter not installed - skipping cleanup"
fi
```

## 🧹 Additional System Cleanup

### Remove Temporary Files

```bash
# Remove any temporary Docker-related files
sudo rm -rf /tmp/docker-*
sudo rm -rf /tmp/get-docker.sh

# Clean up systemd
sudo systemctl daemon-reload
sudo systemctl reset-failed
```

### Clean Package Cache

```bash
# Clean up package cache
sudo apt-get clean
sudo apt-get autoclean
```

### Remove Runtime Directories

```bash
# Remove runtime directories (will be recreated if needed)
sudo rm -rf /run/docker
sudo rm -rf /run/containerd

# For rootless installations, check user runtime dirs
sudo rm -rf /run/user/*/docker 2>/dev/null || true
```

## ✅ Verification

Verify that Docker has been completely removed:

```bash
# Check if Docker commands are available
command -v docker && echo "❌ Docker still installed" || echo "✅ Docker removed"
command -v docker-compose && echo "❌ Docker Compose still installed" || echo "✅ Docker Compose removed"

# Check for running services
systemctl is-active docker.service 2>/dev/null && echo "❌ Docker service still running" || echo "✅ Docker service stopped"

# Check for Docker files
[ -d /var/lib/docker ] && echo "❌ Docker data directory still exists" || echo "✅ Docker data directory removed"
[ -f /etc/docker/daemon.json ] && echo "❌ Docker config still exists" || echo "✅ Docker config removed"

# Check for Docker group
getent group docker >/dev/null 2>&1 && echo "❌ Docker group still exists" || echo "✅ Docker group removed"

# Check for repository
[ -f /etc/apt/sources.list.d/docker.list ] && echo "❌ Docker repository still configured" || echo "✅ Docker repository removed"
```

## 🔄 Reinstallation

If you need to reinstall Docker later:

```bash
# Run the docker installation script again
cd /path/to/ubuntu-automation
sudo ./subscripts/docker_install.sh

# Or run the full installation with Docker enabled
sudo ./install.sh
# Answer 'Y' when prompted for Docker installation
```

## 📚 Additional Notes

### Data Recovery

- If you need to recover data after removal, check system backups
- Container volumes may have been stored in `/var/lib/docker/volumes/` (standard) or `~/.local/share/docker/volumes/` (rootless)

### Selective Removal

- You can choose to keep certain components (like just removing containers but keeping images)
- Modify the removal steps accordingly based on your needs

### Network Cleanup

- Some Docker networks may have modified iptables rules
- Restart the system or reload iptables if you experience network issues after removal

## 🆘 Troubleshooting

### Common Issues

**Permission Denied Errors:**

```bash
# Ensure you're running commands with appropriate privileges
sudo -i  # Switch to root for system cleanup
```

**Services Won't Stop:**

```bash
# Force stop services
sudo systemctl kill docker.service
sudo systemctl kill docker.socket
sudo pkill -f docker
```

**Files Won't Delete:**

```bash
# Check for active mounts
mount | grep docker
# Unmount if necessary
sudo umount /var/lib/docker/*/
```

**Rootless Issues:**

```bash
# Check user's systemd services
sudo -u username systemctl --user list-units | grep docker
# Clean up user systemd
sudo -u username systemctl --user daemon-reload
```

---

**⚠️ Remember:** This is a complete removal process. Make sure you have backed up any important data before proceeding!
