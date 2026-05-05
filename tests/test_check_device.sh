#!/bin/bash

# Test script for check_device function in flash-helper.sh

TEST_DIR=$(mktemp -d)
MOCK_BIN="${TEST_DIR}/mock_bin"
mkdir -p "${MOCK_BIN}"

# Create a mock fastboot
cat << 'EOF' > "${MOCK_BIN}/fastboot"
#!/bin/bash
echo "Mock fastboot executing with args: $@"
EOF
chmod +x "${MOCK_BIN}/fastboot"

# Create a mock adb
cat << 'EOF' > "${MOCK_BIN}/adb"
#!/bin/bash
if [[ "$1" == "devices" ]]; then
    if [[ "${MOCK_ADB_NO_DEVICES}" == "1" ]]; then
        echo "List of devices attached"
        echo ""
    else
        echo "List of devices attached"
        echo "1234567890abcdef    device"
    fi
elif [[ "$1" == "shell" && "$2" == "getprop" ]]; then
    if [[ "$3" == "ro.product.device" ]]; then
        echo "${MOCK_DEVICE:-unknown}"
    elif [[ "$3" == "ro.product.model" ]]; then
        echo "${MOCK_MODEL:-unknown}"
    fi
else
    echo "Unknown adb command: $@"
fi
EOF
chmod +x "${MOCK_BIN}/adb"

export PATH="${MOCK_BIN}:${PATH}"

# Override the read builtin to simulate user input
read() {
    # If the last argument is the variable name (e.g., read -p "Prompt" confirm)
    local var_name="${!#}"
    if [[ "${var_name}" != "-p" ]] && [[ ! "${var_name}" =~ ^[\"\'].*[\"\']$ ]] && [[ -n "${var_name}" ]] && [[ "${var_name}" != *" "* ]]; then
        eval "${var_name}=\"${MOCK_READ_INPUT}\""
    fi
    REPLY="${MOCK_READ_INPUT}"
}

# Create a safe copy of flash-helper.sh to source (removing the bare `main` call)
# Assuming tests run from the repo root
sed 's/^main$//' flash-helper.sh > "${TEST_DIR}/flash-helper-safe.sh"

# Source the safe script
source "${TEST_DIR}/flash-helper-safe.sh"
# Disable exit-on-error from the script
set +e

FAILURES=0

echo "Running tests for check_device..."

# Test Case 1: No ADB devices connected
export MOCK_ADB_NO_DEVICES=1
(check_device) > "${TEST_DIR}/out1" 2>&1
res=$?
if [[ $res -ne 1 ]]; then
    echo "FAIL: Test Case 1 (No ADB devices) returned $res, expected 1"
    let FAILURES++
else
    echo "PASS: Test Case 1 (No ADB devices)"
fi

# Test Case 2: Device connected, exact codename match
export MOCK_ADB_NO_DEVICES=0
export MOCK_DEVICE="gts8wifi"
export MOCK_MODEL="SM-X700"
(check_device) > "${TEST_DIR}/out2" 2>&1
res=$?
if [[ $res -ne 0 ]]; then
    echo "FAIL: Test Case 2 (Exact match gts8wifi) returned $res, expected 0"
    let FAILURES++
else
    echo "PASS: Test Case 2 (Exact match gts8wifi)"
fi

# Test Case 3: Device connected, pattern codename match (*gts8*)
export MOCK_ADB_NO_DEVICES=0
export MOCK_DEVICE="gts8plus"
export MOCK_MODEL="SM-X800"
(check_device) > "${TEST_DIR}/out3" 2>&1
res=$?
if [[ $res -ne 0 ]]; then
    echo "FAIL: Test Case 3 (Pattern match gts8plus) returned $res, expected 0"
    let FAILURES++
else
    echo "PASS: Test Case 3 (Pattern match gts8plus)"
fi

# Test Case 4: Device connected, mismatch, user confirms
export MOCK_ADB_NO_DEVICES=0
export MOCK_DEVICE="pixel6"
export MOCK_MODEL="Pixel 6"
export MOCK_READ_INPUT="y"
(check_device) > "${TEST_DIR}/out4" 2>&1
res=$?
if [[ $res -ne 0 ]]; then
    echo "FAIL: Test Case 4 (Mismatch, user confirms) returned $res, expected 0"
    let FAILURES++
else
    echo "PASS: Test Case 4 (Mismatch, user confirms)"
fi

# Test Case 5: Device connected, mismatch, user rejects
export MOCK_ADB_NO_DEVICES=0
export MOCK_DEVICE="pixel6"
export MOCK_MODEL="Pixel 6"
export MOCK_READ_INPUT="n"
(check_device) > "${TEST_DIR}/out5" 2>&1
res=$?
if [[ $res -ne 1 ]]; then
    echo "FAIL: Test Case 5 (Mismatch, user rejects) returned $res, expected 1"
    let FAILURES++
else
    echo "PASS: Test Case 5 (Mismatch, user rejects)"
fi

# Cleanup
rm -rf "${TEST_DIR}"

if [[ $FAILURES -gt 0 ]]; then
    echo "$FAILURES tests failed."
else
    echo "All tests passed successfully."
fi

exit $FAILURES
