#!/bin/bash

# Setup mock environment
export MOCK_DIR=$(mktemp -d)
export PATH="${MOCK_DIR}:${PATH}"

# Mock logging functions to prevent output
log_step() { echo "log_step: $1" >> "${MOCK_DIR}/mock.log"; }
log_info() { echo "log_info: $1" >> "${MOCK_DIR}/mock.log"; }
log_warn() { echo "log_warn: $1" >> "${MOCK_DIR}/mock.log"; }
log_error() { echo "log_error: $1" >> "${MOCK_DIR}/mock.log"; }

# Create mock adb command
cat << 'MOCK_ADB' > "${MOCK_DIR}/adb"
#!/bin/bash
echo "adb called with args: \$@" >> "${MOCK_DIR}/adb.log"

if [[ "$1" == "shell" && "$2" == "su -c 'id'" ]]; then
    if [[ -f "${MOCK_DIR}/mock_root_success" ]]; then
        echo "uid=0(root) gid=0(root) groups=0(root)"
    else
        echo "uid=2000(shell) gid=2000(shell) groups=2000(shell)"
    fi
fi
MOCK_ADB
chmod +x "${MOCK_DIR}/adb"

# Source the target script
source ./flash-helper.sh > /dev/null
set +e

FAILURES=0

# Test 1: Root access not available
check_root > "${MOCK_DIR}/test1.log" 2>&1
result=$?
if [[ $result -ne 1 ]]; then
    echo "Test 1 Failed: Expected check_root to return 1 when root is not available, got $result"
    cat "${MOCK_DIR}/test1.log"
    ((FAILURES++))
else
    echo "Test 1 Passed: Root access not available"
fi

# Test 2: Root access available
touch "${MOCK_DIR}/mock_root_success"
check_root > "${MOCK_DIR}/test2.log" 2>&1
result=$?
if [[ $result -ne 0 ]]; then
    echo "Test 2 Failed: Expected check_root to return 0 when root is available, got $result"
    cat "${MOCK_DIR}/test2.log"
    ((FAILURES++))
else
    echo "Test 2 Passed: Root access available"
fi

rm -rf "${MOCK_DIR}"
exit $FAILURES
