#!/bin/bash

# Setup mock environment
export MOCK_DIR=$(mktemp -d)

# Mock log_error to capture error messages
log_error() { echo "log_error: $1" >> "${MOCK_DIR}/mock.log"; }

# Extract the validate_tarball function from build-nethunter.sh to test it in isolation
sed -n '/validate_tarball() {/,/^}/p' ./build-nethunter.sh > "${MOCK_DIR}/func.sh"
source "${MOCK_DIR}/func.sh"

FAILURES=0

# Test 1: Valid tarball
mkdir -p "${MOCK_DIR}/valid_dir"
touch "${MOCK_DIR}/valid_dir/test.txt"
tar -cf "${MOCK_DIR}/valid.tar" -C "${MOCK_DIR}" valid_dir

validate_tarball "${MOCK_DIR}/valid.tar" > "${MOCK_DIR}/test1.log" 2>&1
result=$?
if [[ $result -ne 0 ]]; then
    echo "Test 1 Failed: Expected valid tarball to return 0, got $result"
    ((FAILURES++))
else
    echo "Test 1 Passed: Valid tarball accepted"
fi

# Test 2: Invalid/corrupt tarball
echo "corrupted data" > "${MOCK_DIR}/invalid.tar"
validate_tarball "${MOCK_DIR}/invalid.tar" > "${MOCK_DIR}/test2.log" 2>&1
result=$?
if [[ $result -ne 1 ]]; then
    echo "Test 2 Failed: Expected corrupt tarball to return 1, got $result"
    ((FAILURES++))
else
    echo "Test 2 Passed: Corrupt tarball rejected"
fi

# Test 3: Tarball with absolute path
# Use python to create a malicious tar as standard tar forbids absolute paths
python3 -c "
import tarfile
with tarfile.open('${MOCK_DIR}/absolute.tar', 'w') as tar:
    info = tarfile.TarInfo(name='/etc/passwd')
    info.size = 0
    tar.addfile(info)
"
validate_tarball "${MOCK_DIR}/absolute.tar" > "${MOCK_DIR}/test3.log" 2>&1
result=$?
if [[ $result -ne 1 ]]; then
    echo "Test 3 Failed: Expected tarball with absolute path to return 1, got $result"
    ((FAILURES++))
else
    echo "Test 3 Passed: Tarball with absolute path rejected"
fi

# Test 4: Tarball with directory traversal (../)
python3 -c "
import tarfile
with tarfile.open('${MOCK_DIR}/traversal.tar', 'w') as tar:
    info = tarfile.TarInfo(name='../evil.sh')
    info.size = 0
    tar.addfile(info)
"
validate_tarball "${MOCK_DIR}/traversal.tar" > "${MOCK_DIR}/test4.log" 2>&1
result=$?
if [[ $result -ne 1 ]]; then
    echo "Test 4 Failed: Expected tarball with path traversal to return 1, got $result"
    ((FAILURES++))
else
    echo "Test 4 Passed: Tarball with path traversal rejected"
fi

rm -rf "${MOCK_DIR}"

exit $FAILURES
