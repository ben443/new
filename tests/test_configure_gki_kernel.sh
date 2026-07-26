#!/bin/bash

# Test script for configure_gki_kernel in build-nethunter.sh
# Based on the memory guidance, we use custom bash scripts.



# Mock logging functions
log_step() { echo "STEP: $1"; }
log_info() { echo "INFO: $1"; }
log_error() { echo "ERROR: $1"; }
log_warn() { echo "WARN: $1"; }

# Setup test environment
setup() {
    TEST_DIR=$(mktemp -d)
    export KERNEL_DIR="${TEST_DIR}/kernel"
    export SCRIPT_DIR="${TEST_DIR}/script"
    export GKI_DEFCONFIG="gki_defconfig"

    mkdir -p "${KERNEL_DIR}"
    mkdir -p "${SCRIPT_DIR}"

    # Create mock make command
    export PATH="${TEST_DIR}/mock_bin:$PATH"
    mkdir -p "${TEST_DIR}/mock_bin"

    cat << 'MOCK' > "${TEST_DIR}/mock_bin/make"
#!/bin/bash
echo "MAKE_CALLED_WITH: $@" >> "$TEST_DIR/make_calls.log"
# Create a dummy .config when make is called
touch .config
MOCK
    chmod +x "${TEST_DIR}/mock_bin/make"

    # Create a mock nethunter-config.fragment
    cat << 'FRAG' > "${SCRIPT_DIR}/nethunter-config.fragment"
CONFIG_NETHUNTER=y
CONFIG_MAC80211=y
FRAG

    # Source the script to test
    source ./build-nethunter.sh > /dev/null 2>&1
}

teardown() {
    rm -rf "${TEST_DIR}"
}

test_configure_gki_kernel() {
    echo "Running test_configure_gki_kernel..."
    setup

    # Execute the function, outputting to a file to capture return code and output as per memory
    configure_gki_kernel > "${TEST_DIR}/output.log" 2>&1
    local status=$?

    if [ $status -ne 0 ]; then
        echo "FAIL: configure_gki_kernel returned non-zero status ($status)"
        cat "${TEST_DIR}/output.log"
        teardown
        exit 1
    fi

    # Check if make was called with correct defconfig
    if ! grep -q "MAKE_CALLED_WITH: gki_defconfig" "${TEST_DIR}/make_calls.log"; then
        echo "FAIL: make was not called with gki_defconfig"
        cat "${TEST_DIR}/make_calls.log"
        teardown
        exit 1
    fi

    # Check if .config exists and has fragment content
    if [ ! -f "${KERNEL_DIR}/.config" ]; then
        echo "FAIL: .config was not created in KERNEL_DIR"
        teardown
        exit 1
    fi

    if ! grep -q "CONFIG_NETHUNTER=y" "${KERNEL_DIR}/.config"; then
        echo "FAIL: fragment content not merged into .config"
        cat "${KERNEL_DIR}/.config"
        teardown
        exit 1
    fi

    # Check if EOF heredoc content was merged
    if ! grep -q "CONFIG_MODULE_SIG=y" "${KERNEL_DIR}/.config"; then
        echo "FAIL: NetHunter Extensions not appended to .config"
        cat "${KERNEL_DIR}/.config"
        teardown
        exit 1
    fi

    echo "PASS: test_configure_gki_kernel"
    teardown
}

test_configure_gki_kernel_no_fragment() {
    echo "Running test_configure_gki_kernel_no_fragment..."
    setup

    # Remove fragment
    rm "${SCRIPT_DIR}/nethunter-config.fragment"

    # Execute the function
    configure_gki_kernel > "${TEST_DIR}/output.log" 2>&1
    local status=$?

    if [ $status -ne 0 ]; then
        echo "FAIL: configure_gki_kernel returned non-zero status ($status)"
        cat "${TEST_DIR}/output.log"
        teardown
        exit 1
    fi

    # Should not contain fragment content, but should contain the appended block
    if grep -q "CONFIG_NETHUNTER=y" "${KERNEL_DIR}/.config" 2>/dev/null; then
        echo "FAIL: fragment content unexpectedly found"
        teardown
        exit 1
    fi

    if ! grep -q "CONFIG_MODULE_SIG=y" "${KERNEL_DIR}/.config"; then
        echo "FAIL: NetHunter Extensions not appended to .config"
        cat "${KERNEL_DIR}/.config"
        teardown
        exit 1
    fi

    echo "PASS: test_configure_gki_kernel_no_fragment"
    teardown
}

# Run tests
test_configure_gki_kernel
test_configure_gki_kernel_no_fragment

echo "All tests passed!"
