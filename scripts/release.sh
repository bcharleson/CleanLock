#!/usr/bin/env bash
# Build, sign, notarize, and Sparkle-sign CleanLock for distribution.
# Full checklist: docs/RELEASING.md
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-1.1.4}"
BUILD="${BUILD:-6}"
TEAM_ID="${TEAM_ID:-CC989JZCNV}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Brandon Charleson (CC989JZCNV)}"
# Same keychain profile used by Grok (xcrun notarytool store-credentials "notarytool-profile")
NOTARY_PROFILE="${NOTARY_PROFILE:-notarytool-profile}"
DIST="$ROOT/dist"
APP_NAME="CleanLock"
DERIVED="$ROOT/build-release"
SIGN_UPDATE="${SIGN_UPDATE:-$ROOT/scripts/bin/sign_update}"
APPCAST="${APPCAST:-$ROOT/appcast.xml}"
DOWNLOAD_URL_PREFIX="${DOWNLOAD_URL_PREFIX:-https://github.com/bcharleson/CleanLock/releases/download/v${VERSION}}"

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
  echo "==> Submitting DMG for notarization"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  spctl --assess --type execute -vv "$APP" || true
else
  echo "==> Skipping notarization (set NOTARY_PROFILE= to disable; default is notarytool-profile)"
fi

if [[ -x "$SIGN_UPDATE" ]]; then
  echo "==> Sparkle-signing DMG"
  # shellcheck disable=SC2034
  SPARKLE_OUT="$("$SIGN_UPDATE" "$DMG")"
  echo "$SPARKLE_OUT"
  ED_SIGNATURE="$(printf '%s\n' "$SPARKLE_OUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' | head -1)"
  LENGTH="$(printf '%s\n' "$SPARKLE_OUT" | sed -n 's/.*length="\([^"]*\)".*/\1/p' | head -1)"
  if [[ -z "$ED_SIGNATURE" || -z "$LENGTH" ]]; then
    # Newer sign_update may print "edSignature: …" / "length: …"
    ED_SIGNATURE="$(printf '%s\n' "$SPARKLE_OUT" | awk -F': ' '/edSignature/ {print $2; exit}')"
    LENGTH="$(printf '%s\n' "$SPARKLE_OUT" | awk -F': ' '/^length/ {print $2; exit}')"
  fi
  if [[ -n "$ED_SIGNATURE" && -n "$LENGTH" ]]; then
    PUB_DATE="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"
    DMG_NAME="$(basename "$DMG")"
    cat > "$APPCAST" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>CleanLock</title>
    <link>https://github.com/bcharleson/CleanLock</link>
    <description>CleanLock updates</description>
    <language>en</language>
    <item>
      <title>Version ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${BUILD}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure
        url="${DOWNLOAD_URL_PREFIX}/${DMG_NAME}"
        length="${LENGTH}"
        type="application/octet-stream"
        sparkle:edSignature="${ED_SIGNATURE}" />
    </item>
  </channel>
</rss>
EOF
    echo "==> Wrote $APPCAST"
  else
    echo "Warning: could not parse Sparkle signature output" >&2
  fi
else
  echo "==> Skipping Sparkle sign (missing $SIGN_UPDATE)"
fi

shasum -a 256 "$ZIP" "$DMG" | tee "$DIST/SHA256SUMS.txt"
echo "Artifacts in $DIST"
ls -lh "$DIST"
