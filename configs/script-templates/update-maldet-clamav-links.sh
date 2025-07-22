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

    # Remove old maldet links first
    show_info "Removing old Maldet signature links..."
    rm -f "$CLAMAV_DB_DIR"/maldet_* 2>/dev/null || true

    # Also clean up any signature files that may have been incorrectly placed directly in ClamAV directory
    find "$CLAMAV_DB_DIR" -name "rfxn.*" -user root -delete 2>/dev/null || true

    # Update Maldet signatures first if possible
    if command -v maldet >/dev/null 2>&1; then
        show_info "Updating Maldet signatures before linking..."

        # Try version update first
        if maldet --update-ver >>$LOGDIR/$LOGFILE 2>&1; then
            show_info "Maldet version update completed successfully."
        else
            show_warn "Maldet version update failed - continuing with existing signatures"
        fi

        # Try signature update with timeout and retry
        local sig_update_success=false
        for attempt in 1 2; do
            show_info "Signature update attempt $attempt of 2..."
            if timeout 600 maldet --update-sigs >>$LOGDIR/$LOGFILE 2>&1; then
                show_info "Maldet signature update completed successfully on attempt $attempt."
                sig_update_success=true
                break
            else
                show_warn "Maldet signature update attempt $attempt failed"
                if [ $attempt -lt 2 ]; then
                    show_info "Waiting 30 seconds before retry..."
                    sleep 30
                fi
            fi
        done

        if [ "$sig_update_success" = false ]; then
            show_warn "Maldet signature update failed - proceeding with existing signatures"
        fi
    fi

    # Check if we have signature files after update attempt
    local sig_count=$(find "$MALDET_SIG_DIR" -name "*.hdb" -o -name "*.ndb" -o -name "*.ldb" 2>/dev/null | wc -l)

    # Exclude placeholder files from actual signature count
    local actual_sig_count=$(find "$MALDET_SIG_DIR" -name "*.hdb" -o -name "*.ndb" -o -name "*.ldb" 2>/dev/null | grep -v "custom.hex.dat" | wc -l)

    show_info "Found $sig_count total files, $actual_sig_count actual signature files in $MALDET_SIG_DIR"

    if [ "$actual_sig_count" -eq 0 ]; then
        show_warn "No actual Maldet signature files found after update attempt."
        show_warn "This may be due to network issues or Maldet server unavailability."
        show_warn "ClamAV will continue to work with standard signatures only."

        # Create a minimal status file to track this situation
        echo "# No Maldet signatures available as of $(date)" >"$MALDET_SIG_DIR/status.txt"
        echo "# Signature download failed or files not available" >>"$MALDET_SIG_DIR/status.txt"
        echo "# ClamAV is running with standard signatures only" >>"$MALDET_SIG_DIR/status.txt"

        return 1
    fi

    show_info "Processing $actual_sig_count Maldet signature files for ClamAV integration..."

    # Create new links for each signature type, but only for actual signature files
    for sig_type in hdb ndb ldb; do
        if ls "$MALDET_SIG_DIR"/*.$sig_type >/dev/null 2>&1; then
            show_info "Processing .$sig_type signature files..."
            for sig_file in "$MALDET_SIG_DIR"/*.$sig_type; do
                # Skip placeholder files
                if [[ "$(basename "$sig_file")" == "custom.hex.dat" ]]; then
                    show_info "Skipping placeholder file: $(basename "$sig_file")"
                    continue
                fi

                if [ -f "$sig_file" ] && [ -s "$sig_file" ]; then
                    # Verify the file is actually a signature file (basic check)
                    if head -n 1 "$sig_file" | grep -q "^#" || head -n 1 "$sig_file" | grep -q "^[a-f0-9]"; then
                        sig_basename=$(basename "$sig_file")
                        link_target="$CLAMAV_DB_DIR/maldet_$sig_basename"

                        if ln -sf "$sig_file" "$link_target" 2>>$LOGDIR/$LOGFILE; then
                            # Ensure proper ownership of the link
                            chown -h clamav:clamav "$link_target" 2>>$LOGDIR/$LOGFILE || true
                            updated_count=$((updated_count + 1))
                            show_info "Linked: maldet_$sig_basename -> $sig_file"
                        else
                            show_warn "Failed to link: $sig_basename"
                        fi
                    else
                        show_warn "Skipping invalid signature file format: $(basename "$sig_file")"
                    fi
                elif [ -f "$sig_file" ]; then
                    show_warn "Skipping empty signature file: $(basename "$sig_file")"
                else
                    show_warn "Signature file not found: $sig_file"
                fi
            done
        else
            show_info "No .$sig_type signature files found in $MALDET_SIG_DIR"
        fi
    done

    # Fix permissions for ClamAV directory
    chown -R clamav:clamav "$CLAMAV_DB_DIR" 2>>$LOGDIR/$LOGFILE || true

    if [ $updated_count -gt 0 ]; then
        show_info "Successfully linked $updated_count signature files."

        # Create status file documenting successful integration
        echo "# Maldet-ClamAV integration status as of $(date)" >"$MALDET_SIG_DIR/status.txt"
        echo "# Successfully linked $updated_count signature files to ClamAV" >>"$MALDET_SIG_DIR/status.txt"
        echo "# Integration completed successfully" >>"$MALDET_SIG_DIR/status.txt"

        # Reload ClamAV daemon to pick up new signatures
        show_info "Reloading ClamAV daemon to apply new signatures..."
        if systemctl is-active --quiet clamav-daemon.service; then
            if systemctl reload clamav-daemon.service 2>>$LOGDIR/$LOGFILE; then
                show_info "ClamAV daemon reloaded successfully."
            else
                show_warn "Failed to reload ClamAV daemon. Service may need restart."
                show_info "You can try: sudo systemctl restart clamav-daemon.service"
            fi
        else
            show_warn "ClamAV daemon is not running. Signatures will be available when service starts."
            show_info "To start ClamAV daemon: sudo systemctl start clamav-daemon.service"
        fi

        show_info "Signature link update completed successfully. Updated $updated_count signature files."
    else
        show_warn "No signature files were linked. ClamAV will work with standard signatures only."

        # Create status file documenting the situation
        echo "# Maldet-ClamAV integration status as of $(date)" >"$MALDET_SIG_DIR/status.txt"
        echo "# No signature files were successfully linked" >>"$MALDET_SIG_DIR/status.txt"
        echo "# ClamAV is running with standard signatures only" >>"$MALDET_SIG_DIR/status.txt"

        return 1
    fi
}

# Function to verify signature integration
verify_integration() {
    show_info "Verifying Maldet-ClamAV signature integration..."

    local maldet_links=$(ls "$CLAMAV_DB_DIR"/maldet_* 2>/dev/null | wc -l)
    local total_sigs=$(find "$MALDET_SIG_DIR" -name "*.hdb" -o -name "*.ndb" -o -name "*.ldb" 2>/dev/null | wc -l)
    local actual_sigs=$(find "$MALDET_SIG_DIR" -name "*.hdb" -o -name "*.ndb" -o -name "*.ldb" 2>/dev/null | grep -v "custom.hex.dat" | wc -l)

    show_info "Integration status:"
    show_info "  - Total signature files in Maldet directory: $total_sigs"
    show_info "  - Actual signature files (excluding placeholders): $actual_sigs"
    show_info "  - Active signature links in ClamAV directory: $maldet_links"

    # Check for broken links
    local broken_links=$(find "$CLAMAV_DB_DIR" -name "maldet_*" -type l ! -e 2>/dev/null | wc -l)
    if [ "$broken_links" -gt 0 ]; then
        show_warn "Found $broken_links broken Maldet signature links!"
        show_warn "Broken links:"
        find "$CLAMAV_DB_DIR" -name "maldet_*" -type l ! -e -ls 2>/dev/null || true
        show_warn "Run 'update' mode to fix broken links."
        return 1
    fi

    if [ "$maldet_links" -gt 0 ]; then
        show_info "✓ Found $maldet_links active Maldet signature links in ClamAV database directory."

        # Verify the links point to existing, non-empty files
        local valid_links=0
        for link in "$CLAMAV_DB_DIR"/maldet_*; do
            # Skip if no files match the pattern
            [ -e "$link" ] || continue
            if [ -f "$link" ] && [ -s "$link" ]; then
                valid_links=$((valid_links + 1))
            fi
        done

        show_info "  - Valid signature links: $valid_links/$maldet_links"

        # Check if ClamAV daemon is running and can access signatures
        if systemctl is-active --quiet clamav-daemon.service; then
            show_info "✓ ClamAV daemon is running and has access to Maldet signatures."

            # Try to get ClamAV to report signature count (if possible)
            if command -v clamdscan >/dev/null 2>&1; then
                local sig_info=$(timeout 10 clamdscan --version 2>/dev/null | grep "ClamAV" || echo "Version info not available")
                show_info "  - ClamAV status: $sig_info"
            fi
        else
            show_warn "⚠ ClamAV daemon is not running."
            show_info "  - Signatures will be available when service starts"
            show_info "  - To start: sudo systemctl start clamav-daemon.service"
        fi

        # Check status file
        if [ -f "$MALDET_SIG_DIR/status.txt" ]; then
            show_info "Last integration status:"
            while IFS= read -r line; do
                if [[ "$line" =~ ^#.*$ ]]; then
                    show_info "  ${line#\# }"
                fi
            done <"$MALDET_SIG_DIR/status.txt"
        fi

        show_info "✓ Maldet-ClamAV integration verification completed successfully."
        return 0
    else
        show_warn "⚠ No Maldet signature links found in ClamAV database directory."

        if [ "$actual_sigs" -gt 0 ]; then
            show_warn "  - Maldet has $actual_sigs signature files available"
            show_warn "  - But no links are created in ClamAV directory"
            show_info "  - Run 'update' mode to create signature links"
        else
            show_warn "  - No Maldet signature files available"
            show_info "  - Download signatures first: sudo maldet --update-sigs"
            show_info "  - Then run: sudo /usr/local/bin/update-maldet-clamav-links.sh update"
        fi

        # Check for common issues
        if [ ! -d "$MALDET_SIG_DIR" ]; then
            show_warn "  - Maldet signature directory not found: $MALDET_SIG_DIR"
        fi

        if [ ! -d "$CLAMAV_DB_DIR" ]; then
            show_warn "  - ClamAV database directory not found: $CLAMAV_DB_DIR"
        fi

        show_warn "⚠ Integration verification found issues."
        return 1
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
