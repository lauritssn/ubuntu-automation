#!/bin/bash

##########################################################################################
## Test script for Maldet-ClamAV integration
##########################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test functions
test_passed() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
}

test_failed() {
    echo -e "${RED}✗ FAIL${NC}: $1"
}

test_warning() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
}

echo "=== Maldet-ClamAV Integration Test ==="
echo "Generated: $(date)"
echo "Hostname: $(hostname)"
echo "==========================================="
echo

# Test 1: Check if Maldet is installed
echo "1. Testing Maldet installation..."
if command -v maldet >/dev/null 2>&1; then
    test_passed "Maldet is installed and in PATH"
    MALDET_VERSION=$(maldet --version 2>/dev/null | head -n 1 || echo "Version unknown")
    echo "   Version: $MALDET_VERSION"
else
    test_failed "Maldet is not installed or not in PATH"
    exit 1
fi

# Test 2: Check Maldet signature directory
echo
echo "2. Testing Maldet signature directory..."
MALDET_SIG_DIR="/usr/local/maldetect/sigs"
if [ -d "$MALDET_SIG_DIR" ]; then
    test_passed "Maldet signature directory exists: $MALDET_SIG_DIR"
    
    # Count signature files
    TOTAL_SIGS=$(find "$MALDET_SIG_DIR" -name "*.hdb" -o -name "*.ndb" -o -name "*.ldb" 2>/dev/null | wc -l)
    ACTUAL_SIGS=$(find "$MALDET_SIG_DIR" -name "*.hdb" -o -name "*.ndb" -o -name "*.ldb" 2>/dev/null | grep -v "custom.hex.dat" | wc -l)
    
    echo "   Total signature files: $TOTAL_SIGS"
    echo "   Actual signature files: $ACTUAL_SIGS"
    
    if [ "$ACTUAL_SIGS" -gt 0 ]; then
        test_passed "Maldet has downloadable signature files"
    else
        test_warning "No downloadable Maldet signature files found"
        echo "   This is expected if signatures haven't been downloaded yet"
    fi
else
    test_failed "Maldet signature directory not found: $MALDET_SIG_DIR"
fi

# Test 3: Check ClamAV installation
echo
echo "3. Testing ClamAV installation..."
if command -v clamd >/dev/null 2>&1 && command -v freshclam >/dev/null 2>&1; then
    test_passed "ClamAV is installed"
else
    test_failed "ClamAV is not properly installed"
    exit 1
fi

# Test 4: Check ClamAV database directory
echo
echo "4. Testing ClamAV database directory..."
CLAMAV_DB_DIR="/var/lib/clamav"
if [ -d "$CLAMAV_DB_DIR" ]; then
    test_passed "ClamAV database directory exists: $CLAMAV_DB_DIR"
    
    # Check essential databases
    if [ -f "$CLAMAV_DB_DIR/main.cvd" ] || [ -f "$CLAMAV_DB_DIR/main.cld" ]; then
        test_passed "ClamAV main signature database found"
    else
        test_failed "ClamAV main signature database missing"
    fi
    
    if [ -f "$CLAMAV_DB_DIR/daily.cvd" ] || [ -f "$CLAMAV_DB_DIR/daily.cld" ]; then
        test_passed "ClamAV daily signature database found"
    else
        test_failed "ClamAV daily signature database missing"
    fi
else
    test_failed "ClamAV database directory not found: $CLAMAV_DB_DIR"
    exit 1
fi

# Test 5: Check for Maldet signature links
echo
echo "5. Testing Maldet-ClamAV integration links..."
MALDET_LINKS=$(ls "$CLAMAV_DB_DIR"/maldet_* 2>/dev/null | wc -l)
BROKEN_LINKS=$(find "$CLAMAV_DB_DIR" -name "maldet_*" -type l ! -e 2>/dev/null | wc -l)

echo "   Maldet signature links found: $MALDET_LINKS"
echo "   Broken links found: $BROKEN_LINKS"

if [ "$BROKEN_LINKS" -gt 0 ]; then
    test_failed "Found $BROKEN_LINKS broken Maldet signature links"
    echo "   Broken links:"
    find "$CLAMAV_DB_DIR" -name "maldet_*" -type l ! -e -ls 2>/dev/null | sed 's/^/     /'
elif [ "$MALDET_LINKS" -gt 0 ]; then
    test_passed "Found $MALDET_LINKS working Maldet signature links"
    echo "   Links:"
    ls -la "$CLAMAV_DB_DIR"/maldet_* 2>/dev/null | sed 's/^/     /'
else
    if [ "$ACTUAL_SIGS" -gt 0 ]; then
        test_warning "No Maldet signature links found, but signatures are available"
        echo "   Run: sudo /usr/local/bin/update-maldet-clamav-links.sh update"
    else
        test_warning "No Maldet signature links found (no signatures available)"
        echo "   This is expected if Maldet signatures haven't been downloaded"
    fi
fi

# Test 6: Check ClamAV daemon status
echo
echo "6. Testing ClamAV daemon status..."
if systemctl is-active --quiet clamav-daemon.service; then
    test_passed "ClamAV daemon is running"
    
    # Check if daemon can load databases
    if systemctl status clamav-daemon.service | grep -q "LibClamAV Error"; then
        test_failed "ClamAV daemon has database loading errors"
        echo "   Check: journalctl -u clamav-daemon.service"
    else
        test_passed "ClamAV daemon is running without database errors"
    fi
else
    test_failed "ClamAV daemon is not running"
    echo "   Status:"
    systemctl status clamav-daemon.service --no-pager -l | sed 's/^/     /'
fi

# Test 7: Check update script availability
echo
echo "7. Testing update script availability..."
UPDATE_SCRIPT="/usr/local/bin/update-maldet-clamav-links.sh"
if [ -f "$UPDATE_SCRIPT" ] && [ -x "$UPDATE_SCRIPT" ]; then
    test_passed "Update script is available and executable: $UPDATE_SCRIPT"
else
    test_failed "Update script is missing or not executable: $UPDATE_SCRIPT"
fi

# Test 8: Check file permissions
echo
echo "8. Testing file permissions..."
CLAMAV_USER="clamav"
CLAMAV_GROUP="clamav"

# Check database directory ownership
DB_OWNER=$(stat -c '%U:%G' "$CLAMAV_DB_DIR" 2>/dev/null || echo "unknown:unknown")
if [ "$DB_OWNER" = "$CLAMAV_USER:$CLAMAV_GROUP" ]; then
    test_passed "ClamAV database directory has correct ownership"
else
    test_warning "ClamAV database directory ownership: $DB_OWNER (expected: $CLAMAV_USER:$CLAMAV_GROUP)"
fi

# Check signature file ownership
WRONG_OWNER_COUNT=0
for sig_file in "$CLAMAV_DB_DIR"/*.cvd "$CLAMAV_DB_DIR"/*.cld "$CLAMAV_DB_DIR"/maldet_* 2>/dev/null; do
    if [ -e "$sig_file" ]; then
        FILE_OWNER=$(stat -c '%U:%G' "$sig_file" 2>/dev/null || echo "unknown:unknown")
        if [ "$FILE_OWNER" != "$CLAMAV_USER:$CLAMAV_GROUP" ]; then
            WRONG_OWNER_COUNT=$((WRONG_OWNER_COUNT + 1))
        fi
    fi
done

if [ "$WRONG_OWNER_COUNT" -eq 0 ]; then
    test_passed "All signature files have correct ownership"
else
    test_warning "$WRONG_OWNER_COUNT signature files have incorrect ownership"
fi

echo
echo "=== Test Summary ==="
echo "Test completed at $(date)"
echo

# Final recommendations
if [ "$BROKEN_LINKS" -gt 0 ]; then
    echo "🔧 RECOMMENDED ACTIONS:"
    echo "1. Fix broken Maldet signature links:"
    echo "   sudo /usr/local/bin/update-maldet-clamav-links.sh update"
    echo
elif [ "$ACTUAL_SIGS" -eq 0 ]; then
    echo "🔧 RECOMMENDED ACTIONS:"
    echo "1. Download Maldet signatures:"
    echo "   sudo maldet --update-sigs"
    echo "2. Update ClamAV integration:"
    echo "   sudo /usr/local/bin/update-maldet-clamav-links.sh update"
    echo
fi

if ! systemctl is-active --quiet clamav-daemon.service; then
    echo "3. Start ClamAV daemon:"
    echo "   sudo systemctl start clamav-daemon.service"
    echo
fi

echo "For detailed integration status, run:"
echo "   sudo /usr/local/bin/update-maldet-clamav-links.sh verify"
echo

echo "=== End of Test ===" 