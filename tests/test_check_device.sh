#!/bin/bash

# Setup mock environment
export MOCK_DIR=$(mktemp -d)
export PATH="${MOCK_DIR}:${PATH}"

# Mock logging functions to prevent output
log_step() { echo "log_step: $1" >> "${MOCK_DIR}/mock.log"; }
log_info() { echo "log_info: $1" >> "${MOCK_DIR}/mock.log"; }
log_warn() { echo "log_warn: $1" >> "${MOCK_DIR}/mock.log"; }
log_error() { echo "log_error: $1" >> "${MOCK_DIR}/mock.log"; }

# Mock read to automatically answer 'y' or 'n'
read() {
    # If the mock asks for confirmation, provide default 'y'
    echo "read called with args: $@" >> "${MOCK_DIR}/mock.log"
    confirm="y"
}

# Create mock adb command
cat << MOCK > "${MOCK_DIR}/adb"
#!/bin/bash
echo "adb called with args: \$@" >> "${MOCK_DIR}/adb.log"

if [[ "\$1" == "devices" ]]; then
    if [[ -f "${MOCK_DIR}/no_device" ]]; then
        echo "List of devices attached"
        echo ""
    else
        echo "List of devices attached"
        echo "1234567890abcde    device"
    fi
elif [[ "\$1" == "shell" && "\$2" == "getprop" ]]; then
    if [[ "\$3" == "ro.product.device" ]]; then
        cat "${MOCK_DIR}/mock_device_name" 2>/dev/null || echo "gts8wifi"
    elif [[ "\$3" == "ro.product.model" ]]; then
        cat "${MOCK_DIR}/mock_model_name" 2>/dev/null || echo "SM-X700"
    fi
fi
MOCK
chmod +x "${MOCK_DIR}/adb"

# Source the target script
source ./flash-helper.sh > /dev/null
set +e

# Set defaults
export DEVICE_CODENAME="gts8wifi"

FAILURES=0

# Test 1: No device connected
touch "${MOCK_DIR}/no_device"
check_device > "${MOCK_DIR}/test1.log" 2>&1
result=$?
if [[ $result -ne 1 ]]; then
    echo "Test 1 Failed: Expected check_device to return 1 when no device is connected, got $result"
    cat "${MOCK_DIR}/test1.log"
    ((FAILURES++))
else
    echo "Test 1 Passed: No device connected"
fi
rm -f "${MOCK_DIR}/no_device"

# Test 2: Correct device connected (gts8wifi)
echo "gts8wifi" > "${MOCK_DIR}/mock_device_name"
check_device > "${MOCK_DIR}/test2.log" 2>&1
result=$?
if [[ $result -ne 0 ]]; then
    echo "Test 2 Failed: Expected check_device to return 0 for matching device, got $result"
    cat "${MOCK_DIR}/test2.log"
    ((FAILURES++))
else
    echo "Test 2 Passed: Correct device connected"
fi

# Test 3: Incorrect device connected, user confirms
echo "wrongdevice" > "${MOCK_DIR}/mock_device_name"
# Re-mock read to answer 'y'
read() { confirm="y"; REPLY="y"; }
check_device > "${MOCK_DIR}/test3.log" 2>&1
result=$?
if [[ $result -ne 0 ]]; then
    echo "Test 3 Failed: Expected check_device to return 0 when user confirms mismatch, got $result"
    cat "${MOCK_DIR}/test3.log"
    ((FAILURES++))
else
    echo "Test 3 Passed: Incorrect device with confirmation"
fi

# Test 4: Incorrect device connected, user denies
echo "wrongdevice" > "${MOCK_DIR}/mock_device_name"
# Re-mock read to answer 'n'
read() { confirm="n"; REPLY="n"; }
check_device > "${MOCK_DIR}/test4.log" 2>&1
result=$?
if [[ $result -ne 1 ]]; then
    echo "Test 4 Failed: Expected check_device to return 1 when user denies mismatch, got $result"
    cat "${MOCK_DIR}/test4.log"
    ((FAILURES++))
else
    echo "Test 4 Passed: Incorrect device with denial"
fi

rm -rf "${MOCK_DIR}"
exit $FAILURES
