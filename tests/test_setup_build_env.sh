#!/bin/bash

# Source the file we want to test
source ./build-nethunter.sh

test_setup_build_env() {
    # Set mock toolchain dir
    export TOOLCHAIN_DIR="/tmp/mock/toolchains"
    export BUILD_DIR="/tmp/mock/build"

    # Run function instead of capturing in subshell,
    # so the variables get exported in the current shell context
    setup_build_env > /dev/null

    # Assert variables are exported correctly
    assertEquals "ARCH" "arm64" "$ARCH"
    assertEquals "SUBARCH" "arm64" "$SUBARCH"
    assertEquals "CROSS_COMPILE" "/tmp/mock/toolchains/aarch64-5.5/bin/aarch64-linux-gnu-" "$CROSS_COMPILE"
    assertEquals "CROSS_COMPILE_ARM32" "/tmp/mock/toolchains/armhf-5.5/bin/arm-linux-gnueabihf-" "$CROSS_COMPILE_ARM32"
    assertEquals "CC" "/tmp/mock/toolchains/clang-r416183b/bin/clang" "$CC"
    assertEquals "CLANG_TRIPLE" "aarch64-linux-gnu-" "$CLANG_TRIPLE"
    assertEquals "AR" "/tmp/mock/toolchains/clang-r416183b/bin/llvm-ar" "$AR"
    assertEquals "NM" "/tmp/mock/toolchains/clang-r416183b/bin/llvm-nm" "$NM"
    assertEquals "OBJCOPY" "/tmp/mock/toolchains/aarch64-5.5/bin/aarch64-linux-gnu-objcopy" "$OBJCOPY"
    assertEquals "OBJDUMP" "/tmp/mock/toolchains/aarch64-5.5/bin/aarch64-linux-gnu-objdump" "$OBJDUMP"
    assertEquals "STRIP" "/tmp/mock/toolchains/aarch64-5.5/bin/aarch64-linux-gnu-strip" "$STRIP"
    assertEquals "LD" "/tmp/mock/toolchains/clang-r416183b/bin/ld.lld" "$LD"

    assertEquals "CCACHE_COMPRESS" "1" "$CCACHE_COMPRESS"
    assertEquals "CCACHE_DIR" "/tmp/mock/build/.ccache" "$CCACHE_DIR"

    assertTrue "Cache dir created" "[ -d /tmp/mock/build/.ccache ]"
}

# Source shunit2 at the end
source shunit2
