#!/bin/bash

# Setup mock environment
export MOCK_DIR=$(mktemp -d)
export KERNEL_DIR="${MOCK_DIR}"

# Mock logging functions to prevent output

# Create safe version of build-nethunter.sh
sed -e 's/^set -e/# set -e/' build-nethunter.sh > "${MOCK_DIR}/build-nethunter-safe.sh"

# Move mock definitions after sourcing
# Source the target script
source "${MOCK_DIR}/build-nethunter-safe.sh" > /dev/null
set +e
# Mock logging functions to prevent output
log_step() { echo "log_step: $1" >> "${MOCK_DIR}/mock.log"; }
log_info() { echo "log_info: $1" >> "${MOCK_DIR}/mock.log"; }
log_warn() { echo "log_warn: $1" >> "${MOCK_DIR}/mock.log"; }
log_error() { echo "log_error: $1" >> "${MOCK_DIR}/mock.log"; }

FAILURES=0

# Clean state before each test
reset_state() {
    rm -rf "${KERNEL_DIR}"/*
    mkdir -p "${KERNEL_DIR}/arch/arm64/configs"
    GKI_DEFCONFIG="custom_defconfig"
    GKI_ENABLE=""
    GKI_BUILD_VENDOR_MODULES=""
}

echo "Running Test 1: Custom GKI defconfig exists"
reset_state
touch "${KERNEL_DIR}/arch/arm64/configs/custom_defconfig"
GKI_DEFCONFIG="custom_defconfig"
check_gki_support > /dev/null 2>&1
if [[ "${GKI_ENABLE}" != "true" ]]; then
    echo "Test 1 Failed: Expected GKI_ENABLE='true', got '${GKI_ENABLE}'"
    ((FAILURES++))
else
    echo "Test 1 Passed"
fi
if [[ "${GKI_DEFCONFIG}" != "custom_defconfig" ]]; then
    echo "Test 1 Failed: Expected GKI_DEFCONFIG='custom_defconfig', got '${GKI_DEFCONFIG}'"
    ((FAILURES++))
fi

echo "Running Test 2: gki_defconfig exists (fallback)"
reset_state
GKI_DEFCONFIG="nonexistent_defconfig"
touch "${KERNEL_DIR}/arch/arm64/configs/gki_defconfig"
check_gki_support > /dev/null 2>&1
if [[ "${GKI_ENABLE}" != "true" ]]; then
    echo "Test 2 Failed: Expected GKI_ENABLE='true', got '${GKI_ENABLE}'"
    ((FAILURES++))
else
    echo "Test 2 Passed"
fi
if [[ "${GKI_DEFCONFIG}" != "gki_defconfig" ]]; then
    echo "Test 2 Failed: Expected GKI_DEFCONFIG='gki_defconfig', got '${GKI_DEFCONFIG}'"
    ((FAILURES++))
fi

echo "Running Test 3: No defconfig exists"
reset_state
check_gki_support > /dev/null 2>&1
if [[ "${GKI_ENABLE}" != "false" ]]; then
    echo "Test 3 Failed: Expected GKI_ENABLE='false', got '${GKI_ENABLE}'"
    ((FAILURES++))
else
    echo "Test 3 Passed"
fi

echo "Running Test 4: Vendor module support via drivers/staging/gki"
reset_state
touch "${KERNEL_DIR}/arch/arm64/configs/custom_defconfig"
mkdir -p "${KERNEL_DIR}/drivers/staging/gki"
check_gki_support > /dev/null 2>&1
if [[ "${GKI_BUILD_VENDOR_MODULES}" != "true" ]]; then
    echo "Test 4 Failed: Expected GKI_BUILD_VENDOR_MODULES='true', got '${GKI_BUILD_VENDOR_MODULES}'"
    ((FAILURES++))
else
    echo "Test 4 Passed"
fi

echo "Running Test 5: Vendor module support via Kbuild.gki"
reset_state
touch "${KERNEL_DIR}/Kbuild.gki"
check_gki_support > /dev/null 2>&1
if [[ "${GKI_BUILD_VENDOR_MODULES}" != "true" ]]; then
    echo "Test 5 Failed: Expected GKI_BUILD_VENDOR_MODULES='true', got '${GKI_BUILD_VENDOR_MODULES}'"
    ((FAILURES++))
else
    echo "Test 5 Passed"
fi

echo "Running Test 6: No vendor module support"
reset_state
check_gki_support > /dev/null 2>&1
if [[ "${GKI_BUILD_VENDOR_MODULES}" != "false" ]]; then
    echo "Test 6 Failed: Expected GKI_BUILD_VENDOR_MODULES='false', got '${GKI_BUILD_VENDOR_MODULES}'"
    ((FAILURES++))
else
    echo "Test 6 Passed"
fi

rm -rf "${MOCK_DIR}"
exit $FAILURES
