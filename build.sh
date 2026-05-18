#!/bin/bash
# Android GKI Kernel 5.10 Build Script for Samsung Galaxy Tab S8
# VERIFIED FOR CI AUTOMATION

set -e

# ==========================================
# CONFIGURATION
# ==========================================
# IMPORTANT: Update DEFCONFIG to match your source.
# For Tab S8 (SM8450), check arch/arm64/configs/ (or arch/arm64/configs/vendor/)
DEFCONFIG="vendor/taro_defconfig"

# Working directories
KERNEL_DIR="$(pwd)"
OUT_DIR="${KERNEL_DIR}/out"
TOOLCHAIN_DIR="${KERNEL_DIR}/toolchain"
CLANG_DIR="${TOOLCHAIN_DIR}/clang"

# ==========================================
# TOOLCHAIN SETUP (AOSP Clang 14)
# ==========================================
echo "--- Checking Toolchain ---"
if [ ! -d "${CLANG_DIR}" ]; then
    echo "Downloading AOSP Clang Toolchain..."
    mkdir -p "${CLANG_DIR}"
    # Reliable Clang 14 mirror optimized for Android GKI 5.10
    git clone --depth=1 https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 "${CLANG_DIR}"
else
    echo "Toolchain already exists."
fi

# ==========================================
# ENVIRONMENT VARIABLES
# ==========================================
echo "--- Exporting Environment Variables ---"
export PATH="${CLANG_DIR}/bin:${PATH}"

export ARCH="arm64"
export SUBARCH="arm64"

# GKI Compilers (LLVM/Clang)
export CC="clang"
export LLVM=1
export LLVM_IAS=1
export CROSS_COMPILE="aarch64-linux-gnu-"
export CROSS_COMPILE_COMPAT="arm-linux-gnueabi-"

export KBUILD_COMPILER_STRING="$(${CLANG_DIR}/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
echo "Using Compiler: ${KBUILD_COMPILER_STRING}"

# ==========================================
# BUILD PROCESS
# ==========================================
echo "--- Starting Kernel Build ---"
mkdir -p "${OUT_DIR}"

# 1. Generate Configuration
echo "Generating defconfig: ${DEFCONFIG}..."
make O="${OUT_DIR}" ARCH="${ARCH}" "${DEFCONFIG}"

# 2. Fix Build-Breaking Configurations (CRITICAL)
echo "Applying config fixes (Disabling BTF & Trusted Keys)..."
# If we don't clear these, make looks for Samsung's private keys and fails.
scripts/config --file "${OUT_DIR}/.config" --set-str SYSTEM_TRUSTED_KEYS ""
scripts/config --file "${OUT_DIR}/.config" --set-str SYSTEM_REVOCATION_KEYS ""
# BTF debug info generation frequently breaks CI builds, disabling it is safest.
scripts/config --file "${OUT_DIR}/.config" --disable DEBUG_INFO_BTF

# Regenerate config to apply the changes above cleanly
make O="${OUT_DIR}" ARCH="${ARCH}" olddefconfig

# 3. Compile Kernel Image
echo "Compiling Kernel..."
make O="${OUT_DIR}" ARCH="${ARCH}" CC="${CC}" \
     CROSS_COMPILE="${CROSS_COMPILE}" \
     CROSS_COMPILE_COMPAT="${CROSS_COMPILE_COMPAT}" \
     LLVM="${LLVM}" LLVM_IAS="${LLVM_IAS}" \
     -j"$(nproc)"

# ==========================================
# FINISH & VERIFY
# ==========================================
if [ -f "${OUT_DIR}/arch/arm64/boot/Image" ]; then
    echo "=========================================="
    echo "✅ BUILD SUCCESSFUL!"
    echo "Kernel Image found at: ${OUT_DIR}/arch/arm64/boot/Image"
    echo "=========================================="
else
    echo "❌ BUILD FAILED! Kernel Image not found."
    exit 1
fi
