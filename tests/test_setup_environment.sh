#!/bin/bash

# Test for setup_environment function

# Mock variables
SCRIPT_DIR="$(pwd)"
BUILD_DIR="${SCRIPT_DIR}/test_build"
TOOLCHAIN_DIR="${BUILD_DIR}/test_toolchains"
OUTPUT_DIR="${SCRIPT_DIR}/test_output"
MODULES_DIR="${OUTPUT_DIR}/test_modules"

# Mock commands
sudo() {
    echo "$@" >> "mock_sudo.log"
}

log_step() {
    # Mock log_step
    :
}

log_info() {
    # Mock log_info
    :
}

# Extract and source the setup_environment function
sed -n '/setup_environment() {/,/^}/p' build-nethunter.sh > setup_env_only.sh
source setup_env_only.sh

test_setup_environment() {
    echo "Running test_setup_environment..."

    # Cleanup before test
    rm -rf "${BUILD_DIR}" "${OUTPUT_DIR}" mock_sudo.log

    # Run the function
    setup_environment > /dev/null

    # Verify directories were created
    local failed=0

    if [[ ! -d "${BUILD_DIR}" ]]; then
        echo "FAIL: BUILD_DIR was not created"
        failed=1
    fi

    if [[ ! -d "${TOOLCHAIN_DIR}" ]]; then
        echo "FAIL: TOOLCHAIN_DIR was not created"
        failed=1
    fi

    if [[ ! -d "${OUTPUT_DIR}" ]]; then
        echo "FAIL: OUTPUT_DIR was not created"
        failed=1
    fi

    if [[ ! -d "${MODULES_DIR}" ]]; then
        echo "FAIL: MODULES_DIR was not created"
        failed=1
    fi

    # Verify apt-get update and install were called
    if ! grep -q "apt-get update" mock_sudo.log; then
        echo "FAIL: apt-get update was not called via sudo"
        failed=1
    fi

    # Check for some key packages to ensure the install command was correct
    if ! grep -q "apt-get install -y" mock_sudo.log || ! grep -q "git" mock_sudo.log || ! grep -q "build-essential" mock_sudo.log || ! grep -q "device-tree-compiler" mock_sudo.log; then
        echo "FAIL: apt-get install was not called correctly"
        cat mock_sudo.log
        failed=1
    fi

    # Cleanup after test
    rm -rf "${BUILD_DIR}" "${OUTPUT_DIR}" mock_sudo.log setup_env_only.sh

    if [[ $failed -eq 0 ]]; then
        echo "PASS: test_setup_environment"
        return 0
    else
        return 1
    fi
}

# Run the test
test_setup_environment
