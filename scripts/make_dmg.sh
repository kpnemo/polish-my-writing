#!/usr/bin/env bash
# Build the app and package it into a drag-to-Applications .dmg installer.
# Does NOT install anything — it just produces build/Polish My Writing.dmg, which
# you double-click and drag into Applications (Finder prompts to replace if it
# already exists).
#
# Run scripts/setup_local_signing.sh once first so the app gets the stable
# signature (keeps the Accessibility grant across reinstalls).
set -euo pipefail
cd "$(dirname "$0")/.."

CERT="Polish My Writing Dev"
APP_NAME="Polish My Writing"
SRC="build/dd/Build/Products/Release/PolishMyWriting.app"
STAGE="build/dmg-stage"
DMG="build/$APP_NAME.dmg"

echo "==> Building (Release)…"
xcodegen generate
xcodebuild -project PolishMyWriting.xcodeproj -scheme PolishMyWriting -configuration Release \
  -derivedDataPath build/dd \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES build >/dev/null
echo "    build ok"

echo "==> Generating installer background…"
swift scripts/generate_dmg_background.swift

echo "==> Staging + signing the app…"
rm -rf "$STAGE"; mkdir -p "$STAGE"
ditto "$SRC" "$STAGE/$APP_NAME.app"
if security find-identity -p codesigning | grep -q "$CERT"; then
  codesign --force --deep --options runtime \
    --entitlements App/PolishMyWriting.entitlements --sign "$CERT" "$STAGE/$APP_NAME.app"
  echo "    signed with stable identity ($CERT)"
else
  codesign --force --deep --sign - "$STAGE/$APP_NAME.app"
  echo "    WARNING: ad-hoc signed — run scripts/setup_local_signing.sh to keep the Accessibility grant"
fi

echo "==> Building the .dmg…"
rm -f "$DMG"
# create-dmg sometimes exits non-zero even when the .dmg is fine; verify by file.
create-dmg \
  --volname "$APP_NAME" \
  --background "build/dmg_background.png" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 120 \
  --icon "$APP_NAME.app" 150 200 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 450 200 \
  --no-internet-enable \
  "$DMG" \
  "$STAGE" || true

if [ -f "$DMG" ]; then
  echo "==> Done: $DMG"
  open -R "$DMG"  # reveal it in Finder
else
  echo "ERROR: DMG was not created"; exit 1
fi
