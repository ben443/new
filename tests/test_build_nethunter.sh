#!/bin/bash
# Test suite for build-nethunter.sh using basic bash

# Setup test environment
export TEST_DIR="$(mktemp -d)"
export SCRIPT_TO_TEST="${TEST_DIR}/build-nethunter-test.sh"
export FAILURES=0

# Strip main execution from the script so we can source it safely
sed 's/^main "$@"$/# main "$@"/' build-nethunter.sh > "$SCRIPT_TO_TEST"
chmod +x "$SCRIPT_TO_TEST"

# Source the script, handling set -e safely
set +e
source "$SCRIPT_TO_TEST"
set +e

echo "Running tests..."

# Helper function to assert string equality
assert_eq() {
    local actual="$1"
    local expected="$2"
    local test_name="$3"

    if [[ "$actual" == "$expected" ]]; then
        echo "PASS: $test_name"
    else
        echo "FAIL: $test_name"
        echo "  Expected: $(echo "$expected" | cat -v)"
        echo "  Actual:   $(echo "$actual" | cat -v)"
        FAILURES=$((FAILURES+1))
    fi
}

# 1. Test log_info
expected_info=$(printf "\033[0;32m[INFO]\033[0m Test Info")
actual_info=$(log_info "Test Info")
assert_eq "$actual_info" "$expected_info" "log_info outputs correct format and colors"

# 2. Test log_warn
expected_warn=$(printf "\033[1;33m[WARN]\033[0m Test Warn")
actual_warn=$(log_warn "Test Warn")
assert_eq "$actual_warn" "$expected_warn" "log_warn outputs correct format and colors"

# 3. Test log_error
expected_error=$(printf "\033[0;31m[ERROR]\033[0m Test Error")
actual_error=$(log_error "Test Error")
assert_eq "$actual_error" "$expected_error" "log_error outputs correct format and colors"

# 4. Test log_step
expected_step=$(printf "\033[0;34m[STEP]\033[0m Test Step")
actual_step=$(log_step "Test Step")
assert_eq "$actual_step" "$expected_step" "log_step outputs correct format and colors"

# 5. Test check_gki_support with GKI defconfig
export KERNEL_DIR="${TEST_DIR}/kernel"
mkdir -p "${KERNEL_DIR}/arch/arm64/configs"
touch "${KERNEL_DIR}/arch/arm64/configs/gki_defconfig"

# Capture output and status
check_gki_support > "${TEST_DIR}/gki_output.log" 2>&1
status=$?

if [[ "$status" -eq 0 && "$GKI_ENABLE" == "true" ]]; then
    echo "PASS: check_gki_support enables GKI when defconfig exists"
else
    echo "FAIL: check_gki_support did not enable GKI"
    FAILURES=$((FAILURES+1))
fi

# Clean up
rm -rf "$TEST_DIR"

if [[ $FAILURES -eq 0 ]]; then
    echo "All tests passed!"
    exit 0
else
    echo "$FAILURES test(s) failed."
    exit $FAILURES
fi
