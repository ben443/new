#!/bin/bash

# Setup environment for testing
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# We source the script to test
source "${SCRIPT_DIR}/flash-helper.sh"

# Since flash-helper.sh has "set -e", we need to disable it so tests can continue after failures
set +e

# Override OUTPUT_DIR for testing after sourcing because it's hardcoded
export OUTPUT_DIR="${SCRIPT_DIR}/test_output"

# Mock adb command
adb_calls=()
adb() {
    adb_calls+=("$*")
}

# Setup output dir
setup() {
    mkdir -p "${OUTPUT_DIR}"
    adb_calls=()
}

# Teardown output dir
teardown() {
    rm -rf "${OUTPUT_DIR}"
    adb_calls=()
}

# Counter for tests
tests_run=0
tests_failed=0

# Assert equals helper
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [ "$expected" != "$actual" ]; then
        echo "FAIL: $message"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        tests_failed=$((tests_failed + 1))
    fi
}

echo "Running flash_twrp tests..."

# Test 1: No zip file present
setup
# Run without capture so set -e doesn't break subshell or wait, and so adb_calls array is populated in the same shell
flash_twrp > /dev/null 2>&1
result=$?
assert_equals "1" "$result" "Should return 1 when no zip is found"
assert_equals "0" "${#adb_calls[@]}" "Should not call adb when no zip is found"
tests_run=$((tests_run + 1))
teardown

# Test 2: Zip file present
setup
touch "${OUTPUT_DIR}/nethunter-kernel.zip"
flash_twrp > /dev/null 2>&1
result=$?
assert_equals "0" "$result" "Should return 0 when zip is found and pushed successfully"
assert_equals "2" "${#adb_calls[@]}" "Should call adb twice"

if [ ${#adb_calls[@]} -ge 2 ]; then
    assert_equals "push ${OUTPUT_DIR}/nethunter-kernel.zip /sdcard/" "${adb_calls[0]}" "First adb call should push zip"
    assert_equals "reboot recovery" "${adb_calls[1]}" "Second adb call should reboot to recovery"
fi
tests_run=$((tests_run + 1))
teardown

echo "Tests run: $tests_run"
if [ "$tests_failed" -gt 0 ]; then
    echo "$tests_failed tests failed."
    exit 1
else
    echo "All tests passed."
    exit 0
fi
