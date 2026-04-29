#!/bin/bash
set -e

# Create a mock environment for testing find performance
TEST_DIR=$(mktemp -d)
mkdir -p "$TEST_DIR/modules"
# Create 500 dummy kernel modules
for i in {1..500}; do
  touch "$TEST_DIR/modules/module_${i}.ko"
done

echo "Running benchmark with \;"
time find "$TEST_DIR/modules" -name "*.ko" -exec basename {} \; > /dev/null

echo "Running benchmark with +"
# Note we need to handle basename diff.
# For multiple args, basename doesn't work out of the box like that unless using `-a`
# Actually `basename -a` works, or `cp -t`
time find "$TEST_DIR/modules" -name "*.ko" -exec basename -a {} + > /dev/null

rm -rf "$TEST_DIR"
