#!/bin/bash

##########################################################################################
# Ubuntu Automation - Installation Status Viewer
# View the current installation status of all modules
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
init_logging "view_install_status.sh"

##########################################################################################
# Local helper functions specific to status viewing
##########################################################################################

# Enhanced version of show_install_status with additional features
show_detailed_install_status() {
    if [ ! -f "$INSTALL_STATUS_LOG" ]; then
        show_err "No installation status log found at: $INSTALL_STATUS_LOG"
        echo "Run the main install.sh script first to create the status log."
        return 1
    fi

    echo ""
    show_info "📋 UBUNTU AUTOMATION INSTALLATION STATUS:"
    echo "============================================="

    local success_count=0
    local failed_count=0
    local skipped_count=0

    while IFS='=' read -r module status; do
        # Skip comments and empty lines
        if [[ "$module" =~ ^#.*$ ]] || [[ -z "$module" ]]; then
            continue
        fi

        case "$status" in
        "SUCCESS")
            echo "✅ $module: Successfully installed"
            ((success_count++))
            ;;
        "FAILED")
            echo "❌ $module: Installation failed"
            ((failed_count++))
            ;;
        "SKIPPED")
            echo "⏭️  $module: Skipped by user"
            ((skipped_count++))
            ;;
        esac
    done <"$INSTALL_STATUS_LOG"

    echo "============================================="
    show_info "📊 SUMMARY: $success_count successful, $failed_count failed, $skipped_count skipped"

    if [ $failed_count -gt 0 ]; then
        echo ""
        show_warn "⚠️  Some modules failed. You can re-run install.sh to retry failed modules."
        show_warn "   Successfully installed modules will be skipped automatically."
    fi

    if [ $success_count -gt 0 ] && [ $failed_count -eq 0 ]; then
        echo ""
        show_info "🎉 All selected modules installed successfully!"
    fi

    echo ""
    show_info "📝 Status log location: $INSTALL_STATUS_LOG"
    echo ""
}

# Reset installation status (optional feature)
reset_install_status() {
    if [ ! -f "$INSTALL_STATUS_LOG" ]; then
        show_err "No installation status log found to reset."
        return 1
    fi

    echo ""
    show_warn "⚠️  This will reset all installation status and force reinstallation of all modules."
    read -p "Are you sure you want to reset the installation status? (Y/N): " yn

    case $yn in
    [Yy]*)
        if rm -f "$INSTALL_STATUS_LOG"; then
            show_info "✅ Installation status log reset successfully."
            show_info "   Next run of install.sh will reinstall all selected modules."
        else
            show_err "❌ Failed to reset installation status log."
            return 1
        fi
        ;;
    *)
        show_info "Reset cancelled."
        ;;
    esac
    echo ""
}

# Reset specific module status
reset_module_status() {
    local module_name="$1"

    if [ -z "$module_name" ]; then
        show_err "Please specify a module name to reset."
        echo "Example: $0 reset-module Podman_Installation"
        return 1
    fi

    if [ ! -f "$INSTALL_STATUS_LOG" ]; then
        show_err "No installation status log found."
        return 1
    fi

    # Check if module exists in log
    if ! grep -q "^${module_name}=" "$INSTALL_STATUS_LOG" 2>/dev/null; then
        show_err "Module '$module_name' not found in installation log."
        echo ""
        echo "Available modules:"
        grep -E "^[^#].*=" "$INSTALL_STATUS_LOG" 2>/dev/null | cut -d'=' -f1 | sed 's/^/  /'
        return 1
    fi

    # Remove the module entry
    local temp_file=$(mktemp)
    grep -v "^${module_name}=" "$INSTALL_STATUS_LOG" >"$temp_file" 2>/dev/null || touch "$temp_file"
    mv "$temp_file" "$INSTALL_STATUS_LOG"
    chmod 600 "$INSTALL_STATUS_LOG"

    show_info "✅ Module '$module_name' status reset successfully."
    show_info "   This module will be reinstalled on next run of install.sh"
    echo ""
}

##########################################################################################
# Main script logic
##########################################################################################

case "$1" in
"reset")
    reset_install_status
    ;;
"reset-module")
    reset_module_status "$2"
    ;;
"-h" | "--help" | "help")
    echo ""
    show_info "Ubuntu Automation - Installation Status Viewer"
    echo "=============================================="
    echo ""
    echo "USAGE:"
    echo "  $0                    Show current installation status"
    echo "  $0 reset              Reset all installation status (force reinstall all)"
    echo "  $0 reset-module NAME  Reset specific module status"
    echo "  $0 help               Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                              # View status"
    echo "  $0 reset-module Podman_Installation  # Reset Podman installation"
    echo "  $0 reset                        # Reset everything"
    echo ""
    ;;
"")
    show_detailed_install_status
    ;;
*)
    show_err "Unknown command: $1"
    echo "Use '$0 help' for usage information."
    exit 1
    ;;
esac
