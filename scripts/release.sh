#!/usr/bin/env bash
set -euo pipefail

# Required: your Developer ID and notarization credentials.
DEV_ID="Developer ID Application: YOUR NAME (TEAMID)"
KEYCHAIN_PROFILE="polish-notary"   # created once via: xcrun notarytool store-credentials
APP_NAME="Polish My Writing"
SCHEME="PolishMyWriting"

BUILD_DIR="$(pwd)/build"
EXPORT_DIR="$BUILD_DIR/export"
rm -rf "$BUILD_DIR"
mkdir -p "$EXPORT_DIR"

xcodegen generate

# Archive and export a Developer-ID-signed app.
xcodebuild -project PolishMyWriting.xcodeproj -scheme "$SCHEME" \
  -configuration Release -archivePath "$BUILD_DIR/app.xcarchive" archive

cat > "$BUILD_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
</dict></plist>
PLIST

xcodebuild -exportArchive -archivePath "$BUILD_DIR/app.xcarchive" \
  -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
  -exportPath "$EXPORT_DIR"

APP_PATH="$EXPORT_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"

# Build a simple .dmg with a drag-to-Applications layout.
STAGE="$BUILD_DIR/dmg-stage"
mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG_PATH"

# Notarize and staple the .dmg.
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$KEYCHAIN_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"

echo "Built and notarized: $DMG_PATH"
