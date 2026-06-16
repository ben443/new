#!/bin/bash

# Simple testing framework
TESTS_PASSED=0
TESTS_FAILED=0

# Reset mock states before each test
reset_mocks() {
    echo "0" > "${OUTPUT_DIR}/adb_called"
    echo "" > "${OUTPUT_DIR}/adb_all_args"
    export MOCK_ADB_DEVICES_OUTPUT=""
    export MOCK_ADB_ROOT_OUTPUT=""
    export MOCK_ADB_GETPROP_DEVICE=""
}

# Mock external commands
adb() {
    local count=$(cat "${OUTPUT_DIR}/adb_called")
    echo $((count + 1)) > "${OUTPUT_DIR}/adb_called"
    echo "$*" >> "${OUTPUT_DIR}/adb_all_args"

    if [ "$1" = "devices" ]; then
        echo "$MOCK_ADB_DEVICES_OUTPUT"
        return 0
    fi

    if [ "$1" = "shell" ] && [ "$2" = "getprop" ] && [ "$3" = "ro.product.device" ]; then
        echo "$MOCK_ADB_GETPROP_DEVICE"
        return 0
    fi

    if [ "$1" = "shell" ] && [ "$2" = "su -c 'id'" ]; then
        echo "$MOCK_ADB_ROOT_OUTPUT"
        return 0
    fi

    return 0
}

assert_equal() {
    local expected=$1
    local actual=$2
    local message=$3

    if [ "$expected" = "$actual" ]; then
        echo -e "  [PASS] $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  [FAIL] $message\n    Expected: '$expected'\n    Actual:   '$actual'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Source the target file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Disable set -e for the tests
set +e
source "${SCRIPT_DIR}/flash-helper.sh"
set +e # Just in case it was re-enabled by sourcing

# Override OUTPUT_DIR for tests - MUST be done after sourcing because flash-helper.sh defines it!
export OUTPUT_DIR="${SCRIPT_DIR}/tests/test_output_chroot"
mkdir -p "$OUTPUT_DIR"

# Test 1: No device connected
test_setup_chroot_no_device() {
    echo "Running test_setup_chroot_no_device..."
    reset_mocks
    export MOCK_ADB_DEVICES_OUTPUT="List of devices attached" # no device

    setup_chroot > "${OUTPUT_DIR}/test.log" 2>&1
    local return_code=$?
    local output=$(cat "${OUTPUT_DIR}/test.log")

    assert_equal "1" "$return_code" "Should return 1 when no device is connected"

    if echo "$output" | grep -q "No device connected in ADB mode!"; then
        assert_equal "1" "1" "Should log no device connected error"
    else
        assert_equal "1" "0" "Should log no device connected error"
    fi
}

# Test 2: No root access
test_setup_chroot_no_root() {
    echo "Running test_setup_chroot_no_root..."
    reset_mocks
    export MOCK_ADB_DEVICES_OUTPUT="12345 device"
    export MOCK_ADB_GETPROP_DEVICE="gts8wifi"
    export MOCK_ADB_ROOT_OUTPUT="uid=2000(shell) gid=2000(shell)"

    setup_chroot > "${OUTPUT_DIR}/test.log" 2>&1
    local return_code=$?
    local output=$(cat "${OUTPUT_DIR}/test.log")

    assert_equal "1" "$return_code" "Should return 1 when no root access is available"

    if echo "$output" | grep -q "Root access not available!"; then
        assert_equal "1" "1" "Should log no root access error"
    else
        assert_equal "1" "0" "Should log no root access error"
    fi
}

# Test 3: Successful chroot setup
test_setup_chroot_success() {
    echo "Running test_setup_chroot_success..."
    reset_mocks
    export MOCK_ADB_DEVICES_OUTPUT="12345 device"
    export MOCK_ADB_GETPROP_DEVICE="gts8wifi"
    export MOCK_ADB_ROOT_OUTPUT="uid=0(root) gid=0(root)"

    setup_chroot > "${OUTPUT_DIR}/test.log" 2>&1
    local return_code=$?
    local output=$(cat "${OUTPUT_DIR}/test.log")

    assert_equal "0" "$return_code" "Should return 0 on successful setup"

    if echo "$output" | grep -q "NetHunter chroot setup complete!"; then
        assert_equal "1" "1" "Should log successful setup message"
    else
        assert_equal "1" "0" "Should log successful setup message"
    fi

    local adb_calls=$(cat "${OUTPUT_DIR}/adb_all_args")

    # Check that adb was called with wget
    if echo "$adb_calls" | grep -q "wget https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-full.tar.xz"; then
        assert_equal "1" "1" "adb should execute wget command"
    else
        assert_equal "1" "0" "adb should execute wget command"
    fi

    # Check that adb was called with tar extraction
    if echo "$adb_calls" | grep -q "tar -xJf kalifs-arm64-full.tar.xz"; then
        assert_equal "1" "1" "adb should execute tar command"
    else
        assert_equal "1" "0" "adb should execute tar command"
    fi

    # Check that adb was called with bootkali_init
    if echo "$adb_calls" | grep -q "bootkali_init"; then
        assert_equal "1" "1" "adb should execute bootkali_init script"
    else
        assert_equal "1" "0" "adb should execute bootkali_init script"
    fi

    # Check that adb was called with bootkali_login
    if echo "$adb_calls" | grep -q "bootkali_login"; then
        assert_equal "1" "1" "adb should execute bootkali_login script"
    else
        assert_equal "1" "0" "adb should execute bootkali_login script"
    fi
}

# Run tests
echo "Starting tests for setup_chroot..."
test_setup_chroot_no_device
test_setup_chroot_no_root
test_setup_chroot_success

# Cleanup
rm -rf "$OUTPUT_DIR"

# Print summary
echo ""
echo "Test Summary:"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"

if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
fi
exit 0
