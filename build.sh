#!/bin/bash
# Builds ED Scan and packages it as ED Scan.app. Run from the project directory: ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/EDScan"

APP="ED Scan.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/EDScan"
cp Support/Info.plist "$APP/Contents/"

echo "✓ Built: $(pwd)/$APP"
echo "  Run with: open \"$APP\""
