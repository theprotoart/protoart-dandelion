#!/bin/bash
# Double-click to build "ProtoArt Dandelion.app" next to this file and open it.
#   --no-open   build only
# Needs Apple's free Command Line Tools (xcode-select --install).
cd "$(dirname "$0")"
ROOT="$(pwd)"
exec > >(tee "$ROOT/build-log.txt") 2>&1

APP_NAME="ProtoArt Dandelion"
BUNDLE_ID="local.protoart.dandelion"
APP="$ROOT/$APP_NAME.app"
VERSION="1.0.0-beta3"
step() { printf '\n== %s\n' "$*"; }
fail() { printf '\nSTATUS: FAILED (%s)\n' "$*"; [ -t 0 ] && read -r -p "Press Return to close this window." _; exit 1; }

step "1/5 Checking"
[ "$(uname -s)" = "Darwin" ] || fail "this builds a Mac app, so it has to run on a Mac"
command -v swift >/dev/null 2>&1 || { xcode-select --install >/dev/null 2>&1; fail "Apple's Command Line Tools are needed"; }
echo "Swift: $(swift --version 2>&1 | grep -m1 -o 'Swift version [0-9.]*')"

step "2/5 Compiling"
# keep this Mac's folder paths out of the app
PREFIX_MAP=(-Xswiftc -file-prefix-map -Xswiftc "$ROOT=.")
swift build -c release --arch arm64 "${PREFIX_MAP[@]}" > "$ROOT/.build-out.txt" 2>&1
BUILD_STATUS=$?
grep -vE '^\[[0-9]+/[0-9]+\] (Compiling|Write|Emitting)' "$ROOT/.build-out.txt"
[ $BUILD_STATUS -eq 0 ] || fail "the Swift code didn't compile (see above)"
ARM="$(swift build -c release --arch arm64 "${PREFIX_MAP[@]}" --show-bin-path)/Dandelion"
BIN="$ROOT/.build/Dandelion-universal"
# Intel slice too, so friends with Intel Macs can run it (skipped if it doesn't build)
if swift build -c release --arch x86_64 "${PREFIX_MAP[@]}" > "$ROOT/.build-out-x86.txt" 2>&1; then
  X86="$(swift build -c release --arch x86_64 "${PREFIX_MAP[@]}" --show-bin-path)/Dandelion"
  lipo -create "$ARM" "$X86" -output "$BIN" || fail "couldn't join the architectures"
else
  echo "(Intel build skipped: see .build-out-x86.txt)"
  cp "$ARM" "$BIN"
fi
# drop debug symbols (they record the build folder) and local symbol names
strip -S -x "$BIN" || fail "couldn't strip the binary"
echo "Runs on: $(lipo -archs "$BIN")"
echo "Binary: $(du -h "$BIN" | cut -f1)"

step "3/5 Icon"
ICONSET="$(mktemp -d)/Dandelion.iconset"; mkdir -p "$ICONSET"
swift tools/make-icon.swift "$ICONSET/icon_512x512@2x.png" >/dev/null || fail "icon drawing failed"
for s in 16 32 128 256 512; do
  sips -z $s $s "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2)); sips -z $d $d "$ICONSET/icon_512x512@2x.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$ROOT/.build/Dandelion.icns" || fail "iconutil failed"

step "4/5 App bundle"
osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
sleep 0.5
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/.build/Dandelion.icns" "$APP/Contents/Resources/Dandelion.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>Dandelion</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSDesktopFolderUsageDescription</key><string>Dandelion measures this folder and searches it for large files.</string>
    <key>NSDocumentsFolderUsageDescription</key><string>Dandelion measures this folder and searches it for large files.</string>
    <key>NSDownloadsFolderUsageDescription</key><string>Dandelion finds old installers and large files here.</string>
    <key>NSAppleEventsUsageDescription</key><string>Dandelion asks Finder to move protected apps to the Trash, and macOS for your password to run maintenance tasks.</string>
</dict>
</plist>
PLIST

step "5/5 Signing"
codesign --force --deep --sign - "$APP" || fail "ad-hoc signing failed"
echo "App size: $(du -sh "$APP" | cut -f1)"
echo
echo "STATUS: OK  →  $APP"
[ "$1" = "--no-open" ] || open "$APP"
