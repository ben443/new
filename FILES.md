# File Structure and Description

This document describes all files in the NetHunter kernel build environment for Samsung Galaxy Tab S8 (gts8wifi/SM-X700).

## 📁 Root Directory Files

### Build Scripts

| File | Description | Usage |
|------|-------------|-------|
| `build-nethunter.sh` | Main build script - handles complete kernel build process | `./build-nethunter.sh full` or `./build-nethunter.sh` for interactive menu |
| `flash-helper.sh` | Helper script for flashing and managing kernel | `./flash-helper.sh` for interactive menu |
| `device-config.sh` | Device-specific configuration variables | Sourced by build scripts |

### Configuration Files

| File | Description | Purpose |
|------|-------------|---------|
| `nethunter-config.fragment` | NetHunter kernel configuration options | Merged with kernel defconfig during build |
| `Dockerfile` | Docker build environment definition | Creates consistent build container |
| `docker-compose.yml` | Docker Compose configuration | Simplifies Docker build process |

### Documentation

| File | Description | Audience |
|------|-------------|----------|
| `README.md` | Comprehensive documentation | All users |
| `QUICKSTART.md` | Quick start guide | New users |
| `GKI-GUIDE.md` | GKI-specific documentation | GKI users |
| `FILES.md` | This file - file structure documentation | Developers |
| `LICENSE` | GPL v2 License | Legal |

## 📂 Directory Structure

```
nethunter-gts8wifi/
├── build-nethunter.sh          # Main build script (GKI-aware)
├── flash-helper.sh             # Flash helper script
├── device-config.sh            # Device configuration (GKI settings)
├── nethunter-config.fragment   # NetHunter kernel config
├── Dockerfile                  # Docker build file
├── docker-compose.yml          # Docker compose config
├── README.md                   # Main documentation
├── QUICKSTART.md               # Quick start guide
├── GKI-GUIDE.md                # GKI-specific documentation
├── FILES.md                    # This file
├── LICENSE                     # GPL v2 License
├── PROJECT_SUMMARY.txt         # Summary document
├── .gitignore                  # Git ignore file
├── build/                      # Build directory (created during build)
│   ├── kernel/                 # Kernel source code
│   ├── toolchains/             # Cross-compilation toolchains
│   ├── kali-nethunter-kernel/  # NetHunter kernel builder
│   ├── AnyKernel3/             # AnyKernel3 for packaging
│   └── .ccache/                # ccache directory
├── output/                     # Build output (created during build)
│   ├── kernel/                 # Compiled kernel images
│   ├── gki/                    # GKI kernel output (GKI builds)
│   ├── vendor/                 # Vendor modules (GKI builds)
│   ├── modules/                # Kernel modules
│   ├── build.log               # Build log
│   ├── build-gki.log           # GKI build log
│   ├── vendor-modules.list     # Vendor module list
│   └── *.zip                   # Flashable AnyKernel zips
└── backups/                    # Kernel backups (created by flash-helper)
```

## 🔧 Script Details

### build-nethunter.sh

**Purpose**: Main build script for NetHunter kernel with GKI support

**Functions**:
- Environment setup
- Toolchain download and configuration
- Kernel source download
- NetHunter patches application
- **GKI kernel configuration** (detects and configures GKI)
- **GKI kernel compilation** (builds generic + vendor modules)
- **GKI-aware packaging** (handles GKI output structure)

**GKI-Specific Functions**:
- `check_gki_support()` - Detects GKI support in kernel source
- `configure_gki_kernel()` - Configures GKI base kernel
- `configure_vendor_modules()` - Configures vendor-specific modules
- `build_gki_kernel()` - Builds generic GKI kernel
- `build_vendor_modules()` - Builds vendor loadable modules
- `package_gki_kernel()` - Packages GKI kernel + modules
- `create_gki_anykernel_zip()` - Creates GKI-compatible flashable zip

**Usage**:
```bash
./build-nethunter.sh [command]

Commands:
  full        - Full build (setup + download + configure + build + package)
  setup       - Setup environment only
  toolchains  - Download toolchains only
  source      - Download kernel source only
  configure   - Configure kernel only (GKI-aware)
  build       - Build kernel only (GKI-aware)
  package     - Package kernel only (GKI-aware)
  clean       - Clean build directory
```

**Key Features**:
- **GKI detection and automatic configuration**
- Automatic dependency installation
- ccache support for faster rebuilds
- Parallel compilation
- Interactive menuconfig option
- Automatic AnyKernel3 packaging (GKI-compatible)

### flash-helper.sh

**Purpose**: Helper script for flashing and managing kernel

**Functions**:
- Device connection verification
- Root access verification
- Kernel backup and restore
- Multiple flash methods (Fastboot, TWRP, Magisk)
- Temporary kernel testing
- WiFi driver installation
- NetHunter chroot setup

**Usage**:
```bash
./flash-helper.sh

Interactive menu options:
  1. Full Flash (Backup + Flash via Fastboot)
  2. Backup Current Kernel
  3. Flash via Fastboot
  4. Flash via TWRP (AnyKernel zip)
  5. Flash via Magisk (AnyKernel zip)
  6. Test Kernel (Temporary Boot)
  7. Restore Kernel Backup
  8. Check Kernel Status
  9. Install WiFi Drivers
  10. Setup NetHunter Chroot
  11. Exit
```

### device-config.sh

**Purpose**: Device-specific configuration variables

**Contents**:
- Device information (codename, model, chipset)
- Android version configuration
- Kernel configuration
- Partition information
- Feature flags
- Build configuration

**Usage**:
```bash
source device-config.sh
```

## ⚙️ Configuration Files

### nethunter-config.fragment

**Purpose**: NetHunter-specific kernel configuration options

**Sections**:
- USB Gadget Support
- USB HID Support
- USB Serial/ACM Support
- USB Network Support
- USB Storage Support
- Wireless LAN Support
- Bluetooth Support
- Network Support
- Filesystem Support
- Module Support
- Debug Support

**Usage**: Automatically merged with kernel defconfig during build

### Dockerfile

**Purpose**: Defines Docker build environment

**Base Image**: Ubuntu 22.04

**Installed Packages**:
- Build essentials (gcc, make, etc.)
- Cross-compilation tools
- Kernel build dependencies
- Utility tools (vim, git, wget, etc.)

**Usage**:
```bash
docker build -t nethunter-gts8wifi-builder .
docker run -v $(pwd)/output:/build/output nethunter-gts8wifi-builder
```

### docker-compose.yml

**Purpose**: Simplifies Docker build process

**Services**:
- builder: Main build container

**Volumes**:
- ./output:/build/output
- nethunter-ccache:/build/.ccache

**Usage**:
```bash
docker-compose up --build
```

## 📖 Documentation Files

### README.md

**Contents**:
- Project overview
- Prerequisites
- Device specifications
- Features list
- Build instructions (native and Docker)
- Installation guide
- WiFi adapter compatibility
- Troubleshooting
- Credits and license

**Target Audience**: All users

### QUICKSTART.md

**Contents**:
- Quick build instructions
- Docker build method
- Post-installation steps
- Common commands
- Basic troubleshooting

**Target Audience**: New users who want to get started quickly

### FILES.md

**Contents**:
- File structure description
- Script details
- Configuration file descriptions
- Usage examples

**Target Audience**: Developers and advanced users

### LICENSE

**Contents**: GNU General Public License v2

**Applies to**: All original code in this repository

## 📂 Generated Directories

### build/

Created during build process. Contains:
- `kernel/`: Cloned kernel source code
- `toolchains/`: Downloaded cross-compilers
- `kali-nethunter-kernel/`: NetHunter patches and tools
- `AnyKernel3/`: AnyKernel3 packaging tool
- `.ccache/`: Compiler cache for faster rebuilds

### output/

Created during build process. Contains:
- `kernel/`: Compiled kernel images (Image.gz, dtb files)
- `modules/`: Compiled kernel modules (.ko files)
- `build.log`: Complete build log
- `*.zip`: Flashable AnyKernel3 packages

### backups/

Created by flash-helper.sh. Contains:
- `boot_backup_*.img`: Kernel backup images
- `latest_backup.txt`: Pointer to latest backup

## 🔗 External Resources

The build scripts download the following external resources:

### Kernel Source
- **URL**: https://github.com/akm-04/Samsung_Kernel_sm8450_common_gts8x
- **Branch**: main
- **Description**: Samsung Galaxy Tab S8 kernel source

### Toolchains
- **AArch64 GCC**: https://kali.download/nethunter-images/toolchains/linaro-aarch64-5.5.tar.xz
- **ARM GCC**: https://kali.download/nethunter-images/toolchains/linaro-armhf-5.5.tar.xz
- **Clang**: https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b

### NetHunter Tools
- **Kernel Builder**: https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel
- **AnyKernel3**: https://github.com/osm0sis/AnyKernel3

## 📝 Notes

- All scripts should be run from the repository root directory
- Ensure you have sufficient disk space (at least 50GB free)
- Build process requires stable internet connection
- First build may take 30-60 minutes depending on hardware
- Subsequent builds are faster due to ccache
