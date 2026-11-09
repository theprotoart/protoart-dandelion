#!/bin/bash
# Double-click to make a .dmg of ProtoArt Dandelion to share with friends.
# Builds a fresh app, checks it, and packs it with an Applications shortcut and a Read Me.
cd "$(dirname "$0")"
ROOT="$(pwd)"
APP_NAME="ProtoArt Dandelion"
APP="$ROOT/$APP_NAME.app"
VERSION="$(sed -n 's/^VERSION="\(.*\)"/\1/p' "$ROOT/Build ProtoArt Dandelion.command" | head -1)"
mkdir -p "$ROOT/dist"
DMG="$ROOT/dist/ProtoArt-Dandelion-${VERSION}.dmg"
LOG="$ROOT/dist/dmg-log.txt"
exec > >(tee "$LOG") 2>&1
step() { printf '\n== %s\n' "$*"; }
fail() { printf '\nSTATUS: FAILED (%s)\n' "$*"; [ -t 0 ] && read -r -p "Press Return to close this window." _; exit 1; }

step "Building a fresh copy of the app"
bash "$ROOT/Build ProtoArt Dandelion.command" --no-open < /dev/null || fail "the build didn't finish"
[ -d "$APP" ] || fail "the build didn't produce $APP_NAME.app"

step "Checking it"
codesign --verify --deep --strict "$APP" >/dev/null 2>&1 && echo "Signature OK." || fail "the signature didn't verify"
echo "Runs on: $(lipo -archs "$APP/Contents/MacOS/$APP_NAME" 2>/dev/null)"

step "Packing the DMG"
STAGE="$(mktemp -d)/$APP_NAME"
mkdir -p "$STAGE"
cp -cR "$APP" "$STAGE/" 2>/dev/null || cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/Read Me First.txt" <<'TXT'
ProtoArt Dandelion · Model PD-1 · Mac cleaning unit (beta)

INSTALL
1. Drag ProtoArt Dandelion onto the Applications folder.
2. Open it once. macOS will say it can't check it (it isn't notarised yet).
3. Open System Settings → Privacy & Security, scroll down, click "Open Anyway", then Open.

RECOMMENDED: FULL DISK ACCESS AND APP MANAGEMENT
macOS never shows a pop-up for these; you switch them on yourself (once):
- Full Disk Access lets Dandelion see protected folders (the Trash, Mail attachments, app containers).
- App Management lets it remove other apps.
System Settings → Privacy & Security → Full Disk Access (and then App Management) → + →
choose ProtoArt Dandelion → switch it on → restart the app.
If Dandelion can't move an app itself, it asks Finder to do it; Finder may ask for your password,
and the first time macOS asks whether Dandelion may control Finder (choose OK).

SAFETY
- Nothing is removed until you review it and press CLEAN, UNINSTALL, REMOVE or TRASH.
- With the SAFE lever up (default), everything goes to the Trash, so you can put it back.
- Apple's own apps are never offered for removal.
- Leftovers of removed apps are never pre-selected; check each one before removing.

PRIVACY
Runs entirely on your Mac. No network connections, nothing is uploaded.

Needs macOS 14 (Sonoma) or later.
TXT
rm -f "$DMG"
echo "Compressing…"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format ULFO -fs HFS+ "$DMG" >/dev/null ||
  hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null ||
  fail "hdiutil couldn't create the DMG"
rm -rf "$(dirname "$STAGE")"
hdiutil verify "$DMG" >/dev/null 2>&1 && echo "DMG checked OK."
(cd "$ROOT/dist" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
echo "SHA-256: $(cut -d' ' -f1 "$DMG.sha256")"
echo "Size: $(du -h "$DMG" | cut -f1)"
echo
echo "STATUS: DONE"
