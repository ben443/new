#!/bin/bash

# Setup mock environment
export MOCK_DIR=$(mktemp -d)
export PATH="${MOCK_DIR}:${PATH}"

# Mock date
cat << 'MOCK_DATE' > "${MOCK_DIR}/date"
#!/bin/bash
echo "20230101_120000"
MOCK_DATE
chmod +x "${MOCK_DIR}/date"

# Mock adb
cat << 'MOCK_ADB' > "${MOCK_DIR}/adb"
#!/bin/bash
echo "adb called with args: $@" >> "${MOCK_DIR}/adb.log"

if [[ "$1" == "pull" ]]; then
    if [[ "${MOCK_ADB_PULL_FAIL}" == "1" ]]; then
        exit 1
    fi

    if [[ "${MOCK_ADB_PULL_TOUCH}" == "1" ]]; then
        # $3 is the destination path
        touch "$3"
    fi

    exit 0
fi


if [[ "$1" == "shell" ]]; then
    exit 0
fi

MOCK_ADB
_mock_adb_sed="${MOCK_DIR}/adb"
sed -i "s/exit 1/zapped_exit 1/g" "$_mock_adb_sed"
sed -i "s/exit 0/zapped_exit 0/g" "$_mock_adb_sed"
sed -i "s/zapped_exit/exit/g" "${MOCK_DIR}/adb"
chmod +x "${MOCK_DIR}/adb"

# Copy and source the target script safely to isolate SCRIPT_DIR
cp ./flash-helper.sh "${MOCK_DIR}/flash-helper.sh"
# Comment out set -e to prevent the test suite from aborting prematurely on expected errors
sed -i 's/^set -e/# set -e/' "${MOCK_DIR}/flash-helper.sh"
source "${MOCK_DIR}/flash-helper.sh" > /dev/null

# Turn off set -e just in case
set +e

# Mock logging functions to prevent output
log_step() { echo "log_step: $1" >> "${MOCK_DIR}/mock.log"; }
log_info() { echo "log_info: $1" >> "${MOCK_DIR}/mock.log"; }
log_warn() { echo "log_warn: $1" >> "${MOCK_DIR}/mock.log"; }
log_error() { echo "log_error: $1" >> "${MOCK_DIR}/mock.log"; }
export -f log_step log_info log_warn log_error

FAILURES=0

# Test 1: adb pull fails
export MOCK_ADB_PULL_FAIL=1
export MOCK_ADB_PULL_TOUCH=0
(backup_kernel) > "${MOCK_DIR}/test1.log" 2>&1
result=$?
if [[ $result -ne 1 ]]; then
    echo "Test 1 Failed: Expected backup_kernel to return 1 when adb pull fails, got $result"
    cat "${MOCK_DIR}/test1.log"
    ((FAILURES++))
else
    echo "Test 1 Passed: adb pull fails"
fi


# Test 2: adb pull succeeds, but file doesn't exist
export MOCK_ADB_PULL_FAIL=0
export MOCK_ADB_PULL_TOUCH=0
(backup_kernel) > "${MOCK_DIR}/test2.log" 2>&1
result=$?
if [[ $result -ne 1 ]]; then
    echo "Test 2 Failed: Expected backup_kernel to return 1 when file is not created, got $result"
    cat "${MOCK_DIR}/test2.log"
    ((FAILURES++))
else
    echo "Test 2 Passed: file not created after pull"
fi


# Test 3: Happy path
export MOCK_ADB_PULL_FAIL=0
export MOCK_ADB_PULL_TOUCH=1
(backup_kernel) > "${MOCK_DIR}/test3.log" 2>&1
result=$?
if [[ $result -ne 0 ]]; then
    echo "Test 3 Failed: Expected backup_kernel to return 0 on success, got $result"
    cat "${MOCK_DIR}/test3.log"
    ((FAILURES++))
else
    if [[ ! -f "${SCRIPT_DIR}/backups/latest_backup.txt" ]]; then
        echo "Test 3 Failed: latest_backup.txt not created"
        ((FAILURES++))
    else
        echo "Test 3 Passed: Happy path"
    fi

fi


rm -rf "${MOCK_DIR}"
exit $FAILURES
