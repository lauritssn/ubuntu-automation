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
## Netdata Real-time Monitoring Installation
##########################################################################################
##
## This script installs Netdata via apt-get, which modifies the following Ubuntu system files:
##
## CREATED/INSTALLED FILES:
## - /etc/netdata/                         - Main configuration directory
##   ├── netdata.conf                      - Primary Netdata configuration file
##   ├── apps_groups.conf                  - Application grouping configuration
##   ├── charts.d.conf                     - External plugin configuration
##   ├── fping.conf                        - Network latency monitoring configuration
##   ├── health.d/                         - Health monitoring alerts directory
##   ├── python.d.conf                     - Python plugin configuration
##   ├── statsd.d/                         - StatsD configuration directory
##   ├── stream.conf                       - Streaming configuration
##   └── web_log.conf                      - Web log analysis configuration
##
## - /var/lib/netdata/                     - Database and runtime data directory
##   ├── registry/                         - Web registry data
##   ├── cloud.d/                          - Cloud integration data
##   └── cache/                            - Database files and metrics cache
##
## - /var/cache/netdata/                   - Cache directory for temporary files
##
## - /var/log/netdata/                     - Log files directory
##   ├── error.log                         - Main error log
##   ├── access.log                        - Web access log
##   ├── debug.log                         - Debug information log
##   └── collector.log                     - Data collection log
##
## - /usr/sbin/netdata                     - Main Netdata daemon executable
## - /usr/libexec/netdata/                 - Netdata plugins and helper binaries
## - /usr/share/netdata/                   - Web interface files and documentation
##
## SYSTEMD INTEGRATION:
## - /etc/systemd/system/netdata.service   - Systemd service unit file
## - /lib/systemd/system/netdata.service   - Alternative systemd service location
##
## USER AND GROUP CREATION:
## - Creates 'netdata' system user and group
## - Adds netdata user to relevant system groups for monitoring access:
##   - adm (for log file access)
##   - docker (if Docker is installed)
##   - www-data (on Proxmox systems)
##
## MODIFIED EXISTING FILES:
## - /etc/passwd                           - New netdata user entry
## - /etc/group                            - New netdata group and group memberships
## - /etc/shadow                           - Password entry for netdata user (locked)
##
## NETWORK CONFIGURATION:
## - Opens port 19999/tcp for web dashboard access (may require firewall configuration)
## - Creates web server binding on localhost:19999 by default
##
## AUTOMATIC STARTUP:
## - Enables and starts netdata.service via systemd
## - Configures automatic startup on system boot
##
## PERMISSIONS:
## - Sets appropriate file ownership (netdata:netdata) for config and data directories
## - Configures read access to system files (/proc, /sys) for monitoring
## - May require sudo/CAP_SYS_PTRACE capabilities for process monitoring
##
## MONITORING ACCESS:
## - Reads from /proc/*, /sys/* for system metrics collection
## - May access log files in /var/log/ depending on configuration
## - Monitors running processes, network connections, and system resources
##
## Note: The exact files created may vary based on Ubuntu version and Netdata package version.
## Some configuration files are created on first run rather than during installation.
##
##########################################################################################

##########################################################################################
## Set variables
##########################################################################################

DATE=$(date +%Y-%m-%d_%H%M)
SUBSCRIPT="netdata_install.sh"

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
## Install Netdata
##########################################################################################

## https://learn.netdata.cloud/guides/longer-metrics-storage/

show_yellow "Installing Netdata - you may need to answer yes to certain install commands."

show_yellow "Please install Netdata using Netdata script from your account instead."
# cd /tmp
# bash <(curl -Ss https://my-netdata.io/kickstart.sh) >>$LOGDIR/$LOGFILE 2>&1 || (show_err "Installation of Netdata package failed. Please check logfile and fix error manually.")

if ! apt-get --yes install netdata >>$LOGDIR/$LOGFILE 2>&1; then
    show_err "Installation of netdata failed. Please check logfile and fix error manually."
    exit 1
fi
show_yellow "Netdata installed successfully."

##########################################################################################
## Done
##########################################################################################

show_info "$SUBSCRIPT done."
