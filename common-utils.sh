#!/bin/bash
################################################################################
# Common Utilities for NetHunter Build and Flash Scripts
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Helper Functions

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_banner() {
    local title="${1:-NetHunter Script}"
    local subtitle="${2:-gts8wifi (SM-X700)}"
    local color="${3:-${CYAN}}"

    echo -e "${color}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    # Ensure title is centered in a 76 char wide line.
    local pad=76
    local title_len=${#title}
    local left_pad=$(( (pad - title_len) / 2 ))
    local right_pad=$(( pad - title_len - left_pad ))
    printf "║%*s%s%*s║\n" $left_pad "" "$title" $right_pad ""

    local sub_len=${#subtitle}
    local s_left_pad=$(( (pad - sub_len) / 2 ))
    local s_right_pad=$(( pad - sub_len - s_left_pad ))
    printf "║%*s%s%*s║\n" $s_left_pad "" "$subtitle" $s_right_pad ""

    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}
