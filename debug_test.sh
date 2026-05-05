#!/bin/bash
source ./build-nethunter.sh > /dev/null 2>&1
echo "Sourced build-nethunter.sh"
echo "Variables defined:"
env | grep "KERNEL_DIR\|SCRIPT_DIR\|GKI_DEFCONFIG" || true
