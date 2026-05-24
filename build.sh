#!/bin/bash
# Android GKI Kernel 5.10 Build Script for Samsung Galaxy Tab S8
# VERIFIED FOR GITHUB ACTIONS CI

set -euo pipefail

# ==========================================
# CONFIGURATION
# ==========================================
DEFCONFIG="vendor/taro_defconfig" 

KERNEL_DIR="$(pwd)"
OUT_DIR="${KERNEL_DIR}/out"
TOOLCHAIN_DIR="${KERNEL_DIR}/toolchain"
CLANG_DIR="${TOOLCHAIN_DIR}/clang"
ZIP_DIR="${KERNEL_DIR}/anykernel_zip"

# Use all CPU cores available on the GitHub runner
THREADS=$(nproc)

# ==========================================
# TOOLCHAIN SETUP (AOSP Clang 14)
# ==========================================
echo "--- Checking Toolchain ---"
if [ ! -d "${CLANG_DIR}" ]; then
    echo "Downloading AOSP Clang Toolchain..."
    mkdir -p "${CLANG_DIR}"
    git clone --depth=1 --single-branch https://gitlab.com "${CLANG_DIR}"
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

KBUILD_COMPILER_STRING=$("${CLANG_DIR}/bin/clang" --version | head -n 1 | sed -E 's/\(http[^)]+\)//g; s/[[:space:]]+/ /g; s/[[:space:]]+$//')
export KBUILD_COMPILER_STRING
echo "Using Compiler: ${KBUILD_COMPILER_STRING}"

# ==========================================
# BUILD PROCESS
# ==========================================
echo "--- Starting Kernel Build ---"

if [ -d "${OUT_DIR}" ]; then rm -rf "${OUT_DIR}"; fi
mkdir -p "${OUT_DIR}"

# 1. Generate Configuration
echo "Generating defconfig: ${DEFCONFIG}..."
make O="${OUT_DIR}" ARCH="${ARCH}" "${DEFCONFIG}"

# 2. Fix Build-Breaking Configurations (CRITICAL)
echo "Applying config fixes (Disabling BTF & Trusted Keys)..."
"${KERNEL_DIR}/scripts/config" --file "${OUT_DIR}/.config" \
    --set-str SYSTEM_TRUSTED_KEYS "" \
    --set-str SYSTEM_REVOCATION_KEYS "" \
    --disable DEBUG_INFO_BTF

# Regenerate config cleanly
make O="${OUT_DIR}" ARCH="${ARCH}" olddefconfig

# 3. Compile Kernel Image & Modules
echo "Compiling Kernel and Modules using ${THREADS} threads..."
make O="${OUT_DIR}" ARCH="${ARCH}" \
     CC="${CC}" \
     CROSS_COMPILE="${CROSS_COMPILE}" \
     CROSS_COMPILE_COMPAT="${CROSS_COMPILE_COMPAT}" \
     LLVM="${LLVM}" \
     LLVM_IAS="${LLVM_IAS}" \
     -j"${THREADS}"

# ==========================================
# ANYKERNEL3 ZIP CREATION
# ==========================================
if [ -f "${OUT_DIR}/arch/arm64/boot/Image" ]; then
    echo "=========================================="
    echo "✅ BUILD SUCCESSFUL! Packaging AnyKernel3..."
    echo "=========================================="
    
    # 1. Clone fresh AnyKernel3 template
    if [ -d "${ZIP_DIR}" ]; then rm -rf "${ZIP_DIR}"; fi
    git clone --depth=1 https://github.com/osm0sis/AnyKernel3.git "${ZIP_DIR}"
    
    # 2. Copy the compiled Kernel Image into the ZIP folder
    cp "${OUT_DIR}/arch/arm64/boot/Image" "${ZIP_DIR}/"
    
    # 3. Find and copy all built Kernel Modules (.ko files)
    echo "Searching for compiled kernel modules..."
    mkdir -p "${ZIP_DIR}/modules"
    find "${OUT_DIR}" -name "*.ko" -exec cp {} "${ZIP_DIR}/modules/" \;
    
    # Clean up empty modules folder if none were built
    if [ -z "$(ls -A "${ZIP_DIR}/modules")" ]; then
        rmdir "${ZIP_DIR}/modules"
        echo "No modules found. Skipping modules folder."
    else
        echo "Modules packed successfully."
    fi

    # 4. Modify target device details inside anykernel.sh
    # Galaxy Tab S8 runs on the Snapdragon 8 Gen 1 (taro / SM8450) platform
    sed -i 's/device.name1=maguro/device.name1=taro/g' "${ZIP_DIR}/anykernel.sh"
    sed -i 's/device.name2=toro/device.name2=gts8/g' "${ZIP_DIR}/anykernel.sh"
    
    # 5. Create the flashable zip archive
    cd "${ZIP_DIR}"
    zip -r9 "${KERNEL_DIR}/TabS8_Kernel_GKI.zip" ./*
    cd "${KERNEL_DIR}"
    
    echo "🎉 Success! Flashable zip created: TabS8_Kernel_GKI.zip"
else
    echo "❌ BUILD FAILED! Kernel Image not found."
    exit 1
fi
