#!/usr/bin/env bash

#########################################################################
# Manual Service Test Script for Ubuntu 24.04 Server Automation
# Tests all monitoring and security services manually
#########################################################################

# Configuration
SCRIPT_NAME="Service Test Runner"
HOSTNAME=$(hostname)
START_TIME=$(date)
LOG_FILE="/tmp/service_test_$(date +%Y%m%d_%H%M%S).log"
FAILED_SERVICES=()
SUCCESS_SERVICES=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log with timestamp
log_message() {
    local message="$1"
    local level="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Function to print colored output
print_status() {
    local message="$1"
    local status="$2"

    case "$status" in
    "INFO")
        echo -e "${BLUE}[INFO]${NC} $message"
        ;;
    "SUCCESS")
        echo -e "${GREEN}[SUCCESS]${NC} $message"
        ;;
    "WARNING")
        echo -e "${YELLOW}[WARNING]${NC} $message"
        ;;
    "ERROR")
        echo -e "${RED}[ERROR]${NC} $message"
        ;;
    *)
        echo "$message"
        ;;
    esac
}

# Function to run a service and capture output
run_service() {
    local service_name="$1"
    local description="$2"
    local command="$3"

    print_status "Testing $service_name: $description" "INFO"
    log_message "Starting test for $service_name" "INFO"

    echo "========================================" >>"$LOG_FILE"
    echo "Service: $service_name" >>"$LOG_FILE"
    echo "Description: $description" >>"$LOG_FILE"
    echo "Command: $command" >>"$LOG_FILE"
    echo "Start Time: $(date)" >>"$LOG_FILE"
    echo "========================================" >>"$LOG_FILE"

    # Run the service and capture both stdout and stderr
    if eval "$command" >>"$LOG_FILE" 2>&1; then
        print_status "$service_name completed successfully" "SUCCESS"
        log_message "$service_name completed successfully" "SUCCESS"
        SUCCESS_SERVICES+=("$service_name")
    else
        local exit_code=$?
        print_status "$service_name failed with exit code $exit_code" "ERROR"
        log_message "$service_name failed with exit code $exit_code" "ERROR"
        FAILED_SERVICES+=("$service_name")
    fi

    echo "End Time: $(date)" >>"$LOG_FILE"
    echo "" >>"$LOG_FILE"

    # Add a small delay between services
    sleep 2
}

# Function to check if required dependencies exist
check_dependencies() {
    local missing_deps=()

    print_status "Checking dependencies..." "INFO"

    # Check for systemctl
    if ! command -v systemctl >/dev/null 2>&1; then
        missing_deps+=("systemctl")
    fi

    # Check for specific commands used by services
    local commands=("df" "free" "bc" "curl" "ps" "ping" "ss" "journalctl")
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_status "Missing dependencies: ${missing_deps[*]}" "ERROR"
        log_message "Missing dependencies: ${missing_deps[*]}" "ERROR"
        return 1
    else
        print_status "All dependencies found" "SUCCESS"
        return 0
    fi
}

# Function to display final summary
display_summary() {
    local total_services=$((${#SUCCESS_SERVICES[@]} + ${#FAILED_SERVICES[@]}))
    local end_time=$(date)
    local duration=$(($(date +%s) - $(date -d "$START_TIME" +%s)))

    echo ""
    echo "========================================"
    echo "           TEST SUMMARY"
    echo "========================================"
    echo "Hostname: $HOSTNAME"
    echo "Start Time: $START_TIME"
    echo "End Time: $end_time"
    echo "Duration: ${duration} seconds"
    echo "Total Services Tested: $total_services"
    echo "Successful: ${#SUCCESS_SERVICES[@]}"
    echo "Failed: ${#FAILED_SERVICES[@]}"
    echo ""

    if [ ${#SUCCESS_SERVICES[@]} -gt 0 ]; then
        print_status "Successful Services:" "SUCCESS"
        for service in "${SUCCESS_SERVICES[@]}"; do
            echo "  ✓ $service"
        done
        echo ""
    fi

    if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
        print_status "Failed Services:" "ERROR"
        for service in "${FAILED_SERVICES[@]}"; do
            echo "  ✗ $service"
        done
        echo ""
    fi

    echo "Log file: $LOG_FILE"
    echo "========================================"

    # Log summary to file
    {
        echo ""
        echo "========================================"
        echo "           FINAL SUMMARY"
        echo "========================================"
        echo "Total Services: $total_services"
        echo "Successful: ${#SUCCESS_SERVICES[@]}"
        echo "Failed: ${#FAILED_SERVICES[@]}"
        echo "Duration: ${duration} seconds"
        echo "========================================"
    } >>"$LOG_FILE"
}

# Main execution
main() {
    print_status "Starting $SCRIPT_NAME on $HOSTNAME" "INFO"
    log_message "Starting $SCRIPT_NAME" "INFO"

    # Create log file
    touch "$LOG_FILE"

    # Check dependencies
    if ! check_dependencies; then
        print_status "Dependency check failed. Exiting." "ERROR"
        exit 1
    fi

    echo ""
    print_status "Starting service tests..." "INFO"
    echo ""

    # Test each service manually (not using systemctl start to avoid conflicts)

    # 1. Disk Space Monitor
    run_service "disk-space-monitor" \
        "Check disk space with warning at 20% and critical at 10%" \
        "/srv/apps/scripts/check_disk_space.sh -w 20 -c 10"

    # 2. Swap Monitor
    run_service "swap-monitor" \
        "Monitor swap usage and memory pressure" \
        "/srv/apps/scripts/check_swap_usage.sh"

    # 3. System Health Check
    run_service "system-health-check" \
        "Comprehensive system health monitoring" \
        "/srv/apps/scripts/system_health_check.sh"

    # 4. RKHunter Scan (if available) - Allow up to 3 hours
    if command -v rkhunter >/dev/null 2>&1; then
        print_status "RKHunter scan may take up to 3 hours to complete..." "INFO"
        run_service "rkhunter-scan" \
            "Security scan with RKHunter (timeout: 3h)" \
            "timeout 10800 bash -c 'rkhunter --cronjob --check --sk || (grep -q \"Possible rootkits: 0\" /var/log/rkhunter.log && exit 0 || exit 1)'"
    else
        print_status "RKHunter not installed, skipping scan" "WARNING"
        log_message "RKHunter not installed, skipping scan" "WARNING"
    fi

    # 5. RKHunter Update (if available) - Allow up to 1 hour
    if command -v rkhunter >/dev/null 2>&1; then
        print_status "RKHunter update may take up to 1 hour to complete..." "INFO"
        run_service "rkhunter-update" \
            "Update RKHunter database and properties (timeout: 1h)" \
            "timeout 3600 bash -c 'rkhunter --cronjob --update --sk; UPDATE_EXIT=\$?; echo \"Update exit code: \$UPDATE_EXIT\"; rkhunter --cronjob --propupd --sk; PROPUPD_EXIT=\$?; echo \"Propupd exit code: \$PROPUPD_EXIT\"; if [ \$UPDATE_EXIT -eq 0 ] && [ \$PROPUPD_EXIT -eq 0 ]; then exit 0; elif [ \$PROPUPD_EXIT -eq 0 ]; then exit 0; else exit \$PROPUPD_EXIT; fi'"
    else
        print_status "RKHunter not installed, skipping update" "WARNING"
        log_message "RKHunter not installed, skipping update" "WARNING"
    fi

    # 5.5. ClamAV Signature Update (if available) - Allow up to 30 minutes
    if [ -f "/usr/local/bin/clamav-update.sh" ]; then
        print_status "ClamAV signature update may take up to 30 minutes to complete..." "INFO"
        run_service "clamav-update" \
            "Update ClamAV virus signatures (timeout: 30m)" \
            "timeout 1800 /usr/local/bin/clamav-update.sh"
    elif command -v freshclam >/dev/null 2>&1; then
        # Fallback to basic freshclam if script not available
        print_status "Basic ClamAV signature update may take a while to complete..." "INFO"
        run_service "clamav-update-basic" \
            "Basic ClamAV signature update (timeout: 30m)" \
            "timeout 1800 freshclam --verbose"
    else
        print_status "ClamAV not installed, skipping signature update" "WARNING"
        log_message "ClamAV not installed, skipping signature update" "WARNING"
    fi

    # 5.6. Maldet Signature Update (if available) - Allow up to 30 minutes
    if command -v maldet >/dev/null 2>&1; then
        print_status "Maldet signature update may take up to 30 minutes to complete..." "INFO"
        run_service "maldet-update" \
            "Update Maldet signatures (timeout: 30m)" \
            "timeout 1800 maldet --update-sigs"
    else
        print_status "Maldet not installed, skipping signature update" "WARNING"
        log_message "Maldet not installed, skipping signature update" "WARNING"
    fi

    # 6. Maldet Scan (if available) - Allow up to 3 hours
    if [ -f "/usr/local/bin/maldet-scan.sh" ]; then
        print_status "Maldet scan may take up to 3 hours to complete..." "INFO"
        run_service "maldet-scan" \
            "Malware detection scan with Maldet (timeout: 3h)" \
            "timeout 10800 /usr/local/bin/maldet-scan.sh"
    elif command -v maldet >/dev/null 2>&1; then
        # Fallback to basic maldet scan if script not available
        print_status "Basic Maldet scan may take a while to complete..." "INFO"
        run_service "maldet-scan-basic" \
            "Basic Maldet scan of /tmp (timeout: 2h)" \
            "timeout 7200 maldet -a /tmp"
    else
        print_status "Maldet not installed, skipping scan" "WARNING"
        log_message "Maldet not installed, skipping scan" "WARNING"
    fi

    # 7. ClamAV Scan (if available) - Allow up to 6 hours
    if [ -f "/usr/local/bin/clamav-scan.sh" ]; then
        print_status "ClamAV scan may take up to 6 hours to complete..." "INFO"
        run_service "clamav-scan" \
            "Antivirus scan with ClamAV (timeout: 6h)" \
            "timeout 21600 /usr/local/bin/clamav-scan.sh"
    elif command -v clamscan >/dev/null 2>&1; then
        # Fallback to basic clamscan if script not available
        print_status "Basic ClamAV scan may take a while to complete..." "INFO"
        run_service "clamav-scan-basic" \
            "Basic ClamAV scan of /tmp (timeout: 1h)" \
            "timeout 3600 clamscan -r --bell -i /tmp"
    else
        print_status "ClamAV not installed, skipping scan" "WARNING"
        log_message "ClamAV not installed, skipping scan" "WARNING"
    fi

    # Display final summary
    display_summary

    # Exit with appropriate code
    if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Handle script interruption
trap 'print_status "Script interrupted by user" "ERROR"; exit 130' INT TERM

# Show usage information
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 [options]"
    echo ""
    echo "Manual test script for all monitoring and security services"
    echo ""
    echo "Services tested:"
    echo "  - disk-space-monitor (check disk usage)"
    echo "  - swap-monitor (check swap usage)"
    echo "  - system-health-check (comprehensive health check)"
    echo "  - rkhunter-scan (security rootkit scan)"
    echo "  - rkhunter-update (update security database)"
    echo "  - clamav-update (update ClamAV virus signatures)"
    echo "  - maldet-update (update maldet signatures)"
    echo "  - maldet-scan (malware detection scan)"
    echo "  - clamav-scan (antivirus scan)"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "The script will create a detailed log file in /tmp/"
    echo "All services run independently without using systemd timers"
    exit 0
fi

# Run main function
main "$@"
