#!/bin/bash

# This script is called by Flutter's xcode_backend.sh after the build
# It processes the Info.plist to replace placeholders with dart-define values

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Call the process_infoplist script
"${SCRIPT_DIR}/process_infoplist.sh"
