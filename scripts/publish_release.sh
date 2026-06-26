#!/usr/bin/env bash
# Build the notarized DMG and publish it as a NEW GitHub release.
#
# IMPORTANT: this NEVER deletes or overwrites prior releases or tags. Each
# version stays published so download counts and history accumulate. To ship a
# new version, bump CFBundleShortVersionString (App/Info.plist) + MARKETING_VERSION
# (project.yml) first; this script refuses to run if the tag already exists.
#
# Notarization credentials come from scripts/release.sh — provide EITHER a
# stored `pmw-notary` profile OR the App Store Connect API key via env:
#   NOTARY_KEY=/path/AuthKey_XXXX.p8 NOTARY_KEY_ID=XXXX NOTARY_ISSUER=<uuid> \
#     scripts/publish_release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="kpnemo/polish-my-writing"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' App/Info.plist)
TAG="v$VERSION"

# Never clobber an existing release/tag — bump the version instead.
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "ERROR: release $TAG already exists." >&2
  echo "Bump CFBundleShortVersionString (App/Info.plist) + MARKETING_VERSION (project.yml) first." >&2
  exit 1
fi

# Build + sign (Developer ID, hardened runtime) + notarize + staple.
bash scripts/release.sh

# Stable, space-free asset name for a tidy, predictable download URL.
cp "build/Polish My Writing.dmg" "build/PolishMyWriting.dmg"

# Publish a NEW release. Do NOT pass --cleanup-tag, and never call
# `gh release delete` on a prior version.
gh release create "$TAG" "build/PolishMyWriting.dmg#Polish My Writing $VERSION (macOS, notarized)" \
  --repo "$REPO" --title "Polish My Writing $VERSION" --latest \
  --notes "${RELEASE_NOTES:-Polish My Writing $VERSION. Free macOS app — download the .dmg, drag to Applications, launch. Requires macOS 14+ and your own Anthropic/OpenAI/OpenRouter/Gemini API key.}"

echo ""
echo "Published $TAG. Prior releases are left intact:"
gh release list --repo "$REPO" --limit 20
