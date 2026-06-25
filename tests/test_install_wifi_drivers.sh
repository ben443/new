#!/bin/bash

# Setup mock environment
export MOCK_DIR=$(mktemp -d)
export PATH="${MOCK_DIR}:${PATH}"

# Mock logging functions to prevent output
log_step() { echo "log_step: $1" >> "${MOCK_DIR}/mock.log"; }
log_info() { echo "log_info: $1" >> "${MOCK_DIR}/mock.log"; }
log_warn() { echo "log_warn: $1" >> "${MOCK_DIR}/mock.log"; }
log_error() { echo "log_error: $1" >> "${MOCK_DIR}/mock.log"; }

export MOCK_CHECK_DEVICE=0
export MOCK_CHECK_ROOT=0
export MOCK_ADB_PUSH_RESULT=0

# Create mock adb command
cat << 'MOCK_ADB' > "${MOCK_DIR}/adb"
#
!/bin/bash
echo "adb $*" >> "${MOCK_DIR}/adb.log"

if [[ "$1" == "push" ]]; then
    if [[ $MOCK_CHECK_DEVICE -ne 0 ]]; then
		exit 1
	fi
    if [[ $MOCK_CHECK_ROOT -ne 0 ]]; then
		exit 1
	fi
	if [[ $MOCK_ADB_PUSH_RESULT -ne 0 ]]; then
		exit 1
	fi
	exit 0
fi

exit 0
MOCK_ADB
chmod +x "${MOCK_DIR}/adb"

# Source the target script safely
sed 's/^main "$@"$/# main "$@"/' flash-helper.sh | sed 's/exit 0/return 0/g' | sed 's/exit 1/return 1/g' > "${MOCK_DIR}/flash-helper-test.sh"
source "${MOCK_DIR}/flash-helper-test.sh" > /dev/null
set +e

# Override check_device and check_root
check_device() { return $MOCK_CHECK_DEVICE; }
check_root() { return $MOCK_CHECK_ROOT; }

# Mock OUTPUT_DIR
export OUTPUT_DIR="${MOCK_DIR}/output"

FAILURES=0

# Test 1: check_device fails
export MOCK_CHECK_DEVICE=1
(install_wifi_drivers) > "${MOCK_DIR}/test1.log" 2>&1
result=$?
if [[ $result -ne 1 ]]; then
    echo "Test 1 Failed: Expected install_wifi_drivers to return 1 when check_device fails, got $result"
    ((FAILURES++))
else
    echo "Test 1 Passed: check_device fails"
fi

# Test 2: check_root fails
export MOCK_CHECK_DEVICE=0
export MOCK_CHECK_ROOT=1
(install_wifi_drivers) > "${MOCK_DIR}/test2.log" 2>&1
result=$?
if [[ $result -ne 1 ]]; then
    echo "Test 2 Failed: Expected install_wifi_drivers to return 1 when check_root fails, got $result"
    ((FAILURES++))
else
    echo "Test 2 Passed: check_root fails"
fi


# Test 3: Modules directory not found
export MOCK_CHECK_DEVICE=0
export MOCK_CHECK_ROOT=0
# Ensure MODULES_DIR does not exist
rm -rf "${OUTPUT_DIR}/modules"
#install_wifi_drivers > "${MOCK_DIR}/test3.log" 2>&1
(install_wifi_drivers) > "${MOCK_DIR}/test3.log" 2>&1
result=$?
if [[ $result -ne 1 ]]; then
    echo "Test 3 Failed: Expected install_wifi_drivers to return 1 when modules dir missing, got $result"
    ((FAILURES++))
else
    echo "Test 3 Passed: Modules directory not found"
fi

# Test 4: adb push fails
export MOCK_CHECK_DEVICE=0
export MOCK_CHECK_ROOT=0
export MOCK_ADB_PUSH_RESULT=1
mkdir -p "${OUTPUT_DIR}/modules"
> "${MOCK_DIR}/adb.log"
(install_wifi_drivers) > "${MOCK_DIR}/test4.log" 2>&1
result=$?
if [[ $result -ne 1 ]]; then
    echo "Test 4 Failed: Expected install_wifi_drivers to return 1 when adb push fails, got $result"
    ((FAILURES++))
else
    echo "Test 4 Passed: adb push fails"
fi

# Test 5: Success path - check adb commands
export MOCK_CHECK_DEVICE=0
export MOCK_CHECK_ROOT=0
mkdir -p "${OUTPUT_DIR}/modules"
export MOCK_ADB_PUSH_RESULT=0
> "${MOCK_DIR}/adb.log"

(install_wifi_drivers) > "${MOCK_DIR}/test5.log" 2>&1
result=$?
if [[ $result -ne 0 ]]; then
    echo "Test 5 Failed: Expected install_wifi_drivers to return 0 on success, got $result"
    ((FAILURES++))
else
    # Check if correct adb commands were executed
    grep -F -q "adb push ${OUTPUT_DIR}/modules /data/local/tmp/nethunter_modules" "${MOCK_DIR}/adb.log" || { echo "Test 5 Failed: Missing adb push"; ((FAILURES++)); }
    grep -F -q "adb shell su -c 'cp /data/local/tmp/nethunter_modules/*.ko /system/lib/modules/'" "${MOCK_DIR}/adb.log" || { echo "Test 5 Failed: Missing module cp"; ((FAILURES++)); }
    grep -F -q "adb shell su -c 'modprobe 88XXau'" "${MOCK_DIR}/adb.log" || { echo "Test 5 Failed: Missing modprobe 88XXau"; ((FAILURES++)); }
    grep -F -q "adb shell su -c 'modprobe r8188eu'" "${MOCK_DIR}/adb.log" || { echo "Test 5 Failed: Missing modprobe r8188eu"; ((FAILURES++)); }
    grep -F -q "adb shell su -c 'modprobe ath9k_htc'" "${MOCK_DIR}/adb.log" || { echo "Test 5 Failed: Missing modprobe ath9k_htc"; ((FAILURES++)); }
    grep -F -q "adb shell su -c 'modprobe mt7601u'" "${MOCK_DIR}/adb.log" || { echo "Test 5 Failed: Missing modprobe mt7601u"; ((FAILURES++)); }
    grep -F -q "adb shell rm -rf /data/local/tmp/nethunter_modules" "${MOCK_DIR}/adb.log" || { echo "Test 5 Failed: Missing cleanup"; ((FAILURES++)); }

    if [[ $FAILURES -eq 0 ]]; then
        echo "Test 5 Passed: Successful execution"
    fi
fi

if [[ $FAILURES -ne 0 ]]; then
    echo "ADB log for test 5:"
    cat "${MOCK_DIR}/adb.log"
    echo "/adb"
    echo "test5.log"
    cat "${MOCK_DIR}/test5.log"
    echo "/"
    echo "test4.log"
    cat "${MOCK_DIR}/test4.log"
    echo "/"
    echo "test3.log"
    cat "${MOCK_DIR}/test3.log"
    echo "/"
    echo "test2.log"
    cat "${MOCK_DIR}/test2.log"
    echo "/"
    echo "test1.log"
    cat "${MOCK_DIR}/test1.log"
    echo "/"
fi

rm -rf "${MOCK_DIR}"
echo "Failures: $FAILURES"
if [[ $FAILURES -eq 0 ]]; then sh -c 'exit 0'; else sh -c 'exit 1'; fi
