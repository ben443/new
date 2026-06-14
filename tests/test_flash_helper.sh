#!/bin/bash

# Simple testing framework
TESTS_PASSED=0
TESTS_FAILED=0

# Reset mock states before each test
reset_mocks() {
    echo "0" > "${OUTPUT_DIR}/adb_called"
    echo "0" > "${OUTPUT_DIR}/fastboot_called"
    echo "0" > "${OUTPUT_DIR}/sleep_called"
    echo "" > "${OUTPUT_DIR}/adb_last_args"
    echo "" > "${OUTPUT_DIR}/fastboot_last_args"
    export FASTBOOT_DEVICES_OUTPUT=""
}

# Mock external commands
adb() {
    local count=$(cat "${OUTPUT_DIR}/adb_called")
    echo $((count + 1)) > "${OUTPUT_DIR}/adb_called"
    echo "$*" > "${OUTPUT_DIR}/adb_last_args"
    return 0
}

fastboot() {
    local count=$(cat "${OUTPUT_DIR}/fastboot_called")
    echo $((count + 1)) > "${OUTPUT_DIR}/fastboot_called"
    echo "$*" > "${OUTPUT_DIR}/fastboot_last_args"

    if [ "$1" = "devices" ]; then
        if [ -n "$FASTBOOT_DEVICES_OUTPUT" ]; then
            echo "$FASTBOOT_DEVICES_OUTPUT"
            return 0
        fi
        return 1
    fi
    return 0
}

sleep() {
    local count=$(cat "${OUTPUT_DIR}/sleep_called")
    echo $((count + 1)) > "${OUTPUT_DIR}/sleep_called"
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

# Disable set -e for the tests so test_kernel returning 1 doesn't exit the whole test script
set +e
source "${SCRIPT_DIR}/flash-helper.sh"
set +e # Just in case it was re-enabled by sourcing

# Override OUTPUT_DIR for tests - MUST be done after sourcing because flash-helper.sh defines it!
export OUTPUT_DIR="${SCRIPT_DIR}/tests/test_output"
mkdir -p "$OUTPUT_DIR"

# Test 1: boot.img missing
test_kernel_missing_boot_img() {
    echo "Running test_kernel_missing_boot_img..."
    reset_mocks
    rm -f "${OUTPUT_DIR}/boot.img"

    # Run function and capture return code and output
    test_kernel > "${OUTPUT_DIR}/test.log" 2>&1
    local return_code=$?
    local output=$(cat "${OUTPUT_DIR}/test.log")

    assert_equal "1" "$return_code" "Should return 1 when boot.img is missing"

    # Check that error was logged
    if echo "$output" | grep -q "boot.img not found!"; then
        assert_equal "1" "1" "Should log boot.img not found error"
    else
        assert_equal "1" "0" "Should log boot.img not found error"
    fi

    assert_equal "0" "$(cat "${OUTPUT_DIR}/adb_called")" "adb should not be called"
}

# Test 2: fastboot device not found
test_kernel_fastboot_device_not_found() {
    echo "Running test_kernel_fastboot_device_not_found..."
    reset_mocks
    touch "${OUTPUT_DIR}/boot.img"
    export FASTBOOT_DEVICES_OUTPUT="" # No devices

    test_kernel > "${OUTPUT_DIR}/test.log" 2>&1
    local return_code=$?
    local output=$(cat "${OUTPUT_DIR}/test.log")

    assert_equal "1" "$return_code" "Should return 1 when device not in fastboot"

    if echo "$output" | grep -q "Device not in fastboot mode!"; then
        assert_equal "1" "1" "Should log device not in fastboot mode error"
    else
        assert_equal "1" "0" "Should log device not in fastboot mode error"
    fi

    assert_equal "1" "$(cat "${OUTPUT_DIR}/adb_called")" "adb should be called once (reboot bootloader)"
    assert_equal "1" "$(cat "${OUTPUT_DIR}/sleep_called")" "sleep should be called once"
    assert_equal "reboot bootloader" "$(cat "${OUTPUT_DIR}/adb_last_args")" "adb should be called with 'reboot bootloader'"
}

# Test 3: Successful boot
test_kernel_success() {
    echo "Running test_kernel_success..."
    reset_mocks
    touch "${OUTPUT_DIR}/boot.img"
    export FASTBOOT_DEVICES_OUTPUT="12345 fastboot"

    test_kernel > "${OUTPUT_DIR}/test.log" 2>&1
    local return_code=$?
    local output=$(cat "${OUTPUT_DIR}/test.log")

    assert_equal "0" "$return_code" "Should return 0 on success"

    if echo "$output" | grep -q "Test kernel booted!"; then
        assert_equal "1" "1" "Should log success message"
    else
        assert_equal "1" "0" "Should log success message"
    fi

    assert_equal "1" "$(cat "${OUTPUT_DIR}/adb_called")" "adb should be called once (reboot bootloader)"
    assert_equal "2" "$(cat "${OUTPUT_DIR}/fastboot_called")" "fastboot should be called twice (devices, boot)"
    assert_equal "boot ${OUTPUT_DIR}/boot.img" "$(cat "${OUTPUT_DIR}/fastboot_last_args")" "fastboot should be called with 'boot boot.img'"
}

# Run tests
echo "Starting tests for flash-helper.sh..."
test_kernel_missing_boot_img
test_kernel_fastboot_device_not_found
test_kernel_success

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
