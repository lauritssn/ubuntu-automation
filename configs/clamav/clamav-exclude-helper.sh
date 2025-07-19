#!/bin/bash

# ClamAV False Positive Reduction Helper
# This script helps configure ClamAV exclusions based on your server setup

EXCLUDE_FILE="/etc/clamav/exclude.list"
CLAMAV_SCRIPT="/usr/local/bin/clamav-scan.sh"

echo "ClamAV False Positive Reduction Helper"
echo "======================================"

# Create exclude file if it doesn't exist
mkdir -p /etc/clamav
touch $EXCLUDE_FILE

echo "Current exclusions in $EXCLUDE_FILE:"
cat $EXCLUDE_FILE 2>/dev/null || echo "No exclusions configured"
echo ""

# Check for common software and suggest exclusions
echo "Checking for common software that may cause false positives..."

# Docker
if command -v docker &> /dev/null; then
    echo "✓ Docker detected - Consider excluding /var/lib/docker"
    if ! grep -q "/var/lib/docker" $EXCLUDE_FILE; then
        echo "Add Docker exclusion? (y/n): "
        read -r response
        if [[ $response == "y" ]]; then
            echo "/var/lib/docker" >> $EXCLUDE_FILE
            echo "Added Docker exclusion"
        fi
    fi
fi

# Node.js
if command -v node &> /dev/null; then
    echo "✓ Node.js detected - Consider excluding node_modules directories"
    echo "Note: Use --exclude-dir=**/node_modules in EXCLUDE_OPTS"
fi

# Snap packages
if command -v snap &> /dev/null; then
    echo "✓ Snap detected - Consider excluding /var/lib/snapd"
    if ! grep -q "/var/lib/snapd" $EXCLUDE_FILE; then
        echo "Add Snap exclusion? (y/n): "
        read -r response
        if [[ $response == "y" ]]; then
            echo "/var/lib/snapd" >> $EXCLUDE_FILE
            echo "Added Snap exclusion"
        fi
    fi
fi

# PostgreSQL
if command -v psql &> /dev/null; then
    echo "✓ PostgreSQL detected - Consider excluding database directories"
    echo "Common paths: /var/lib/postgresql"
fi

# MySQL/MariaDB
if command -v mysql &> /dev/null || command -v mariadb &> /dev/null; then
    echo "✓ MySQL/MariaDB detected - Consider excluding database directories"
    echo "Common paths: /var/lib/mysql"
fi

echo ""
echo "Manual exclusion options:"
echo "1. Edit $EXCLUDE_FILE directly"
echo "2. Modify EXCLUDE_OPTS in $CLAMAV_SCRIPT"
echo "3. Use --exclude-dir= and --exclude= patterns"
echo ""
echo "Example patterns to reduce false positives:"
echo "  --exclude=*.pid          (Process ID files)"
echo "  --exclude=*.lock         (Lock files)"
echo "  --exclude=*.sock         (Socket files)"
echo "  --exclude=core.*         (Core dumps)"
echo "  --exclude-dir=/proc      (Virtual filesystem)"
echo "  --exclude-dir=/sys       (Virtual filesystem)"
echo ""
echo "To apply exclusions, update the EXCLUDE_OPTS variable in:"
echo "  - $CLAMAV_SCRIPT"
echo "  - /usr/local/bin/clamav-scan.sh (if using systemd timers)" 