#!/bin/bash

##########################################################################################
## Modern Ubuntu 24.04 Swap Implementation
##########################################################################################

##########################################################################################
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="swap_install.sh"

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
## Detect system RAM and calculate optimal swap size
##########################################################################################

show_yellow "Analyzing system memory to determine optimal swap configuration."

# Get RAM in GB
RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
RAM_MB=$(free -m | awk '/^Mem:/{print $2}')

show_info "Detected system RAM: ${RAM_GB}GB (${RAM_MB}MB)"

# Calculate optimal swap size for 4-16GB RAM servers
if [ $RAM_GB -le 4 ]; then
    # 4GB or less: Equal to RAM for safety
    SWAP_SIZE_GB=$RAM_GB
    SWAP_REASON="Equal to RAM for memory safety"
elif [ $RAM_GB -le 8 ]; then
    # 4-8GB: Equal to RAM for good balance
    SWAP_SIZE_GB=$RAM_GB
    SWAP_REASON="Equal to RAM for optimal balance"
elif [ $RAM_GB -le 16 ]; then
    # 8-16GB: 4-6GB for safety buffer
    SWAP_SIZE_GB=6
    SWAP_REASON="6GB safety buffer for high-RAM system"
else
    # >16GB: 4GB minimal emergency buffer
    SWAP_SIZE_GB=4
    SWAP_REASON="4GB emergency buffer for high-memory system"
fi

show_info "Calculated optimal swap size: ${SWAP_SIZE_GB}GB"
show_info "Reasoning: $SWAP_REASON"

##########################################################################################
## Check if ZRAM is active (Ubuntu 24.04 default)
##########################################################################################

show_yellow "Checking Ubuntu 24.04 ZRAM configuration."

if command -v zramctl >/dev/null 2>&1 && zramctl | grep -q "/dev/zram"; then
    ZRAM_SIZE=$(zramctl | grep "/dev/zram0" | awk '{print $3}' || echo "unknown")
    show_info "ZRAM detected and active: $ZRAM_SIZE"
    show_info "ZRAM provides compressed memory, reducing swap pressure."
else
    show_warn "ZRAM not detected. Traditional swap will be primary memory overflow."
fi

##########################################################################################
## Remove existing swap if present
##########################################################################################

show_yellow "Checking for existing swap configuration."

# Check for existing swap files and partitions
EXISTING_SWAP=$(swapon --show --noheadings | awk '{print $1}')

if [ -n "$EXISTING_SWAP" ]; then
    show_info "Found existing swap: $EXISTING_SWAP"
    
    # Turn off existing swap
    for swap_device in $EXISTING_SWAP; do
        if [[ "$swap_device" == "/var/tmp/swapfile" || "$swap_device" == "/swapfile" ]]; then
            show_yellow "Disabling existing swap file: $swap_device"
            swapoff "$swap_device" >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to disable $swap_device"
            
            # Remove old swap file if it exists
            if [ -f "$swap_device" ]; then
                rm -f "$swap_device"
                show_yellow "Removed old swap file: $swap_device"
            fi
        fi
    done
fi

##########################################################################################
## Create modern swap file using fallocate
##########################################################################################

SWAPFILE="/swapfile"
show_yellow "Creating ${SWAP_SIZE_GB}GB swap file at $SWAPFILE using modern method."

# Try fallocate first (fastest method)
if fallocate -l ${SWAP_SIZE_GB}G "$SWAPFILE" 2>>$LOGDIR/$LOGFILE; then
    show_yellow "Swap file created using fallocate (fast allocation)."
else
    show_warn "fallocate failed, falling back to dd method."
    # Fallback to dd if fallocate fails
    dd if=/dev/zero of="$SWAPFILE" bs=1M count=$((SWAP_SIZE_GB * 1024)) >>$LOGDIR/$LOGFILE 2>&1 || {
        show_err "Failed to create swap file with dd. Please check disk space."
        exit 1
    }
    show_yellow "Swap file created using dd (slower but compatible)."
fi

##########################################################################################
## Set secure permissions and create swap
##########################################################################################

show_yellow "Securing swap file and initializing swap space."

# Set secure permissions (only root access)
chmod 600 "$SWAPFILE" || {
    show_err "Failed to set swap file permissions."
    exit 1
}

# Initialize swap space (modern Ubuntu 24.04 format)
mkswap "$SWAPFILE" >>$LOGDIR/$LOGFILE 2>&1 || {
    show_err "Failed to initialize swap space."
    exit 1
}

# Enable swap file
swapon "$SWAPFILE" >>$LOGDIR/$LOGFILE 2>&1 || {
    show_err "Failed to enable swap file."
    exit 1
}

show_yellow "Swap file created and activated successfully."

##########################################################################################
## Update fstab for persistent swap
##########################################################################################

show_yellow "Configuring persistent swap in /etc/fstab."

FSTAB_ENTRY="$SWAPFILE none swap sw 0 0"

# Backup fstab
CONF_ORG=/etc/fstab
CONF_BACK=$BACKUPDIR/$(basename $CONF_ORG)_$DATE

if [ -f $CONF_ORG ]; then
    cp -p $CONF_ORG $CONF_BACK && show_yellow "fstab backed up to $CONF_BACK."
fi

# Remove any old swap entries for our swap files
sed -i '\|/var/tmp/swapfile|d' $CONF_ORG
sed -i '\|/swapfile|d' $CONF_ORG

# Add new swap entry
echo "$FSTAB_ENTRY" >> $CONF_ORG
show_yellow "Added swap entry to fstab: $FSTAB_ENTRY"

##########################################################################################
## Configure optimal swappiness for Ubuntu 24.04 servers
##########################################################################################

show_yellow "Configuring optimal swappiness for Ubuntu 24.04 servers."

SYSCTL_CONF="/etc/sysctl.conf"
SYSCTL_BACK="$BACKUPDIR/$(basename $SYSCTL_CONF)_$DATE"

# Backup sysctl.conf
if [ -f $SYSCTL_CONF ]; then
    cp -p $SYSCTL_CONF $SYSCTL_BACK && show_yellow "sysctl.conf backed up to $SYSCTL_BACK."
fi

# Remove old swappiness settings
sed -i '/vm.swappiness/d' $SYSCTL_CONF

# Configure optimal settings for servers with ZRAM + traditional swap
cat >> $SYSCTL_CONF << 'EOF'

# Ubuntu 24.04 Server Memory Management Optimization
# Swappiness: Balance between ZRAM and traditional swap
vm.swappiness=60

# VFS cache pressure: Favor keeping directory/inode cache in memory
vm.vfs_cache_pressure=50

# Dirty ratio: Control when dirty pages are written to disk
vm.dirty_ratio=15
vm.dirty_background_ratio=5

# Memory overcommit: Conservative for servers
vm.overcommit_memory=1
vm.overcommit_ratio=50
EOF

# Apply settings immediately
sysctl -p >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Failed to apply sysctl settings."

show_yellow "Memory management parameters optimized for Ubuntu 24.04 servers."

##########################################################################################
## Display swap status and configuration
##########################################################################################

show_yellow "=== Swap Configuration Summary ==="
show_info "Total System Memory: ${RAM_MB}MB"
show_info "Created Swap Size: ${SWAP_SIZE_GB}GB"
show_info "Swap File Location: $SWAPFILE"
show_info "Swappiness Setting: 60 (server-optimized)"

show_yellow "=== Current Swap Status ==="
swapon --show
echo ""
show_yellow "=== Memory + Swap Overview ==="
free -h

##########################################################################################
## Setup swap monitoring
##########################################################################################

show_yellow "Setting up swap usage monitoring."

# Create swap monitoring script (to be scheduled via systemd timers)
cat > $SCRIPTSDIR/check_swap_usage.sh << 'EOF'
#!/bin/bash

# Swap Usage Monitor for Ubuntu 24.04
# Alerts when swap usage exceeds thresholds

SWAP_WARN_THRESHOLD=25  # Warning at 25% swap usage
SWAP_CRIT_THRESHOLD=50  # Critical at 50% swap usage

# Get current swap usage percentage
SWAP_TOTAL=$(free | grep Swap | awk '{print $2}')
SWAP_USED=$(free | grep Swap | awk '{print $3}')

if [ "$SWAP_TOTAL" -gt 0 ]; then
    SWAP_PERCENT=$((SWAP_USED * 100 / SWAP_TOTAL))
    
    if [ "$SWAP_PERCENT" -ge "$SWAP_CRIT_THRESHOLD" ]; then
        echo "CRITICAL: Swap usage at ${SWAP_PERCENT}% - Consider adding more RAM"
        logger -p user.crit "High swap usage: ${SWAP_PERCENT}%"
    elif [ "$SWAP_PERCENT" -ge "$SWAP_WARN_THRESHOLD" ]; then
        echo "WARNING: Swap usage at ${SWAP_PERCENT}% - Monitor memory usage"
        logger -p user.warn "Elevated swap usage: ${SWAP_PERCENT}%"
    fi
else
    echo "No swap configured or available"
fi
EOF

chmod +x $SCRIPTSDIR/check_swap_usage.sh
show_yellow "Swap monitoring script created at $SCRIPTSDIR/check_swap_usage.sh"

##########################################################################################
## Done
##########################################################################################

show_info "=== Modern Ubuntu 24.04 Swap Configuration Complete ==="
show_info "Your server now has optimal memory protection:"
show_info "• ZRAM: Compresses inactive pages in memory (if available)"
show_info "• Traditional Swap: ${SWAP_SIZE_GB}GB safety buffer on disk"
show_info "• Monitoring: Check swap usage with $SCRIPTSDIR/check_swap_usage.sh"
show_info "• Memory pressure is handled gracefully with minimal performance impact"

show_info "$SUBSCRIPT done."