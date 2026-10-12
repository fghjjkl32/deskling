#!/bin/bash
# Packs dist/Deskling.app into dist/Deskling-<version>.dmg. Usage: scripts/make-dmg.sh <version>
set -euo pipefail
VERSION="${1:?usage: make-dmg.sh <version>}"
VERSION="${VERSION#v}"
if ! [[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
  echo "error: invalid version '$VERSION' (expected e.g. 0.1.0)" >&2
  exit 1
fi
cd "$(dirname "$0")/.."

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R dist/Deskling.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Deskling" -srcfolder "$STAGE" -ov -format UDZO "dist/Deskling-$VERSION.dmg"
echo "dist/Deskling-$VERSION.dmg"
