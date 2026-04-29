#!/bin/bash

# Test for configure_vendor_modules function

# Source the main script to get the function
source ./build-nethunter.sh

# Mock dependencies
log_step() { :; }
log_info() { :; }
log_error() { :; }

# Track overall test status
TESTS_FAILED=0

run_test() {
    local test_func=$1
    if $test_func; then
        echo "PASS: $test_func"
    else
        echo "FAIL: $test_func"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_configure_vendor_modules_success() {
    # Create temporary directories for test
    local test_dir=$(mktemp -d)
    export KERNEL_DIR="${test_dir}/kernel"
    export OUTPUT_DIR="${test_dir}/output"
    export VENDOR_DEFCONFIG="test_defconfig"

    mkdir -p "${KERNEL_DIR}/arch/arm64/configs"
    mkdir -p "${KERNEL_DIR}/scripts/kconfig"
    mkdir -p "${OUTPUT_DIR}"

    # Setup dummy GKI .config
    cd "${KERNEL_DIR}"
    echo "CONFIG_GKI=y" > .config
    echo "CONFIG_GKI_TEST=y" >> .config

    # Setup dummy vendor defconfig
    echo "CONFIG_VENDOR=y" > "arch/arm64/configs/${VENDOR_DEFCONFIG}"

    # Create mock scripts
    cat << 'MOCK' > scripts/kconfig/merge_config.sh
#!/bin/bash
# Mock merge_config.sh
echo "merge_config.sh called with: $@" > "${OUTPUT_DIR}/merge_args.txt"
cat "$3" >> "$2"
MOCK
    chmod +x scripts/kconfig/merge_config.sh

    # Mock make
    make() {
        echo "make called with: $@" > "${OUTPUT_DIR}/make_args.txt"
    }
    export -f make

    local failed=0

    # Run the function
    # Go to a safe directory first, the function will cd into KERNEL_DIR
    cd "${test_dir}"
    configure_vendor_modules > "${OUTPUT_DIR}/output.log" 2>&1

    # 1. Verify GKI config was saved
    if [ ! -f "${OUTPUT_DIR}/.config.gki" ]; then
        echo "  - GKI config was not saved to ${OUTPUT_DIR}/.config.gki"
        failed=1
    fi

    # 2. Verify merge_config.sh was called with correct arguments
    if [ ! -f "${OUTPUT_DIR}/merge_args.txt" ]; then
        echo "  - merge_config.sh was not called"
        failed=1
    else
        local merge_args=$(cat "${OUTPUT_DIR}/merge_args.txt")
        if [[ ! "$merge_args" == *"merge_config.sh called with: -m ${OUTPUT_DIR}/.config.gki arch/arm64/configs/${VENDOR_DEFCONFIG}"* ]]; then
            echo "  - merge_config.sh called with wrong arguments: $merge_args"
            failed=1
        fi
    fi

    # 3. Verify NetHunter drivers were appended to .config
    cd "${KERNEL_DIR}"
    if ! grep -q "CONFIG_RTL8812AU=m" .config; then
        echo "  - NetHunter drivers not found in .config"
        failed=1
    fi

    if ! grep -q "CONFIG_USB_NET_RNDIS_HOST=m" .config; then
        echo "  - USB WiFi drivers not found in .config"
        failed=1
    fi

    if ! grep -q "CONFIG_TUN=m" .config; then
        echo "  - Additional NetHunter modules not found in .config"
        failed=1
    fi

    # 4. Verify make olddefconfig was called
    if [ ! -f "${OUTPUT_DIR}/make_args.txt" ]; then
        echo "  - make was not called"
        failed=1
    else
        local make_args=$(cat "${OUTPUT_DIR}/make_args.txt")
        if [[ ! "$make_args" == *"make called with: olddefconfig"* ]]; then
            echo "  - make olddefconfig was not called: $make_args"
            failed=1
        fi
    fi

    # Cleanup after test
    rm -rf "${test_dir}"

    return $failed
}

test_configure_vendor_modules_no_defconfig() {
    # Create temporary directories for test
    local test_dir=$(mktemp -d)
    export KERNEL_DIR="${test_dir}/kernel"
    export OUTPUT_DIR="${test_dir}/output"
    export VENDOR_DEFCONFIG="non_existent_defconfig"

    mkdir -p "${KERNEL_DIR}/arch/arm64/configs"
    mkdir -p "${KERNEL_DIR}/scripts/kconfig"
    mkdir -p "${OUTPUT_DIR}"

    # Setup dummy GKI .config
    cd "${KERNEL_DIR}"
    echo "CONFIG_GKI=y" > .config

    # Mock make
    make() {
        echo "make called with: $@" > "${OUTPUT_DIR}/make_args.txt"
    }
    export -f make

    local failed=0

    # Run the function
    cd "${test_dir}"
    configure_vendor_modules > "${OUTPUT_DIR}/output.log" 2>&1

    # 1. Verify merge_config.sh was NOT called because defconfig doesn't exist
    if [ -f "${OUTPUT_DIR}/merge_args.txt" ]; then
        echo "  - merge_config.sh was called when defconfig doesn't exist"
        failed=1
    fi

    # 2. Verify NetHunter drivers were still appended
    cd "${KERNEL_DIR}"
    if ! grep -q "CONFIG_RTL8812AU=m" .config; then
        echo "  - NetHunter drivers not found in .config when defconfig is missing"
        failed=1
    fi

    # Cleanup after test
    rm -rf "${test_dir}"

    return $failed
}

# Run the tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Running tests for configure_vendor_modules..."
    run_test test_configure_vendor_modules_success
    run_test test_configure_vendor_modules_no_defconfig

    # Return with number of failed tests
    if [ $TESTS_FAILED -eq 0 ]; then
        echo "All tests passed successfully."
        exit 0
    else
        echo "$TESTS_FAILED test(s) failed."
        exit 1
    fi
fi
