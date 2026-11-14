#!/bin/bash
# Double-click to run Dandelion's security tests. Needs Apple's Command Line Tools.
cd "$(dirname "$0")"
ROOT="$(pwd)"
OUT="$(mktemp -d)"
echo "== Compiling the tests with the app's own code"
swiftc -module-name Dandelion -o "$OUT/security-tests" \
  Sources/Dandelion/Shared/FS.swift Sources/Dandelion/Junk/JunkModel.swift \
  Sources/Dandelion/Uninstaller/UninstallerModel.swift Tests/SecurityTests/main.swift || { echo "FAILED to compile"; exit 1; }
"$OUT/security-tests"; STATUS=$?

APP="$ROOT/ProtoArt Dandelion.app"
if [ -d "$APP" ]; then
  echo
  echo "Signed app (build it first with Build ProtoArt Dandelion.command)"
  if codesign -d --verbose=2 "$APP" 2>&1 | grep -q 'flags=.*runtime'; then echo "  PASS  hardened runtime is on"; else echo "  FAIL  hardened runtime is off"; STATUS=1; fi
  if codesign -d --entitlements - "$APP" 2>/dev/null | grep -q 'automation.apple-events'; then echo "  PASS  Finder automation entitlement present"; else echo "  FAIL  Finder automation entitlement missing"; STATUS=1; fi
  # Try to load outside code into the app, the way malware would to borrow its Full Disk Access.
  MARK="/tmp/dandelion-dylib-$$"
  printf '#include <stdio.h>\n__attribute__((constructor)) static void hit(void){FILE*f=fopen("%s","w");if(f)fclose(f);}\n' "$MARK" > "$OUT/inject.c"
  clang -dynamiclib -o "$OUT/inject.dylib" "$OUT/inject.c" 2>/dev/null
  DYLD_INSERT_LIBRARIES="$OUT/inject.dylib" "$APP/Contents/MacOS/ProtoArt Dandelion" >/dev/null 2>&1 & PID=$!
  sleep 3; kill $PID 2>/dev/null; wait $PID 2>/dev/null
  if [ -f "$MARK" ]; then echo "  FAIL  outside code was loaded into Dandelion"; rm -f "$MARK"; STATUS=1; else echo "  PASS  outside code can't be loaded into Dandelion"; fi
fi
rm -rf "$OUT"
echo
[ $STATUS -eq 0 ] && echo "STATUS: ALL PASSED" || echo "STATUS: FAILED"
exit $STATUS
