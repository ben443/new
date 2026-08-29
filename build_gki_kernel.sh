#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/output"

chmod +x "${SCRIPT_DIR}/build-nethunter.sh"
"${SCRIPT_DIR}/build-nethunter.sh" full

if ! compgen -G "${OUTPUT_DIR}/*.zip" > /dev/null; then
    echo "No flashable kernel zip found in ${OUTPUT_DIR}"
    exit 1
fi

echo "NetHunter GKI build completed successfully."
