#!/bin/bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Running as script"
else
    echo "Sourced"
fi
