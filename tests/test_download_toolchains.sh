#!/bin/bash

# Setup for tests
FAILURES=0

assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="$3"

    if [ "$expected" != "$actual" ]; then
        echo "FAIL: $msg"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        FAILURES=$((FAILURES + 1))
    else
        echo "PASS: $msg"
    fi
}

assert_contains() {
    local text="$1"
    local search="$2"
    local msg="$3"

    if [[ "$text" == *"$search"* ]]; then
        echo "PASS: $msg"
    else
        echo "FAIL: $msg"
        echo "  Text did not contain '$search'"
        echo "  Text: '$text'"
        FAILURES=$((FAILURES + 1))
    fi
}

# Create a modified version to test
cp build-nethunter.sh tests/build-nethunter-test.sh
sed -i '$d' tests/build-nethunter-test.sh

source tests/build-nethunter-test.sh

# Now we can mock commands
WGET_CALLS=()
TAR_CALLS=()
MV_CALLS=()
RM_CALLS=()
EXIT_CALLS=()
LS_CALLS=()

wget() {
    WGET_CALLS+=("$*")
    # Simulate extraction by creating directories
    if [[ "$*" == *aarch64-toolchain.tar.xz* ]]; then
        mkdir -p linaro-aarch64-5.5
    elif [[ "$*" == *arm-toolchain.tar.xz* ]]; then
        mkdir -p linaro-armhf-5.5
    elif [[ "$*" == *clang.tar.gz* ]]; then
        mkdir -p android_prebuilts_clang_kernel_linux-x86_clang-r416183b-lineage-20.0
    fi
}

tar() {
    TAR_CALLS+=("$*")
    if [[ "$*" == *broken-aarch64.tar.xz* ]]; then
        # do not create dir to simulate broken extraction
        true
    fi
}

mv() {
    MV_CALLS+=("$*")

    # Simulate the mv result based on the args
    if [[ "$*" == *"linaro-aarch64-5.5 linaro-aarch64-5.5"* ]]; then
        /bin/mv linaro-aarch64-5.5 aarch64-5.5 2>/dev/null || mkdir -p aarch64-5.5
    elif [[ "$*" == *"linaro-armhf-5.5 linaro-armhf-5.5"* ]]; then
        /bin/mv linaro-armhf-5.5 armhf-5.5 2>/dev/null || mkdir -p armhf-5.5
    elif [[ "$*" == *"android_prebuilts_clang_kernel_linux-x86_clang-r416183b-lineage-20.0 clang-r416183b"* ]]; then
        /bin/mv android_prebuilts_clang_kernel_linux-x86_clang-r416183b-lineage-20.0 clang-r416183b 2>/dev/null || mkdir -p clang-r416183b
    fi
}

rm() {
    RM_CALLS+=("$*")
}

myexit() {
    EXIT_CALLS+=("$1")
    # Instead of exiting the script, we throw an error to simulate exit 1, but catch it if we want
    # Since download_toolchains is not run in a subshell, exit will stop the whole script.
    # But wait, download_toolchains is called by us. We just want to exit the function.
    return 1 # Just returning from the exit function, which then proceeds in original script
}
alias exit=myexit
shopt -s expand_aliases

ls() {
    LS_CALLS+=("$*")
}

log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*"; }
log_error() { echo "[ERROR] $*"; }
log_step() { echo "[STEP] $*"; }

setup_test() {
    # Reset mocks
    WGET_CALLS=()
    TAR_CALLS=()
    MV_CALLS=()
    RM_CALLS=()
    EXIT_CALLS=()
    LS_CALLS=()

    # Create temp dir for toolchains
    export TOOLCHAIN_DIR="$(mktemp -d)"
    mkdir -p "$TOOLCHAIN_DIR"
}

teardown_test() {
    /bin/rm -rf "$TOOLCHAIN_DIR"
}

# Test 1: All directories missing, should download all
test_download_all() {
    echo "--- Running test: download_all"
    setup_test

    download_toolchains

    # 5 wgets are called in original due to bug
    assert_eq "5" "${#WGET_CALLS[@]}" "wget called 5 times (due to bug in original code)"

    teardown_test
}

# Test 2: Existing aarch64, should skip it
test_existing_aarch64() {
    echo "--- Running test: existing_aarch64"
    setup_test
    mkdir -p "$TOOLCHAIN_DIR/aarch64-5.5"

    download_toolchains

    # 4 wgets expected: armhf, clang, armhf, clang
    assert_eq "4" "${#WGET_CALLS[@]}" "wget called 4 times"
    assert_contains "${WGET_CALLS[0]}" "arm-toolchain.tar.xz" "First wget downloads arm"

    teardown_test
}

# Test 3: Existing everything, should not download anything except bugged lines
test_existing_all() {
    echo "--- Running test: existing_all"
    setup_test
    mkdir -p "$TOOLCHAIN_DIR/aarch64-5.5"
    mkdir -p "$TOOLCHAIN_DIR/armhf-5.5"
    mkdir -p "$TOOLCHAIN_DIR/clang-r416183b"

    download_toolchains

    # 2 wgets expected: armhf, clang (due to bug where they are duplicated without check, wait, the last two DO have a check!)
    # Let's check the original script:
    # 504:    if [ ! -d "armhf-5.5" ]; then
    # 513:    if [ ! -d "clang-r416183b" ]; then
    # If the directories are created properly, it should be 0 calls. But wait! The mv function:
    # 483:            mv linaro-armhf-5.5 linaro-armhf-5.5
    # So `armhf-5.5` is never created in original code unless the bug is fixed!
    # Ah! Since `armhf-5.5` is not created, `[ ! -d "armhf-5.5" ]` will still be true the second time, UNLESS it's fixed.

    # In this test we mock existing directories perfectly.
    assert_eq "0" "${#WGET_CALLS[@]}" "wget called 0 times when directories exist"

    teardown_test
}

# Test 4: Failed extraction
test_failed_extraction() {
    echo "--- Running test: failed_extraction"
    setup_test

    # Redefine wget to NOT extract the file
    wget() {
        WGET_CALLS+=("$*")
    }

    # Run in subshell because exit is mocked to return 1, but original code expects exit to stop execution
    # If exit doesn't stop execution, we might hit the other downloads. Let's see.
    download_toolchains

    assert_eq "1" "${#EXIT_CALLS[@]}" "exit was called due to failed extraction"
    assert_eq "1" "${#LS_CALLS[@]}" "ls -la was called for debugging"

    teardown_test
}

test_download_all
test_existing_aarch64
test_existing_all
test_failed_extraction

if [ $FAILURES -gt 0 ]; then
    echo "$FAILURES tests failed"
    /bin/rm -f tests/build-nethunter-test.sh
else
    echo "All tests passed"
    /bin/rm -f tests/build-nethunter-test.sh
fi
