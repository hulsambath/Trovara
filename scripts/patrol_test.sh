#!/usr/bin/env bash
set -euo pipefail

# patrol_test.sh — wrapper for `patrol test` that injects a default flavor when none is provided.
# Usage: ./scripts/patrol_test.sh [patrol args...]
# Set PATROL_DEFAULT_FLAVOR to override the repository default (defaults to 'staging').

DEFAULT_FLAVOR="${PATROL_DEFAULT_FLAVOR:-staging}"

# Detect if a flavor flag is already present: --flavor, --flavor=, -f, -f=
has_flavor=false
for arg in "$@"; do
  case "$arg" in
    --flavor|--flavor=*|-f|-f=*)
      has_flavor=true
      break
      ;;
  esac
done

if [ "$has_flavor" = false ]; then
  echo "No --flavor provided; defaulting to flavor: $DEFAULT_FLAVOR"
  # Append the flavor flag at the end of the args
  set -- "$@" --flavor "$DEFAULT_FLAVOR"
fi

# Exec patrol with the (possibly modified) args
exec patrol test "$@"
