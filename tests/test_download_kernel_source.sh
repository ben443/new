#!/bin/bash

# A simple bash test framework

# strict mode
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Globals to track test results
TEST_COUNT=0
TEST_PASSED=0
TEST_FAILED=0

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

test_start() {
    echo "Running test: $1"
    TEST_COUNT=$((TEST_COUNT + 1))
}

test_pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    TEST_PASSED=$((TEST_PASSED + 1))
}

test_fail() {
    echo -e "${RED}FAIL${NC}: $1"
    TEST_FAILED=$((TEST_FAILED + 1))
}

# --- Prepare the code under test ---
TEST_WORKSPACE="/tmp/nethunter_test_$$"
mkdir -p "$TEST_WORKSPACE"

TEST_SOURCE_FILE="$TEST_WORKSPACE/build-nethunter-testable.sh"
# Remove the call to main at the end of the script, so we can source it safely.
# Look for the exact main invocation at the end of the file.
sed '/^main "$@"/d' "$ROOT_DIR/build-nethunter.sh" > "$TEST_SOURCE_FILE"

# --- Setup mocks ---
setup_mocks() {
    # Reset mock call logs
    > "$TEST_WORKSPACE/git_calls.log"
    > "$TEST_WORKSPACE/rm_calls.log"
}

# Mock for git
git() {
    # log the call
    echo "git $@" >> "$TEST_WORKSPACE/git_calls.log"

    # for git clone, fake the clone by making the target dir
    if [ "$1" = "clone" ]; then
        mkdir -p "${KERNEL_DIR}"
    fi
}
export -f git

# Mock for rm
rm() {
    echo "rm $@" >> "$TEST_WORKSPACE/rm_calls.log"
    if [ "$1" = "-rf" ] || [ "$1" = "-r" ]; then
        if [ "$2" = "${KERNEL_DIR}" ]; then
            /bin/rm -rf "$2"
        else
            /bin/rm -rf "$2"
        fi
    else
        /bin/rm "$@"
    fi
}
export -f rm

# Source the file under test
source "$TEST_SOURCE_FILE"

# Re-override colors after source
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Mock setup
KERNEL_DIR="$TEST_WORKSPACE/kernel_dir"

teardown() {
    # cleanup temp dir and files
    /bin/rm -rf "$TEST_WORKSPACE"
}

trap teardown EXIT

# --- Tests ---

# Test 1: KERNEL_DIR does not exist
test_kernel_dir_does_not_exist() {
    test_start "KERNEL_DIR does not exist"
    setup_mocks

    /bin/rm -rf "${KERNEL_DIR}"

    # Run target function
    # Subshell to protect the current directory from `cd` inside `download_kernel_source`
    ( download_kernel_source )

    if grep -q "rm -rf ${KERNEL_DIR}" "$TEST_WORKSPACE/rm_calls.log"; then
        test_fail "rm -rf should not be called when KERNEL_DIR does not exist"
    else
        test_pass "rm -rf not called"
    fi

    if grep -q "git clone" "$TEST_WORKSPACE/git_calls.log"; then
        test_pass "git clone called"
    else
        test_fail "git clone not called"
    fi

    if grep -q "git submodule update" "$TEST_WORKSPACE/git_calls.log"; then
        test_pass "git submodule update called"
    else
        test_fail "git submodule update not called"
    fi
}

# Test 2: KERNEL_DIR exists
test_kernel_dir_exists() {
    test_start "KERNEL_DIR exists"
    setup_mocks

    mkdir -p "${KERNEL_DIR}"

    # Run target function
    ( download_kernel_source )

    if grep -q "rm -rf ${KERNEL_DIR}" "$TEST_WORKSPACE/rm_calls.log"; then
        test_pass "rm -rf called"
    else
        test_fail "rm -rf should be called when KERNEL_DIR exists"
    fi

    if grep -q "git clone" "$TEST_WORKSPACE/git_calls.log"; then
        test_pass "git clone called after rm"
    else
        test_fail "git clone not called"
    fi

    if grep -q "git submodule update" "$TEST_WORKSPACE/git_calls.log"; then
        test_pass "git submodule update called"
    else
        test_fail "git submodule update not called"
    fi
}

# Test 3: Submodule initialization fails
test_submodule_failure_ignored() {
    test_start "Submodule failure is ignored"
    setup_mocks

    # Redefine mock git to fail on submodule
    git() {
        echo "git $@" >> "$TEST_WORKSPACE/git_calls.log"
        if [ "$1" = "clone" ]; then
            mkdir -p "${KERNEL_DIR}"
        elif [ "$1" = "submodule" ]; then
            return 1 # Simulate failure
        fi
    }
    export -f git

    mkdir -p "${KERNEL_DIR}"

    # Should not abort script (because of || true)
    ( download_kernel_source )
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        test_pass "Function completes despite submodule failure"
    else
        test_fail "Function aborted on submodule failure"
    fi
}

# Run tests
test_kernel_dir_does_not_exist
test_kernel_dir_exists
test_submodule_failure_ignored

echo "--------------------------------"
echo "Tests run: $TEST_COUNT"
echo "Tests passed: $TEST_PASSED"
echo "Tests failed: $TEST_FAILED"

if [ $TEST_FAILED -gt 0 ]; then
    exit 1
fi
exit 0
