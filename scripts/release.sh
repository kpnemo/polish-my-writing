#!/usr/bin/env bash
# Build a SIGNED + NOTARIZED + STAPLED .dmg for direct distribution.
# Result: users double-click the .dmg, drag to Applications, and launch with no
# Gatekeeper warning, no Keychain prompt, and a persistent Accessibility grant.
#
# Prerequisites (one-time):
#   1) A "Developer ID Application" certificate in your keychain
#      (Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application).
#   2) A stored notarization profile:
#        xcrun notarytool store-credentials pmw-notary \
#          --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-pw"
#      (App-specific password from appleid.apple.com → Sign-In and Security.)
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Polish My Writing"
SRC="build/dd/Build/Products/Release/PolishMyWriting.app"
STAGE="build/dmg-stage"
DMG="build/$APP_NAME.dmg"
ENTITLEMENTS="App/PolishMyWriting.entitlements"
NOTARY_PROFILE="${NOTARY_PROFILE:-pmw-notary}"

# Auto-detect the Developer ID Application identity.
DEV_ID=$(security find-identity -v -p codesigning \
  | grep "Developer ID Application" | head -1 | sed -E 's/^[^"]*"([^"]+)".*/\1/')
if [ -z "$DEV_ID" ]; then
  echo "ERROR: No 'Developer ID Application' certificate found."
  echo "Create one: Xcode → Settings → Accounts → (your team) → Manage Certificates → + → Developer ID Application."
  exit 1
fi
echo "==> Signing identity: $DEV_ID"

echo "==> Building (Release)…"
xcodegen generate
xcodebuild -project PolishMyWriting.xcodeproj -scheme PolishMyWriting -configuration Release \
  -derivedDataPath build/dd \
  CODE_SIGNING_ALLOWED=NO build >/dev/null
echo "    build ok"

echo "==> Signing the app (Developer ID, hardened runtime, secure timestamp)…"
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" --sign "$DEV_ID" "$SRC"
codesign --verify --strict --verbose=2 "$SRC"

echo "==> Generating installer background…"
swift scripts/generate_dmg_background.swift

echo "==> Building the .dmg…"
rm -rf "$STAGE"; mkdir -p "$STAGE"
ditto "$SRC" "$STAGE/$APP_NAME.app"
rm -f "$DMG"
create-dmg \
  --volname "$APP_NAME" \
  --background "build/dmg_background.png" \
  --window-pos 200 120 --window-size 600 400 --icon-size 120 \
  --icon "$APP_NAME.app" 150 200 --hide-extension "$APP_NAME.app" \
  --app-drop-link 450 200 --no-internet-enable \
  "$DMG" "$STAGE" || true
[ -f "$DMG" ] || { echo "ERROR: dmg not created"; exit 1; }

echo "==> Signing the .dmg…"
codesign --force --sign "$DEV_ID" --timestamp "$DMG"

echo "==> Notarizing (uploads to Apple; usually 1-5 min)…"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling the notarization ticket…"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "==> Gatekeeper assessment…"
spctl -a -vvv -t install "$DMG" || true

echo ""
echo "DONE: $DMG  (signed + notarized + stapled)"
open -R "$DMG"
