#!/usr/bin/env bash
# Build the app, install it to /Applications, sign it with the stable local
# identity (so the Accessibility grant AND the saved API key in the Keychain
# persist across rebuilds), and launch it.
#
# Run scripts/setup_local_signing.sh once first to create the identity.
# Set NO_LAUNCH=1 to install without launching (e.g. to observe a genuine
# first-run from Finder yourself).
set -euo pipefail
cd "$(dirname "$0")/.."

CERT="Polish My Writing Dev"
DEST="/Applications/Polish My Writing.app"
SRC="build/dd/Build/Products/Release/PolishMyWriting.app"

# Stable signing is a correctness requirement, not a nicety: an ad-hoc signature
# changes every build, so the Keychain item's ACL stops matching and macOS pops a
# login-password prompt on launch (which blocks the launch). Fail loudly instead
# of silently degrading to ad-hoc.
if ! security find-identity -p codesigning | grep -q "$CERT"; then
  echo "ERROR: stable signing identity \"$CERT\" not found." >&2
  echo "Run scripts/setup_local_signing.sh once to create it, then re-run this." >&2
  exit 1
fi

xcodegen generate
xcodebuild -project PolishMyWriting.xcodeproj -scheme PolishMyWriting -configuration Release \
  -derivedDataPath build/dd \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES build

pkill -f PolishMyWriting 2>/dev/null || true
sleep 0.3
rm -rf "$DEST"
ditto "$SRC" "$DEST"

codesign --force --deep --options runtime \
  --entitlements App/PolishMyWriting.entitlements --sign "$CERT" "$DEST"
echo "Signed with stable identity ($CERT) — Accessibility grant + Keychain access persist."
# Sanity-check the signature is the dev leaf and NOT ad-hoc.
codesign --verify --strict "$DEST"
codesign -dr - "$DEST" 2>/dev/null | grep -qi adhoc && { echo "ERROR: bundle is ad-hoc signed" >&2; exit 1; }

if [ -n "${NO_LAUNCH:-}" ]; then
  echo "Installed (not launched): $DEST"
else
  open "$DEST"
  echo "Installed and launched: $DEST"
fi
