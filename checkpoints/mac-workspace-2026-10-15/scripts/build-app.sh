#!/bin/bash
set -euo pipefail
STUDIO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$STUDIO_ROOT"
STUDIO_CONFIG="${1:-release}"
python3 scripts/validate-distribution.py --preflight
swift build -c "$STUDIO_CONFIG" --product ShortcutStudio
STUDIO_BIN="$(swift build -c "$STUDIO_CONFIG" --show-bin-path)"
mkdir -p "$STUDIO_ROOT/.build" "$STUDIO_ROOT/dist"
STUDIO_STAGE="$(mktemp -d "$STUDIO_ROOT/.build/app-stage.XXXXXX")"
STUDIO_APP="$STUDIO_STAGE/Shortcut Studio.app"
STUDIO_DESTINATION="$STUDIO_ROOT/dist/Shortcut Studio.app"
mkdir -p "$STUDIO_APP/Contents/MacOS" "$STUDIO_APP/Contents/Resources"
cp "$STUDIO_BIN/ShortcutStudio" "$STUDIO_APP/Contents/MacOS/ShortcutStudio"
cp scripts/Info.plist "$STUDIO_APP/Contents/Info.plist"
cp scripts/PrivacyInfo.xcprivacy "$STUDIO_APP/Contents/Resources/PrivacyInfo.xcprivacy"
rm -rf "$STUDIO_APP/Contents/Resources/Handbook"
cp -R docs/site "$STUDIO_APP/Contents/Resources/Handbook"
swift scripts/icon.swift "$STUDIO_APP/Contents/Resources"
STUDIO_IDENTITY="${STUDIO_SIGNING_IDENTITY:--}"
if [[ "$STUDIO_IDENTITY" == "-" ]]; then
 codesign --force --options runtime --sign - "$STUDIO_APP"
else
 codesign --force --options runtime --timestamp --sign "$STUDIO_IDENTITY" "$STUDIO_APP"
fi
codesign --verify --deep --strict "$STUDIO_APP"
ditto -c -k --sequesterRsrc --keepParent "$STUDIO_APP" dist/Shortcut-Studio-macOS.zip
if [[ -n "${STUDIO_NOTARY_PROFILE:-}" ]]; then
 [[ "$STUDIO_IDENTITY" != "-" ]] || { echo 'Notarization requires Developer ID.' >&2; exit 1; }
 xcrun notarytool submit dist/Shortcut-Studio-macOS.zip --keychain-profile "$STUDIO_NOTARY_PROFILE" --wait --output-format json > verification/notary-result.json
 python3 -c 'import json; assert json.load(open("verification/notary-result.json"))["status"] == "Accepted"'
 xcrun stapler staple "$STUDIO_APP"
 xcrun stapler validate "$STUDIO_APP"
 ditto -c -k --sequesterRsrc --keepParent "$STUDIO_APP" dist/Shortcut-Studio-macOS.zip
fi
# Never overwrite the executable inode of a running signed process.
# Keep the prior bundle in this excluded staging directory until later cleanup.
if [[ -e "$STUDIO_DESTINATION" ]]; then
 /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$STUDIO_DESTINATION" >/dev/null 2>&1 || true
 mv "$STUDIO_DESTINATION" "$STUDIO_STAGE/previous.bundle-backup"
fi
if ! mv "$STUDIO_APP" "$STUDIO_DESTINATION"; then
 if [[ -e "$STUDIO_STAGE/previous.bundle-backup" ]]; then mv "$STUDIO_STAGE/previous.bundle-backup" "$STUDIO_DESTINATION"; fi
 exit 1
fi
STUDIO_APP="$STUDIO_DESTINATION"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$STUDIO_DESTINATION" >/dev/null 2>&1 || true
python3 scripts/package-artifacts.py "$STUDIO_CONFIG"
python3 scripts/validate-distribution.py
printf '%s\n' "$STUDIO_APP"
