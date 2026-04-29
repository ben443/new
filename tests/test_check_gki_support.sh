#!/bin/bash

# Unit tests for check_gki_support function in build-nethunter.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Get the directory of the test script
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TEST_DIR}/.." && pwd)"

# Source the script under test
source "${REPO_ROOT}/build-nethunter.sh"

# Mock helper functions to avoid cluttering output and potential side effects
log_step() { :; }
log_info() { :; }
log_warn() { :; }
log_error() { :; }

# Setup a temporary workspace for mocking the kernel tree
setup_mock_kernel_tree() {
    MOCK_ROOT=$(mktemp -d)
    MOCK_KERNEL_DIR="${MOCK_ROOT}/kernel"
    mkdir -p "${MOCK_KERNEL_DIR}/arch/arm64/configs"

    # Override KERNEL_DIR for the test
    KERNEL_DIR="${MOCK_KERNEL_DIR}"
}

cleanup_mock_kernel_tree() {
    if [ -n "${MOCK_ROOT}" ] && [ -d "${MOCK_ROOT}" ]; then
        rm -rf "${MOCK_ROOT}"
    fi
}

# Assert helper
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [ "${expected}" == "${actual}" ]; then
        echo -e "${GREEN}[PASS]${NC} ${message}"
    else
        echo -e "${RED}[FAIL]${NC} ${message}"
        echo "       Expected: ${expected}"
        echo "       Actual:   ${actual}"
        cleanup_mock_kernel_tree
        exit 1
    fi
}

echo "Running tests for check_gki_support..."

# Test Case 1: GKI defconfig exists at ${GKI_DEFCONFIG}
(
    setup_mock_kernel_tree
    GKI_DEFCONFIG="custom_gki_defconfig"
    touch "${MOCK_KERNEL_DIR}/arch/arm64/configs/custom_gki_defconfig"

    check_gki_support

    assert_equals "true" "${GKI_ENABLE}" "GKI_ENABLE should be true when GKI_DEFCONFIG exists"
    assert_equals "custom_gki_defconfig" "${GKI_DEFCONFIG}" "GKI_DEFCONFIG should remain unchanged"
    cleanup_mock_kernel_tree
) || exit 1

# Test Case 2: GKI defconfig exists at fallback gki_defconfig
(
    setup_mock_kernel_tree
    GKI_DEFCONFIG="non_existent_defconfig"
    touch "${MOCK_KERNEL_DIR}/arch/arm64/configs/gki_defconfig"

    check_gki_support

    assert_equals "true" "${GKI_ENABLE}" "GKI_ENABLE should be true when fallback gki_defconfig exists"
    assert_equals "gki_defconfig" "${GKI_DEFCONFIG}" "GKI_DEFCONFIG should be updated to fallback"
    cleanup_mock_kernel_tree
) || exit 1

# Test Case 3: GKI defconfig does not exist
(
    setup_mock_kernel_tree
    GKI_DEFCONFIG="non_existent_defconfig"

    check_gki_support

    assert_equals "false" "${GKI_ENABLE}" "GKI_ENABLE should be false when no GKI defconfig exists"
    cleanup_mock_kernel_tree
) || exit 1

# Test Case 4: GKI vendor module support detected via drivers/staging/gki
(
    setup_mock_kernel_tree
    touch "${MOCK_KERNEL_DIR}/arch/arm64/configs/gki_defconfig"
    mkdir -p "${MOCK_KERNEL_DIR}/drivers/staging/gki"

    check_gki_support

    assert_equals "true" "${GKI_BUILD_VENDOR_MODULES}" "GKI_BUILD_VENDOR_MODULES should be true when drivers/staging/gki exists"
    cleanup_mock_kernel_tree
) || exit 1

# Test Case 5: GKI vendor module support detected via Kbuild.gki
(
    setup_mock_kernel_tree
    touch "${MOCK_KERNEL_DIR}/arch/arm64/configs/gki_defconfig"
    touch "${MOCK_KERNEL_DIR}/Kbuild.gki"

    check_gki_support

    assert_equals "true" "${GKI_BUILD_VENDOR_MODULES}" "GKI_BUILD_VENDOR_MODULES should be true when Kbuild.gki exists"
    cleanup_mock_kernel_tree
) || exit 1

# Test Case 6: No GKI vendor module support detected
(
    setup_mock_kernel_tree
    touch "${MOCK_KERNEL_DIR}/arch/arm64/configs/gki_defconfig"

    check_gki_support

    assert_equals "false" "${GKI_BUILD_VENDOR_MODULES}" "GKI_BUILD_VENDOR_MODULES should be false when no vendor support files exist"
    cleanup_mock_kernel_tree
) || exit 1

echo "All tests passed!"
