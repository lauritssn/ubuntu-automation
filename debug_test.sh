#!/bin/bash

echo "=== MINIMAL DEBUG TEST ==="
echo "Current directory: $(pwd)"
echo "BASH version: $BASH_VERSION"
echo "User: $(whoami)"
echo "ID: $(id)"

echo "=== TESTING BASIC COMMANDS ==="
echo "date command:"
date
echo "ls command:"
ls -la . | head -5

echo "=== TESTING PROBLEMATIC AREA ==="
export BASEDIR=$(pwd)
echo "BASEDIR: $BASEDIR"

# Test the exact commands that were failing
echo "Testing systemd-cat:"
command -v systemd-cat && echo "systemd-cat found" || echo "systemd-cat not found"

echo "Testing log functions:"
echo "Simple echo test" | systemd-cat -t "test" -p "info" 2>/dev/null && echo "systemd-cat works" || echo "systemd-cat failed"

echo "=== TESTING FILE SOURCING ==="
echo "echo 'TEST SCRIPT SOURCED'" > test_source.sh
echo "Sourcing with dot:"
. ./test_source.sh
echo "Sourcing with source:"
source ./test_source.sh 2>/dev/null || echo "source command failed"

echo "=== TEST COMPLETE ==="
rm -f test_source.sh 