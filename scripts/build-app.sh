#!/bin/bash
# Builds Pawprints.app into dist/. Image Playground only paints for a real,
# signed app bundle, so `swift run` alone is not enough.
#
#   scripts/build-app.sh            release build, ad-hoc signed
#   scripts/build-app.sh debug      debug build
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
APP="dist/Pawprints.app"

swift build -c "$CONFIG" --product Pawprints
swift build -c "$CONFIG" --product PawprintsPainter
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Pawprints" "$APP/Contents/MacOS/Pawprints"

# The painting helper: a faceless app that paints queued pictures and quits.
# (Holding Image Playground in the game itself would lock CLI tools out of the model.)
HELPER="$APP/Contents/Helpers/Pawprints Painter.app"
mkdir -p "$HELPER/Contents/MacOS"
cp "$BIN_DIR/PawprintsPainter" "$HELPER/Contents/MacOS/PawprintsPainter"
cat > "$HELPER/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>dev.apfel.pawprints.painter</string>
    <key>CFBundleName</key><string>Pawprints Painter</string>
    <key>CFBundleExecutable</key><string>PawprintsPainter</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

if [[ -f Resources/AppIcon.png ]]; then
    ICONSET="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for size in 16 32 128 256 512; do
        sips -z $size $size Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        sips -z $((size * 2)) $((size * 2)) Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
fi

VERSION="$(git describe --tags --always 2>/dev/null || echo 1.0)"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>dev.apfel.pawprints</string>
    <key>CFBundleName</key><string>Pawprints</string>
    <key>CFBundleDisplayName</key><string>Pawprints</string>
    <key>CFBundleExecutable</key><string>Pawprints</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.puzzle-games</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$HELPER" >/dev/null 2>&1
codesign --force --sign - "$APP" >/dev/null 2>&1
echo "Built $APP"
