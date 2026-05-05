#!/bin/bash

# Test Workspace Setup
WORKSPACE=$(mktemp -d)
MOCK_BIN="${WORKSPACE}/mock_bin"
mkdir -p "${MOCK_BIN}"
export PATH="${MOCK_BIN}:${PATH}"

# Logging Mocks
log_info() { echo "[INFO] $*" >&2; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
log_step() { echo "[STEP] $*" >&2; }

# Track test failures
FAILURES=0

assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="$3"
    if [[ "$expected" != "$actual" ]]; then
        echo "FAIL: $msg"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        ((FAILURES++))
    else
        echo "PASS: $msg"
    fi
}

assert_true() {
    local exit_code="$1"
    local msg="$2"
    if [[ "$exit_code" -ne 0 ]]; then
        echo "FAIL: $msg (exit code $exit_code)"
        ((FAILURES++))
    else
        echo "PASS: $msg"
    fi
}

assert_false() {
    local exit_code="$1"
    local msg="$2"
    if [[ "$exit_code" -eq 0 ]]; then
        echo "FAIL: $msg (exit code $exit_code)"
        ((FAILURES++))
    else
        echo "PASS: $msg"
    fi
}

# Create adb mock script
cat << 'EOF' > "${MOCK_BIN}/adb"
#!/bin/bash
CMD="$1"
shift

if [[ "$CMD" == "devices" ]]; then
    if [[ "$MOCK_ADB_CONNECTED" == "true" ]]; then
        echo "List of devices attached"
        echo "1234567890abcde device"
    else
        echo "List of devices attached"
    fi
elif [[ "$CMD" == "shell" ]]; then
    SUBCMD="$1"
    if [[ "$SUBCMD" == "getprop" ]]; then
        PROP="$2"
        if [[ "$PROP" == "ro.product.device" ]]; then
            echo "${MOCK_ADB_DEVICE:-unknown}"
        elif [[ "$PROP" == "ro.product.model" ]]; then
            echo "${MOCK_ADB_MODEL:-unknown}"
        fi
    fi
elif [[ "$CMD" == "push" ]]; then
    echo "adb push $*" > "${MOCK_ADB_PUSH_LOG:-/dev/null}"
fi
EOF
chmod +x "${MOCK_BIN}/adb"

# Source the target script
set +e
sed "s/^set -e/# set -e/" flash-helper.sh > "${WORKSPACE}/flash-helper-test.sh"
source "${WORKSPACE}/flash-helper-test.sh"


# Override read to support mocking
read() {
    local var_name
    local prompt_mode=false
    for arg in "$@"; do
        if [[ "$prompt_mode" == true ]]; then
            prompt_mode=false
            continue
        fi
        if [[ "$arg" == "-p" ]]; then
            prompt_mode=true
            continue
        fi
        var_name="$arg"
    done

    if [[ -n "$MOCK_READ_INPUT" ]]; then
        if [[ -n "$var_name" ]]; then
            printf -v "$var_name" "%s" "$MOCK_READ_INPUT"
        fi
        REPLY="$MOCK_READ_INPUT"
    else
        # default to empty
        if [[ -n "$var_name" ]]; then
            printf -v "$var_name" ""
        fi
        REPLY=""
    fi
}

run_tests() {
    echo "=== Testing check_device ==="

    # Test 1: No device connected
    echo "Test 1: No device connected"
    export MOCK_ADB_CONNECTED="false"
    check_device > /dev/null 2>&1
    assert_false "$?" "check_device should fail when no device is connected"

    # Test 2: Happy path
    echo "Test 2: Correct device connected"
    export MOCK_ADB_CONNECTED="true"
    export MOCK_ADB_DEVICE="gts8wifi"
    export MOCK_ADB_MODEL="SM-X700"
    check_device > /dev/null 2>&1
    assert_true "$?" "check_device should pass when gts8wifi is connected"

    # Test 3: Mismatched device, user confirms
    echo "Test 3: Mismatched device, user confirms"
    export MOCK_ADB_CONNECTED="true"
    export MOCK_ADB_DEVICE="pixel"
    export MOCK_ADB_MODEL="Pixel 6"
    export MOCK_READ_INPUT="y"
    check_device > /dev/null 2>&1
    assert_true "$?" "check_device should pass when user confirms mismatch"

    # Test 4: Mismatched device, user refuses
    echo "Test 4: Mismatched device, user refuses"
    export MOCK_ADB_CONNECTED="true"
    export MOCK_ADB_DEVICE="pixel"
    export MOCK_ADB_MODEL="Pixel 6"
    export MOCK_READ_INPUT="n"
    check_device > /dev/null 2>&1
    assert_false "$?" "check_device should fail when user refuses mismatch"

    echo "=== Testing flash_magisk ==="

    # Test 5: No AnyKernel zip found
    echo "Test 5: No AnyKernel zip found"
    # Ensure OUTPUT_DIR is clean/empty for this test
    export OUTPUT_DIR="${WORKSPACE}/output"
    mkdir -p "${OUTPUT_DIR}"
    flash_magisk > /dev/null 2>&1
    assert_false "$?" "flash_magisk should fail when no AnyKernel zip is found"

    # Test 6: AnyKernel zip found, verify adb push target
    echo "Test 6: AnyKernel zip found"
    export OUTPUT_DIR="${WORKSPACE}/output2"
    mkdir -p "${OUTPUT_DIR}"
    touch "${OUTPUT_DIR}/AnyKernel3-test.zip"
    export MOCK_ADB_PUSH_LOG="${WORKSPACE}/adb_push.log"
    rm -f "$MOCK_ADB_PUSH_LOG"
    flash_magisk > /dev/null 2>&1
    assert_true "$?" "flash_magisk should succeed when AnyKernel zip is found"

    if [[ -f "$MOCK_ADB_PUSH_LOG" ]]; then
        push_cmd=$(cat "$MOCK_ADB_PUSH_LOG")
        if [[ "$push_cmd" == *" /sdcard/Download/"* ]]; then
            assert_eq 1 1 "adb push targets /sdcard/Download/"
        else
            assert_eq "adb push targets /sdcard/Download/" "$push_cmd" "adb push target is incorrect"
        fi
    else
        assert_eq "file exists" "no file" "adb push log was not created"
    fi
}

run_tests

rm -rf "$WORKSPACE"

exit $FAILURES
