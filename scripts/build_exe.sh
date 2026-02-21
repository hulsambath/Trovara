#!/bin/bash
# Use this [bin/build_exe.sh] to build Flutter project for a specific flavor.

FLAVOR=$1

# Function to convert JSON file to --dart-define flags
json_to_dart_define() {
  local CONFIG_FILE=$1
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found: $CONFIG_FILE"
    exit 1
  fi

  # Using jq to convert JSON to --dart-define=KEY=VALUE
  jq -r 'to_entries | map("--dart-define=\(.key)=\(.value|tostring)") | .[]' "$CONFIG_FILE"
}

case "$FLAVOR" in
  -nm | --trovara)
    CONFIG_FILE="configs/trovara.json"
    DEFINE_FLAGS=$(json_to_dart_define "$CONFIG_FILE")
    CMD="flutter build windows $DEFINE_FLAGS"
    ;;
  *)
    echo "Invalid option: $FLAVOR"
    echo "Usage: bin/build_exe.sh [--trovara]"
    exit 1
    ;;
esac

# Remove first argument
shift

echo "Executing: $CMD $@"
eval $CMD "$@"
