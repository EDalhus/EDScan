#!/bin/bash
# Builds ED Scan and packages it as ED Scan.app. Run from the project directory: ./build.sh
#   ./build.sh --release   also writes ED-Scan-<version>.zip for a GitHub release
set -euo pipefail
cd "$(dirname "$0")"

# Universal binary (Apple silicon + Intel), minimum macOS 13.
ARCHS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)/EDScan"

APP="ED Scan.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/EDScan"
cp Support/Info.plist "$APP/Contents/"

# Ad-hoc signature so the bundle is consistent (no Developer ID yet).
codesign --force --deep --sign - "$APP"

echo "✓ Built: $(pwd)/$APP"
echo "  Run with: open \"$APP\""

if [[ "${1:-}" == "--release" ]]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Support/Info.plist)
    ZIP="ED-Scan-$VERSION.zip"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    echo "✓ Release archive: $(pwd)/$ZIP"
fi
