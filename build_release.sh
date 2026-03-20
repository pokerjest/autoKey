#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(cat "$ROOT_DIR/VERSION")"
APP_NAME="AutoKeyWriter"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ZIP_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-macOS.zip"

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$DIST_DIR"

clang -fobjc-arc -framework Cocoa "$ROOT_DIR/AutoKeyWriter.m" -o "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$CONTENTS_DIR/Info.plist"

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

echo "Built app bundle: $APP_DIR"
echo "Built release zip: $ZIP_PATH"
