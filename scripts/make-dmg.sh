#!/bin/bash
# Packs dist/Deskling.app into dist/Deskling-<version>.dmg. Usage: scripts/make-dmg.sh <version>
set -euo pipefail
VERSION="${1:?usage: make-dmg.sh <version>}"
cd "$(dirname "$0")/.."

STAGE="$(mktemp -d)"
cp -R dist/Deskling.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Deskling" -srcfolder "$STAGE" -ov -format UDZO "dist/Deskling-$VERSION.dmg"
echo "dist/Deskling-$VERSION.dmg"
