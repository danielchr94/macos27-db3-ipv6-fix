#!/bin/bash
# Build the menu bar app into a self-contained, ad-hoc signed .app bundle and
# zip it for distribution. Requires the Swift toolchain (Xcode command line tools).
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="macOS 27 DB3 IPv6 Fix"
BUNDLE_ID="io.github.danielchr94.macos27db3ipv6fix"
VERSION="1.1.0"
BIN="mac27ipv6fix"

APP="dist/$APP_NAME.app"
MACOS_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"

echo "==> Cleaning previous build"
rm -rf build "$APP" "dist/macOS-27-DB3-IPv6-Fix.zip"
mkdir -p build "$MACOS_DIR" "$RES_DIR"

echo "==> Compiling Swift"
swiftc -O -framework AppKit Sources/main.swift -o "build/$BIN"
cp "build/$BIN" "$MACOS_DIR/$BIN"

echo "==> Writing Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleExecutable</key><string>$BIN</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$APP"

echo "==> Zipping for distribution"
ditto -c -k --keepParent "$APP" "dist/macOS-27-DB3-IPv6-Fix.zip"

echo "==> Done"
echo "    App: $APP"
echo "    Zip: dist/macOS-27-DB3-IPv6-Fix.zip"
