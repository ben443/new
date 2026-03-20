# Quick Start Guide - NetHunter Kernel for Galaxy Tab S8

This guide will help you quickly build and install the NetHunter kernel for your Samsung Galaxy Tab S8 (gts8wifi/SM-X700).

**⚠️ This device uses GKI (Generic Kernel Image). See [GKI Information](#gki-notes) below.**

## 🔄 GKI Notes

The Samsung Galaxy Tab S8 (SM8450) uses GKI (Generic Kernel Image):
- GKI Version: android13-5.10
- The build process creates a generic kernel + vendor modules
- Vendor modules are loaded after boot

## ⚡ Quick Build (5 minutes setup)

### 1. Prerequisites

```bash
# Update system
sudo apt-get update

# Install dependencies
sudo apt-get install -y git build-essential bc bison flex libssl-dev \
    libncurses5-dev device-tree-compiler lz4 xz-utils wget curl \
    python3 ccache libelf-dev kmod zip unzip
```

### 2. Clone and Build

```bash
# Clone this repository
git clone https://github.com/yourusername/nethunter-gts8wifi.git
cd nethunter-gts8wifi

# Make scripts executable
chmod +x build-nethunter.sh flash-helper.sh

# Run full build (this will take 30-60 minutes)
./build-nethunter.sh full
```

### 3. Flash the Kernel

#### Option A: Via Fastboot (Recommended for testing)

```bash
# Reboot to bootloader
adb reboot bootloader

# Flash boot image
fastboot flash boot output/boot.img

# Reboot
fastboot reboot
```

#### Option B: Via TWRP (Recommended for permanent install)

```bash
# Use flash helper
./flash-helper.sh

# Select option 4 (Flash via TWRP)
```

#### Option C: Via Magisk Manager

1. Copy the AnyKernel zip to your device
2. Open Magisk Manager
3. Go to Modules → Install from storage
4. Select the NetHunter zip
5. Reboot

## 🐳 Docker Build (Easiest method)

```bash
# Build Docker image
docker build -t nethunter-gts8wifi-builder .

# Run build
docker run -v $(pwd)/output:/build/output nethunter-gts8wifi-builder ./build-nethunter.sh full

# Or use docker-compose
docker-compose up --build
```

## 📋 Post-Installation

### 1. Install NetHunter App

1. Download from [store.nethunter.com](https://store.nethunter.com)
2. Install NetHunter app and NetHunter Terminal
3. Grant root permissions

### 2. Install Kali Chroot

```bash
# Via NetHunter app
1. Open NetHunter app
2. Go to Kali Chroot Manager
3. Select "Install Kali Chroot"
4. Choose "Full" installation
5. Wait for download and installation
```

Or via command line:

```bash
# Download chroot
wget https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-full.tar.xz

# Push to device
adb push kalifs-arm64-full.tar.xz /sdcard/

# Install via NetHunter app or terminal
```

### 3. Test WiFi Adapter

```bash
# Connect WiFi adapter via USB OTG
# Check if detected
adb shell "su -c 'lsusb'"

# Load driver (if needed)
adb shell "su -c 'modprobe 88XXau'"

# Check interface
adb shell "su -c 'iwconfig'"
```

## 🔧 Common Commands

```bash
# Build specific component
./build-nethunter.sh configure    # Configure kernel only
./build-nethunter.sh build        # Build kernel only
./build-nethunter.sh package      # Package kernel only

# Flash helper commands
./flash-helper.sh                 # Interactive menu
./flash-helper.sh backup          # Backup current kernel
./flash-helper.sh restore         # Restore backup
./flash-helper.sh status          # Check kernel status
```

## 🆘 Troubleshooting

### Build fails with "out of memory"

```bash
# Reduce parallel jobs
export JOBS=2
./build-nethunter.sh build
```

### Device bootloops after flash

```bash
# Restore backup
./flash-helper.sh
# Select option 7 (Restore Kernel Backup)
```

### WiFi adapter not detected

```bash
# Check USB connection
adb shell "su -c 'lsusb'"

# Load driver manually
adb shell "su -c 'modprobe 88XXau'"  # For RTL8812AU
adb shell "su -c 'modprobe r8188eu'" # For RTL8188EUS
```

## 📚 Next Steps

- Read the full [README.md](README.md) for detailed information
- Check [NetHunter Documentation](https://www.kali.org/docs/nethunter/)
- Join the [XDA Forums](https://xdaforums.com/c/samsung-galaxy-tab-s8.12693/) for support

## ⚠️ Important Notes

- **Backup your data** before flashing
- **Unlock bootloader** before starting (this will wipe data)
- **Flash at your own risk** - custom kernels can brick your device
- **Knox will be tripped** - this is irreversible
