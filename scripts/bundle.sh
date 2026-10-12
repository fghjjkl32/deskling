#!/bin/bash
# Builds a universal Deskling.app into dist/. Usage: scripts/bundle.sh [version]
set -euo pipefail
VERSION="${1:-0.0.0}"
VERSION="${VERSION#v}"
if ! [[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
  echo "error: invalid version '$VERSION' (expected e.g. 0.1.0)" >&2
  exit 1
fi
cd "$(dirname "$0")/.."

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

APP="dist/Deskling.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Deskling" "$BIN/deskling-hook" "$APP/Contents/MacOS/"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"
cp -R Resources/skins "$APP/Contents/Resources/skins"

ICONSET_ROOT="$(mktemp -d)"
trap 'rm -rf "$ICONSET_ROOT"' EXIT
ICONSET="$ICONSET_ROOT/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  double=$((size * 2))
  sips -z "$size" "$size" Resources/icon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z "$double" "$double" Resources/icon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP/Contents/MacOS/deskling-hook"
codesign --force --sign - "$APP"
echo "$APP"
