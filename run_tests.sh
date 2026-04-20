#!/bin/bash

# Simple test runner

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "======================================"
echo "Running Tests"
echo "======================================"

FAILURES=0
TOTAL=0

# Find all test scripts
TEST_SCRIPTS=$(find tests -name "test_*.sh")

for script in $TEST_SCRIPTS; do
    echo -n "Running $script... "
    TOTAL=$((TOTAL+1))

    # Run the script and capture output
    OUTPUT=$(./"$script" 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        echo "Output:"
        echo "$OUTPUT"
        FAILURES=$((FAILURES+1))
    fi
done

echo "======================================"
if [ $FAILURES -eq 0 ]; then
    echo -e "Summary: ${GREEN}All $TOTAL tests passed!${NC}"
    exit 0
else
    echo -e "Summary: ${RED}$FAILURES/$TOTAL tests failed.${NC}"
    exit 1
fi
