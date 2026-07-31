#!/bin/bash
# Test for check_root in flash-helper.sh

# Exit on any unhandled error
set -e

# Keep track of failures
FAILURES=0

echo "Running tests for check_root..."

# Setup temporary test environment
TEST_DIR=$(mktemp -d)
MOCK_BIN="${TEST_DIR}/bin"
mkdir -p "${MOCK_BIN}"
export PATH="${MOCK_BIN}:${PATH}"

# Create a safe copy of flash-helper.sh for sourcing (strip out the main execution)
sed 's/^main$//' flash-helper.sh > "${TEST_DIR}/flash-helper.sh"

# Mock log functions
echo 'function log_step() { echo "[STEP] $1"; }' >> "${TEST_DIR}/flash-helper.sh"
echo 'function log_info() { echo "[INFO] $1"; }' >> "${TEST_DIR}/flash-helper.sh"
echo 'function log_warn() { echo "[WARN] $1"; }' >> "${TEST_DIR}/flash-helper.sh"
echo 'function log_error() { echo "[ERROR] $1"; }' >> "${TEST_DIR}/flash-helper.sh"

# Source the modified script
set +e
source "${TEST_DIR}/flash-helper.sh"
set -e

# Helper for testing assertions
assert_failure() {
    local cmd="$1"
    local desc="$2"
    echo -n "Test: $desc ... "
    if eval "$cmd" > /dev/null 2>&1; then
        echo "FAILED (Expected failure, got success)"
        FAILURES=$((FAILURES + 1))
    else
        echo "PASSED"
    fi
}

assert_success() {
    local cmd="$1"
    local desc="$2"
    echo -n "Test: $desc ... "
    if eval "$cmd" > /dev/null 2>&1; then
        echo "PASSED"
    else
        echo "FAILED (Expected success, got failure)"
        FAILURES=$((FAILURES + 1))
    fi
}

# Test Case 1: Root access available (adb shell "su -c 'id'" returns uid=0)
cat << 'MOCK' > "${MOCK_BIN}/adb"
#!/bin/bash
if [[ "$*" == "shell su -c 'id'" ]]; then
    echo "uid=0(root) gid=0(root)"
    exit 0
fi
exit 1
MOCK
chmod +x "${MOCK_BIN}/adb"

assert_success "check_root" "Root available"

# Test Case 2: Root access not available (adb shell "su -c 'id'" returns something else)
cat << 'MOCK' > "${MOCK_BIN}/adb"
#!/bin/bash
if [[ "$*" == "shell su -c 'id'" ]]; then
    echo "uid=2000(shell) gid=2000(shell)"
    exit 0
fi
exit 1
MOCK
chmod +x "${MOCK_BIN}/adb"

assert_failure "check_root" "Root not available"

# Test Case 3: adb command fails
cat << 'MOCK' > "${MOCK_BIN}/adb"
#!/bin/bash
exit 1
MOCK
chmod +x "${MOCK_BIN}/adb"

assert_failure "check_root" "adb command fails"

# Test Case 4: adb command returns empty string
cat << 'MOCK' > "${MOCK_BIN}/adb"
#!/bin/bash
if [[ "$*" == "shell su -c 'id'" ]]; then
    exit 0
fi
exit 1
MOCK
chmod +x "${MOCK_BIN}/adb"

assert_failure "check_root" "adb command returns empty string"

# Clean up
rm -rf "${TEST_DIR}"

if [ $FAILURES -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "$FAILURES test(s) failed."
    exit $FAILURES
fi
