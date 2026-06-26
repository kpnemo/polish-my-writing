#!/usr/bin/env bash
# Completely removes Polish My Writing and ALL of its local data, so the next
# install behaves as a true first-run: app bundle, preferences/settings, the
# saved API key, the Accessibility grant, caches, and saved window state.
#
# Only touches this app's own data (bundle id app.polishmywriting.app).
set -uo pipefail   # intentionally NOT -e: keep going even when a step finds nothing

BUNDLE_ID="app.polishmywriting.app"
KEYCHAIN_SERVICE="app.polishmywriting.apikeys"
APP="/Applications/Polish My Writing.app"

echo "==> Quitting the app…"
if pkill -f "PolishMyWriting" 2>/dev/null; then echo "    quit"; else echo "    (not running)"; fi
sleep 0.5

echo "==> Removing the app bundle…"
rm -rf "$APP" && echo "    removed $APP"
rm -rf "$HOME/Applications/Polish My Writing.app" 2>/dev/null || true

echo "==> Removing stored API keys from the Keychain…"
n=0
while security delete-generic-password -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1; do n=$((n+1)); done
echo "    removed $n keychain item(s)"

echo "==> Removing preferences / settings…"
defaults delete "$BUNDLE_ID" >/dev/null 2>&1 && echo "    cleared UserDefaults" || echo "    (no defaults)"
rm -f "$HOME/Library/Preferences/$BUNDLE_ID.plist" 2>/dev/null || true

echo "==> Resetting Accessibility permission (forces the first-run prompt)…"
tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 && echo "    reset" || echo "    (nothing to reset)"

echo "==> Clearing caches / saved state…"
rm -rf "$HOME/Library/Caches/$BUNDLE_ID" \
       "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState" \
       "$HOME/Library/HTTPStorages/$BUNDLE_ID" \
       "$HOME/Library/Application Support/$BUNDLE_ID" 2>/dev/null || true
echo "    cleared"

# Flush the prefs cache so a relaunch doesn't read stale values.
killall cfprefsd >/dev/null 2>&1 || true

echo ""
echo "Clean — the next install from the .dmg will behave as a first-time install."
echo "If you had 'Launch at login' enabled, remove the orphaned entry under"
echo "System Settings → General → Login Items (a login item can't be unregistered"
echo "from the command line once the app is gone)."
