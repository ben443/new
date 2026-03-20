# NetHunter Kernel Builder for Samsung Galaxy Tab S8 (gts8wifi/SM-X700)
# Dockerfile for consistent build environment

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Set working directory
WORKDIR /build

# Install base dependencies
RUN apt-get update && apt-get install -y \
    # Core build tools
    git \
    build-essential \
    bc \
    bison \
    flex \
    libssl-dev \
    libncurses5-dev \
    libncursesw5-dev \
    device-tree-compiler \
    lz4 \
    xz-utils \
    wget \
    curl \
    python3 \
    python3-pip \
    ccache \
    libelf-dev \
    libxml2-utils \
    kmod \
    cpio \
    qttools5-dev \
    libqt5widgets5 \
    fakeroot \
    zip \
    unzip \
    lynx \
    pandoc \
    axel \
    binutils-aarch64-linux-gnu \
    # Additional tools
    vim \
    nano \
    htop \
    tree \
    jq \
    rsync \
    # SSL/TLS certificates
    ca-certificates \
    # Clean up
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install --no-cache-dir \
    pyyaml \
    requests \
    pygit2

# Set up ccache
ENV CCACHE_DIR=/build/.ccache
ENV CCACHE_COMPRESS=1
ENV CCACHE_MAXSIZE=50G
ENV USE_CCACHE=1
RUN mkdir -p /build/.ccache

# Create directories
RUN mkdir -p /build/toolchains /build/kernel /build/output /build/modules

# Copy build scripts
COPY build-nethunter.sh /build/
COPY device-config.sh /build/
COPY nethunter-config.fragment /build/

# Make scripts executable
RUN chmod +x /build/build-nethunter.sh /build/device-config.sh

# Set environment variables for toolchains
ENV TOOLCHAIN_DIR=/build/toolchains
ENV BUILD_DIR=/build
ENV OUTPUT_DIR=/build/output
ENV MODULES_DIR=/build/modules

# Volume for output
VOLUME ["/build/output", "/build/.ccache"]

# Default command
CMD ["/bin/bash"]

# Metadata
LABEL maintainer="NetHunter Community"
LABEL description="NetHunter Kernel Builder for Samsung Galaxy Tab S8 (gts8wifi/SM-X700)"
LABEL device="gts8wifi"
LABEL chipset="SM8450"
LABEL android_version="13"
LABEL kernel_version="5.10"
