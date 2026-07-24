# Releasing CleanLock

Same distribution model as **Grok**: Developer ID → notarize with keychain profile `notarytool-profile` → Sparkle appcast → GitHub Release.

## One-time setup (already done on Brandon’s Mac)

| Requirement | Value |
| --- | --- |
| Apple team | `CC989JZCNV` |
| Codesign identity | `Developer ID Application: Brandon Charleson (CC989JZCNV)` |
| Notary credentials | Keychain profile **`notarytool-profile`** (shared with Grok) |
| Sparkle EdDSA key | Keychain account `ed25519` (same public key as Grok) |
| Tools | Xcode, `xcodegen`, `scripts/bin/sign_update` |

If notarization ever fails with “No Keychain password item”:

```bash
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "CC989JZCNV"
# follow prompts (app-specific password or API key)
```

Confirm:

```bash
xcrun notarytool history --keychain-profile "notarytool-profile" | head
```

## Release checklist

### 1. Bump version

Update **both** places (keep them in sync):

1. [`project.yml`](../project.yml) — `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`
2. [`scripts/release.sh`](../scripts/release.sh) — `VERSION` and `BUILD` defaults

`BUILD` (`CFBundleVersion`) must increase every release Sparkle should offer. Marketing version can stay (e.g. `1.1.4`) only if build goes up; prefer bumping both.

### 2. Build, sign, notarize, Sparkle-sign

```bash
cd /path/to/CleanLock
./scripts/release.sh
# or: VERSION=1.1.5 BUILD=7 ./scripts/release.sh
```

This script:

1. Runs `xcodegen generate`
2. Builds Release with Developer ID + hardened runtime + timestamp
3. Creates `dist/CleanLock-<version>.zip` and `.dmg`
4. Notarizes the zip (`notarytool-profile`), staples the `.app`
5. Rebuilds the DMG, notarizes + staples the DMG
6. Runs `scripts/bin/sign_update` and writes [`appcast.xml`](../appcast.xml)

Artifacts:

- `dist/CleanLock-<version>.dmg` — primary download (Gatekeeper-clean)
- `dist/CleanLock-<version>.zip`
- `dist/SHA256SUMS.txt`
- `appcast.xml` — Sparkle feed (commit this)

### 3. Verify locally

```bash
spctl --assess --type execute -vv build-release/Build/Products/Release/CleanLock.app
# expect: accepted / Notarized Developer ID

xcrun stapler validate dist/CleanLock-<version>.dmg
# expect: The validate action worked!
```

### 4. Publish

```bash
# Commit version bump + appcast (and any code changes)
git add project.yml scripts/release.sh appcast.xml CleanLock/
git commit -m "Release v1.1.5"
git push origin main

# Attach binaries to GitHub (enclosure URL in appcast must match)
gh release create "v1.1.5" \
  dist/CleanLock-1.1.5.dmg \
  dist/CleanLock-1.1.5.zip \
  dist/SHA256SUMS.txt \
  --title "CleanLock 1.1.5" \
  --notes "Notarized Developer ID build."
```

Sparkle feed URL (in Info.plist):

`https://raw.githubusercontent.com/bcharleson/CleanLock/main/appcast.xml`

Enclosure URL pattern:

`https://github.com/bcharleson/CleanLock/releases/download/v<version>/CleanLock-<version>.dmg`

**Order matters:** push `appcast.xml` to `main` and publish the GitHub Release with that exact DMG filename before users will see the update.

### 5. Smoke-test updates (optional)

1. Install the **previous** build.
2. Confirm **CleanLock → Check for Updates…** offers the new version.
3. Install, relaunch, confirm version/build.

## Do not

- Use App Store / `Apple Distribution` for this pipeline (Direct / Developer ID only).
- Use GoatFit’s `AuthKey_*.p8` APNs / Sign in with Apple keys for notarization — wrong key type.
- Skip stapling; unsigned or unnotarized downloads hit Gatekeeper again.
- Reuse an old `BUILD` number in `appcast.xml` — Sparkle will ignore the update.

## Related

- Grok deploy script (reference): `Documents/DeveloperProjects/xAI Grok/GrokChat/scripts/deploy-release.sh`
- Install / usage: [README.md](../README.md)
