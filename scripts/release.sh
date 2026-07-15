#!/usr/bin/env bash
# Build, sign, package, and optionally notarize CleanLock for distribution.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-1.1.3}"
TEAM_ID="${TEAM_ID:-CC989JZCNV}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Brandon Charleson (CC989JZCNV)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
DIST="$ROOT/dist"
APP_NAME="CleanLock"
DERIVED="$ROOT/build-release"

rm -rf "$DIST" "$DERIVED"
mkdir -p "$DIST"

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Building Release"
xcodebuild \
  -project CleanLock.xcodeproj \
  -scheme CleanLock \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  build

APP="$DERIVED/Build/Products/Release/${APP_NAME}.app"
if [[ ! -d "$APP" ]]; then
  echo "Build failed: missing $APP" >&2
  exit 1
fi

echo "==> Verifying signature"
codesign --force --deep --options runtime --timestamp \
  --sign "$SIGN_IDENTITY" \
  "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

ZIP="$DIST/${APP_NAME}-${VERSION}.zip"
DMG="$DIST/${APP_NAME}-${VERSION}.dmg"

echo "==> Creating zip"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Creating DMG"
STAGE="$DIST/dmg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG"
rm -rf "$STAGE"

# Sign the DMG as well
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG" || true

if [[ -n "$NOTARY_PROFILE" ]]; then
  echo "==> Submitting zip for notarization (profile: $NOTARY_PROFILE)"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "==> Stapling"
  xcrun stapler staple "$APP"
  # Rebuild archives with stapled app
  ditto -c -k --keepParent "$APP" "$ZIP"
  rm -f "$DMG"
  STAGE="$DIST/dmg-stage"
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
  rm -rf "$STAGE"
  codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG" || true
  xcrun stapler staple "$DMG" || true
  spctl --assess --type execute -vv "$APP" || true
else
  echo "==> Skipping notarization (set NOTARY_PROFILE=your-profile to enable)"
fi

shasum -a 256 "$ZIP" "$DMG" | tee "$DIST/SHA256SUMS.txt"
echo "Artifacts in $DIST"
ls -lh "$DIST"
