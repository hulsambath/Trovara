#!/usr/bin/env bash
set -euo pipefail

# Generates iOS Light/Dark AppIcon bitmaps from a single transparent source,
# similar to Android adaptive icon flow (foreground + background color),
# but rendered into the iOS asset catalog (iOS requires pre-rendered PNGs).

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT_DIR}/assets/app_icon/512x512_ios.png"
APPICON_DIR="${ROOT_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset"
FLATTENER="${ROOT_DIR}/tooling/flatten_png.swift"

LIGHT_BG="#415bca"
DARK_BG="#313233"

if [[ ! -f "$SRC" ]]; then
  echo "error: missing source icon: $SRC" >&2
  exit 1
fi

if [[ ! -d "$APPICON_DIR" ]]; then
  echo "error: missing AppIcon set: $APPICON_DIR" >&2
  exit 1
fi

if [[ ! -f "$FLATTENER" ]]; then
  echo "error: missing flattener script: $FLATTENER" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

base_1024="${tmpdir}/base-1024.png"
# Upscale the source to 1024 to be the single raster source.
sips -z 1024 1024 "$SRC" --out "$base_1024" >/dev/null

# Map of required icon sizes -> output filename prefix.
# We'll generate only the filenames referenced by Contents.json.
declare -a entries=(
  "20:Icon-App-20x20@1x"
  "40:Icon-App-20x20@2x"
  "60:Icon-App-20x20@3x"

  "29:Icon-App-29x29@1x"
  "58:Icon-App-29x29@2x"
  "87:Icon-App-29x29@3x"

  "40:Icon-App-40x40@1x"
  "80:Icon-App-40x40@2x"
  "120:Icon-App-40x40@3x"

  "50:Icon-App-50x50@1x"
  "100:Icon-App-50x50@2x"

  "57:Icon-App-57x57@1x"
  "114:Icon-App-57x57@2x"

  "120:Icon-App-60x60@2x"
  "180:Icon-App-60x60@3x"

  "72:Icon-App-72x72@1x"
  "144:Icon-App-72x72@2x"

  "76:Icon-App-76x76@1x"
  "152:Icon-App-76x76@2x"

  "167:Icon-App-83.5x83.5@2x"

  "1024:Icon-App-1024x1024@1x"
)

for entry in "${entries[@]}"; do
  px="${entry%%:*}"
  name="${entry#*:}"

  sized="${tmpdir}/${name}.png"
  sips -z "$px" "$px" "$base_1024" --out "$sized" >/dev/null

  # Light (default)
  swift "$FLATTENER" "$sized" "${APPICON_DIR}/${name}.png" "$LIGHT_BG"
  # Dark appearance
  swift "$FLATTENER" "$sized" "${APPICON_DIR}/${name}-dark.png" "$DARK_BG"
done

echo "Generated iOS AppIcon light/dark from ${SRC}"
