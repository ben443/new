#!/bin/bash
################################################################################
# Tests for log_warn in flash-helper.sh
################################################################################

set -e

# Setup test workspace
TEST_WORKSPACE=$(mktemp -d)
FAILURES=0

# Clean up function
cleanup() {
    rm -rf "${TEST_WORKSPACE}"
}
trap cleanup EXIT

# Setup test script environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source the target script
source "${SCRIPT_DIR}/flash-helper.sh"
set +e

echo "Running tests for log_warn in flash-helper.sh..."

# Test case 1: Test basic log_warn output
test_log_warn_basic() {
    local test_msg="This is a test warning"
    local actual_out="${TEST_WORKSPACE}/actual_out.txt"
    local expected_out="${TEST_WORKSPACE}/expected_out.txt"

    # Run the function, redirecting output
    log_warn "${test_msg}" > "${actual_out}" 2>&1

    # Generate expected output using printf for accurate ansi colors
    printf '\033[1;33m[WARN] %b\033[0m\n' "${test_msg}" > "${expected_out}"

    if cmp -s "${actual_out}" "${expected_out}"; then
        echo "[PASS] test_log_warn_basic"
    else
        echo "[FAIL] test_log_warn_basic"
        echo "Expected:"
        cat -v "${expected_out}"
        echo "Actual:"
        cat -v "${actual_out}"
        FAILURES=$((FAILURES + 1))
    fi
}

# Test case 2: Test log_warn with special characters
test_log_warn_special_chars() {
    local test_msg="Warning: * % \$ & # \n \t"
    local actual_out="${TEST_WORKSPACE}/actual_out2.txt"
    local expected_out="${TEST_WORKSPACE}/expected_out2.txt"

    # Run the function, redirecting output
    log_warn "${test_msg}" > "${actual_out}" 2>&1

    # Generate expected output
    printf '\033[1;33m[WARN] %b\033[0m\n' "${test_msg}" > "${expected_out}"

    if cmp -s "${actual_out}" "${expected_out}"; then
        echo "[PASS] test_log_warn_special_chars"
    else
        echo "[FAIL] test_log_warn_special_chars"
        echo "Expected:"
        cat -v "${expected_out}"
        echo "Actual:"
        cat -v "${actual_out}"
        FAILURES=$((FAILURES + 1))
    fi
}

# Run tests
test_log_warn_basic
test_log_warn_special_chars

# Exit with failure count
if [ ${FAILURES} -gt 0 ]; then
    echo "Tests failed: ${FAILURES}"
else
    echo "All tests passed."
fi
exit ${FAILURES}
