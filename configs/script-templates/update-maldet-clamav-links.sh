#!/bin/bash

##########################################################################################
## Update Maldet signature links for ClamAV integration
##########################################################################################
DATE=$(date +%Y-%m-%d_%H%M)
SCRIPT_NAME="update-maldet-clamav-links.sh"

# Source helper functions if available
if [ -f "/usr/local/bin/script_helper_functions.sh" ]; then
    source /usr/local/bin/script_helper_functions.sh
elif [ -f "$(dirname "$0")/script_helper_functions.sh" ]; then
    source "$(dirname "$0")/script_helper_functions.sh"
else
    # Fallback functions if helper script not available
    show_info() { echo "[INFO] $1"; }
    show_yellow() { echo "[WARNING] $1"; }
    show_err() {
        echo "[ERROR] $1" >&2
        exit 1
    }
    show_warn() { echo "[WARN] $1"; }
fi

if [ -n "$LOGDIR" ]; then
    LOGDIR=$LOGDIR
else
    LOGDIR=/srv/apps/logs
fi

LOGFILE=$SCRIPT_NAME-$DATE.log

##########################################################################################
## Configuration
##########################################################################################
CLAMAV_DB_DIR="/var/lib/clamav"
MALDET_SIG_DIR="/usr/local/maldetect/sigs"

##########################################################################################
## Functions
##########################################################################################

# Function to update signature links
update_signature_links() {
    local updated_count=0

    show_info "Starting Maldet signature link update process."

    # Verify directories exist
    if [ ! -d "$CLAMAV_DB_DIR" ]; then
        show_err "ClamAV database directory not found: $CLAMAV_DB_DIR"
    fi

    if [ ! -d "$MALDET_SIG_DIR" ]; then
        show_err "Maldet signature directory not found: $MALDET_SIG_DIR"
    fi

    # Verify ClamAV has basic signature databases
    if [ ! -f "$CLAMAV_DB_DIR/main.cvd" ] && [ ! -f "$CLAMAV_DB_DIR/main.cld" ]; then
        show_warn "ClamAV main signature database not found. Run 'freshclam' to download basic signatures first."
        return 1
    fi

    # Remove old maldet links
    show_info "Removing old Maldet signature links..."
    rm -f "$CLAMAV_DB_DIR"/maldet_* 2>/dev/null || true

    # Update Maldet signatures first if possible
    if command -v maldet >/dev/null 2>&1; then
        show_info "Updating Maldet signatures before linking..."
        maldet --update-ver >>$LOGDIR/$LOGFILE 2>&1 || show_warn "Maldet signature update reported issues - continuing with existing signatures"
    fi

    # Create new links for each signature type
    for sig_type in hdb ndb ldb; do
        if ls "$MALDET_SIG_DIR"/*.$sig_type >/dev/null 2>&1; then
            show_info "Processing .$sig_type signature files..."
            for sig_file in "$MALDET_SIG_DIR"/*.$sig_type; do
                if [ -f "$sig_file" ] && [ -s "$sig_file" ]; then
                    sig_basename=$(basename "$sig_file")
                    link_target="$CLAMAV_DB_DIR/maldet_$sig_basename"

                    if ln -sf "$sig_file" "$link_target" 2>>$LOGDIR/$LOGFILE; then
                        updated_count=$((updated_count + 1))
                        show_info "Linked: $sig_basename"
                    else
                        show_warn "Failed to link: $sig_basename"
                    fi
                elif [ -f "$sig_file" ]; then
                    show_warn "Skipping empty signature file: $(basename "$sig_file")"
                fi
            done
        else
            show_info "No .$sig_type signature files found in $MALDET_SIG_DIR"
        fi
    done

    # Fix permissions for all maldet links
    if [ $updated_count -gt 0 ]; then
        show_info "Setting proper permissions for signature links..."
        if chown -h clamav:clamav "$CLAMAV_DB_DIR"/maldet_* 2>>$LOGDIR/$LOGFILE; then
            show_info "Permissions updated successfully."
        else
            show_warn "Some permission updates may have failed. Check log: $LOGDIR/$LOGFILE"
        fi

        # Reload ClamAV daemon to pick up new signatures
        show_info "Reloading ClamAV daemon to apply new signatures..."
        if systemctl is-active --quiet clamav-daemon.service; then
            if systemctl reload clamav-daemon.service 2>>$LOGDIR/$LOGFILE; then
                show_info "ClamAV daemon reloaded successfully."
            else
                show_warn "Failed to reload ClamAV daemon. Service may need restart."
            fi
        else
            show_warn "ClamAV daemon is not running. Signatures will be available when service starts."
        fi

        show_info "Signature link update completed. Updated $updated_count signature files."
    else
        show_warn "No signature files were linked. ClamAV will work with standard signatures only."
        return 1
    fi
}

# Function to verify signature integration
verify_integration() {
    show_info "Verifying Maldet-ClamAV signature integration..."

    local maldet_links=$(ls "$CLAMAV_DB_DIR"/maldet_* 2>/dev/null | wc -l)

    if [ "$maldet_links" -gt 0 ]; then
        show_info "Found $maldet_links Maldet signature links in ClamAV database directory."

        # Check if ClamAV daemon is running and can access signatures
        if systemctl is-active --quiet clamav-daemon.service; then
            show_info "ClamAV daemon is running and should have access to Maldet signatures."
        else
            show_warn "ClamAV daemon is not running. Signatures will be available when service starts."
        fi
    else
        show_warn "No Maldet signature links found. Integration may have failed."
    fi
}

##########################################################################################
## Main execution
##########################################################################################

# Create log directory if it doesn't exist
mkdir -p "$LOGDIR" 2>/dev/null || true

# Log script start
echo "$(date): Starting $SCRIPT_NAME" >>$LOGDIR/$LOGFILE

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    show_err "This script must be run as root (or with sudo)."
fi

# Main execution
case "${1:-update}" in
"update")
    update_signature_links
    ;;
"verify")
    verify_integration
    ;;
"both" | "all")
    update_signature_links
    verify_integration
    ;;
*)
    show_info "Usage: $0 [update|verify|both]"
    show_info "  update  - Update Maldet signature links (default)"
    show_info "  verify  - Verify signature integration"
    show_info "  both    - Update and verify"
    exit 0
    ;;
esac

# Log script completion
echo "$(date): Completed $SCRIPT_NAME" >>$LOGDIR/$LOGFILE

show_info "$SCRIPT_NAME completed. Log available at: $LOGDIR/$LOGFILE"
