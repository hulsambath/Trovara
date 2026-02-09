#!/bin/bash

# Decode DART_DEFINES and export as environment variables
function decode_dart_defines() {
    if [ -z "$DART_DEFINES" ]; then
        return
    fi

    IFS=',' read -r -a define_items <<< "$DART_DEFINES"

    for index in "${!define_items[@]}"
    do
        item=$(echo "${define_items[$index]}" | base64 --decode)
        echo "Decoded: $item"

        # Export each define as an environment variable
        export "$item"
    done
}

decode_dart_defines
