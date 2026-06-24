#!/usr/bin/env bash
# Build the app, install it to /Applications, sign it with the stable local
# identity (so the Accessibility grant persists), and launch it.
#
# Run scripts/setup_local_signing.sh once first to create the identity.
set -euo pipefail
cd "$(dirname "$0")/.."

CERT="Polish My Writing Dev"
DEST="/Applications/Polish My Writing.app"
SRC="build/dd/Build/Products/Release/PolishMyWriting.app"

xcodegen generate
xcodebuild -project PolishMyWriting.xcodeproj -scheme PolishMyWriting -configuration Release \
  -derivedDataPath build/dd \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES build

pkill -f PolishMyWriting 2>/dev/null || true
sleep 0.3
rm -rf "$DEST"
ditto "$SRC" "$DEST"

if security find-identity -p codesigning | grep -q "$CERT"; then
  codesign --force --deep --options runtime \
    --entitlements App/PolishMyWriting.entitlements --sign "$CERT" "$DEST"
  echo "Signed with stable identity ($CERT) — Accessibility grant will persist."
else
  codesign --force --deep --sign - "$DEST"
  echo "WARNING: stable identity not found; signed ad-hoc. Run scripts/setup_local_signing.sh"
  echo "to stop Accessibility from re-prompting on every rebuild."
fi

open "$DEST"
echo "Installed and launched: $DEST"
