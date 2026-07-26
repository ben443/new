#!/bin/bash
TEST_DIR=$(mktemp -d)
echo "TEST_DIR: $TEST_DIR"
cat << 'MOCK' > "${TEST_DIR}/make"
#!/bin/bash
echo "MAKE_CALLED_WITH: $@" >> "${TEST_DIR}/make_calls.log"
MOCK
chmod +x "${TEST_DIR}/make"
export PATH="${TEST_DIR}:$PATH"

source ./build-nethunter.sh > /dev/null 2>&1

export KERNEL_DIR="${TEST_DIR}/kernel"
mkdir -p "$KERNEL_DIR"
export SCRIPT_DIR="${TEST_DIR}/script"

configure_gki_kernel > "$TEST_DIR/out" 2>&1
echo "Status: $?"
cat "$TEST_DIR/out"
echo "make calls:"
cat "${TEST_DIR}/make_calls.log" || true
rm -rf "$TEST_DIR"
