#!/bin/bash

# This script decodes DART_DEFINES and writes them to a file that can be included in the build
# It should be run as a "Run Script" build phase before "Compile Sources"

set -e

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT_FILE="${SCRIPT_DIR}/../Flutter/DartDefines.xcconfig"

# Clear the output file
> "$OUTPUT_FILE"

# Check if DART_DEFINES exists
if [ -z "$DART_DEFINES" ]; then
    echo "Warning: DART_DEFINES is not set"
    exit 0
fi

# Decode each dart define
decode_dart_defines() {
    IFS=',' read -r -a define_items <<< "$DART_DEFINES"

    for item in "${define_items[@]}"; do
        # Decode base64
        decoded=$(echo "$item" | base64 --decode)

        # Split by = to get key and value
        key="${decoded%%=*}"
        value="${decoded#*=}"

        # Write to xcconfig file
        echo "$key=$value" >> "$OUTPUT_FILE"
    done
}

decode_dart_defines

echo "Dart defines processed and written to $OUTPUT_FILE"
