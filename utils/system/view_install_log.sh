#!/bin/bash

##########################################################################################
## Ubuntu Automation Installation Log Viewer
##########################################################################################

##########################################################################################
## Source shared helper functions
##########################################################################################

# Set BASEDIR for shared functions (assuming script is in utils/)
export BASEDIR="$(dirname "$(dirname "$(realpath "$0")")")"

# Source the shared helper functions
if [ -f "$BASEDIR/utils/shared_functions.sh" ]; then
    source "$BASEDIR/utils/shared_functions.sh"
else
    echo "❌ ERROR: Shared functions script not found at $BASEDIR/utils/shared_functions.sh"
    exit 1
fi

# Initialize logging
init_logging "view_install_log.sh"

show_usage() {
    echo "Ubuntu Automation Installation Log Viewer"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -l, --list           List all installation runs"
    echo "  -i, --id ID          View logs for specific installation ID"
    echo "  -s, --summary        Show only summary information"
    echo "  -e, --errors         Show only errors and warnings"
    echo "  -t, --steps          Show installation steps only"
    echo "  -f, --full          Show complete logs (default)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --list                    # List all installations"
    echo "  $0 --id 20241219_143052      # View specific installation"
    echo "  $0 --summary                 # Show latest installation summary"
    echo "  $0 --errors                  # Show errors from latest installation"
}

list_installations() {
    echo "Available Ubuntu Automation Installation Logs:"
    echo "=============================================="

    # Get unique installation IDs from journal
    journalctl -o json --no-pager | grep 'ubuntu-automation-' |
        jq -r '.SYSLOG_IDENTIFIER' 2>/dev/null | sort -u | while read -r tag; do
        if [[ "$tag" =~ ubuntu-automation-([0-9_]+) ]]; then
            install_id="${BASH_REMATCH[1]}"
            # Get first and last log entries for this installation
            start_time=$(journalctl -t "$tag" --no-pager -o json -n 1 --reverse | jq -r '.__REALTIME_TIMESTAMP' 2>/dev/null)
            end_time=$(journalctl -t "$tag" --no-pager -o json -n 1 | jq -r '.__REALTIME_TIMESTAMP' 2>/dev/null)

            if [ "$start_time" != "null" ] && [ "$end_time" != "null" ]; then
                start_date=$(date -d "@$((start_time / 1000000))" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
                echo "  ID: $install_id  Date: $start_date"
            else
                echo "  ID: $install_id"
            fi
        fi
    done

    echo ""
    echo "Use: $0 --id <ID> to view specific installation logs"
}

get_latest_installation() {
    journalctl -o json --no-pager | grep 'ubuntu-automation-' |
        jq -r '.SYSLOG_IDENTIFIER' 2>/dev/null | sort -u | tail -n1
}

view_logs() {
    local install_tag="$1"
    local log_type="$2"

    if [ -z "$install_tag" ]; then
        install_tag=$(get_latest_installation)
        if [ -z "$install_tag" ]; then
            echo "No Ubuntu Automation installation logs found."
            echo "Run an installation first, then use this script to view logs."
            return 1
        fi
        echo "Viewing latest installation: $install_tag"
        echo ""
    fi

    case "$log_type" in
    "summary")
        echo "=== INSTALLATION SUMMARY ==="
        journalctl -t "$install_tag" INSTALL_STEP=summary --no-pager
        ;;
    "errors")
        echo "=== ERRORS AND WARNINGS ==="
        journalctl -t "$install_tag" -p warning --no-pager
        ;;
    "steps")
        echo "=== INSTALLATION STEPS ==="
        journalctl -t "$install_tag" INSTALL_PHASE=main --no-pager
        ;;
    "full" | *)
        echo "=== COMPLETE INSTALLATION LOG ==="
        journalctl -t "$install_tag" --no-pager
        ;;
    esac
}

# Parse command line arguments
INSTALL_ID=""
LOG_TYPE="full"

while [[ $# -gt 0 ]]; do
    case $1 in
    -l | --list)
        list_installations
        exit 0
        ;;
    -i | --id)
        INSTALL_ID="ubuntu-automation-$2"
        shift 2
        ;;
    -s | --summary)
        LOG_TYPE="summary"
        shift
        ;;
    -e | --errors)
        LOG_TYPE="errors"
        shift
        ;;
    -t | --steps)
        LOG_TYPE="steps"
        shift
        ;;
    -f | --full)
        LOG_TYPE="full"
        shift
        ;;
    -h | --help)
        show_usage
        exit 0
        ;;
    *)
        echo "Unknown option: $1"
        show_usage
        exit 1
        ;;
    esac
done

# View the logs
view_logs "$INSTALL_ID" "$LOG_TYPE"
