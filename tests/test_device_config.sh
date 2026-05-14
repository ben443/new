#!/bin/bash

# Source the target script
source ./device-config.sh > /dev/null
set +e

FAILURES=0

# Test 1: Verify key variables are exported
if [[ "$DEVICE_CODENAME" != "gts8wifi" ]]; then
    echo "Test 1 Failed: Expected DEVICE_CODENAME='gts8wifi', got '$DEVICE_CODENAME'"
    ((FAILURES++))
else
    echo "Test 1 Passed: DEVICE_CODENAME is correct"
fi

if [[ "$DEVICE_MODEL" != "SM-X700" ]]; then
    echo "Test 1 Failed: Expected DEVICE_MODEL='SM-X700', got '$DEVICE_MODEL'"
    ((FAILURES++))
else
    echo "Test 1 Passed: DEVICE_MODEL is correct"
fi

if [[ "$HAS_SPEN" != "true" ]]; then
    echo "Test 1 Failed: Expected HAS_SPEN='true', got '$HAS_SPEN'"
    ((FAILURES++))
else
    echo "Test 1 Passed: HAS_SPEN is correct"
fi

# Test 2: Verify DEFCONFIG_MODIFICATIONS array has elements
if [[ ${#DEFCONFIG_MODIFICATIONS[@]} -eq 0 ]]; then
    echo "Test 2 Failed: Expected DEFCONFIG_MODIFICATIONS array to not be empty"
    ((FAILURES++))
else
    echo "Test 2 Passed: DEFCONFIG_MODIFICATIONS array is populated"
fi

# Test 3: Verify print_device_config successfully runs and outputs correctly
OUTPUT=$(print_device_config)
if [[ $? -ne 0 ]]; then
    echo "Test 3 Failed: print_device_config returned non-zero exit code"
    ((FAILURES++))
elif [[ ! "$OUTPUT" =~ "Device Codename:     gts8wifi" ]]; then
    echo "Test 3 Failed: print_device_config output missing expected string"
    echo "Got: $OUTPUT"
    ((FAILURES++))
else
    echo "Test 3 Passed: print_device_config works correctly"
fi

# Test 4: Verify duplicate kernel configuration entries absence
DUPLICATES=$(grep '"CONFIG_' device-config.sh | sort | uniq -d)
if [[ -n "$DUPLICATES" ]]; then
    echo "Test 4 Failed: Found duplicate kernel configuration entries:"
    echo "$DUPLICATES"
    ((FAILURES++))
else
    echo "Test 4 Passed: No duplicate kernel configuration entries found"
fi

exit $FAILURES
