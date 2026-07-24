# Releasing CleanLock

Pipeline: **Developer ID codesign → Apple notarization → Sparkle appcast → GitHub Release**.

## One-time setup (maintainer machine)

| Requirement | Notes |
| --- | --- |
| Apple Developer Program membership | Individual or organization |
| Developer ID Application certificate | Installed in login keychain |
| Notary credentials | Keychain profile used by `notarytool` (see below) |
| Sparkle EdDSA key | Keychain account **`cleanlock`** (private key never leaves the keychain) |
| Tools | Xcode, [`xcodegen`](https://github.com/yonaskolb/XcodeGen), `scripts/bin/sign_update` |

### Store notarization credentials

```bash
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID"
# follow prompts (app-specific password, or use --key / --key-id / --issuer for an API key)
```

Confirm:

```bash
xcrun notarytool history --keychain-profile "notarytool-profile" | head
```

Override profile / identity when releasing:

```bash
NOTARY_PROFILE=notarytool-profile \
TEAM_ID=XXXXXXXXXX \
SIGN_IDENTITY="Developer ID Application: Your Name (XXXXXXXXXX)" \
./scripts/release.sh
```

### Sparkle signing key

Private key lives only in the macOS Keychain (`account: cleanlock`).  
**Never commit** private keys, `.p8` files, app-specific passwords, or notary API keys.

Public key is embedded in the app as `SUPublicEDKey` (safe to ship; required for clients to verify updates).

```bash
# Print existing public key
./scripts/bin/generate_keys --account cleanlock -p   # if you have generate_keys from Sparkle

# Sign a DMG (release.sh does this)
./scripts/bin/sign_update --account cleanlock dist/CleanLock-x.y.z.dmg
```

## Release checklist

### 1. Bump version

Keep these in sync:

1. [`project.yml`](../project.yml) — `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`
2. [`scripts/release.sh`](../scripts/release.sh) — `VERSION`, `BUILD` defaults

`BUILD` (`CFBundleVersion`) must increase every time Sparkle should offer an update.

### 2. Build, sign, notarize, Sparkle-sign

```bash
./scripts/release.sh
# or: VERSION=1.1.5 BUILD=7 ./scripts/release.sh
```

Produces:

- `dist/CleanLock-<version>.dmg` / `.zip` (notarized)
- `dist/SHA256SUMS.txt`
- `appcast.xml` (commit this)

### 3. Verify

```bash
spctl --assess --type execute -vv build-release/Build/Products/Release/CleanLock.app
# expect: accepted / Notarized Developer ID

xcrun stapler validate dist/CleanLock-<version>.dmg
```

### 4. Publish

```bash
git add project.yml scripts/release.sh appcast.xml CleanLock/
git commit -m "Release vX.Y.Z"
git push origin main

gh release create "vX.Y.Z" \
  dist/CleanLock-X.Y.Z.dmg \
  dist/CleanLock-X.Y.Z.zip \
  dist/SHA256SUMS.txt \
  --title "CleanLock X.Y.Z" \
  --notes "Notarized Developer ID build."
```

Sparkle feed (Info.plist):

`https://raw.githubusercontent.com/bcharleson/CleanLock/main/appcast.xml`

Enclosure URLs must match the GitHub Release asset names exactly.

### 5. Smoke-test updates (optional)

Install the previous build → **CleanLock → Check for Updates…** → confirm the new version installs.

## Secrets policy (open source)

| Item | In git? |
| --- | --- |
| Source, MIT license, public Sparkle key, appcast signatures | Yes |
| Apple ID / app-specific password | **No** |
| App Store Connect API `.p8` / issuer / key id | **No** |
| Sparkle **private** EdDSA key | **No** (Keychain only) |
| Notary keychain profile contents | **No** (Keychain only) |

Team ID and codesign identity strings in `project.yml` / `release.sh` defaults are the maintainer’s public Apple team identifiers (also visible on signed binaries). Forks should override via env vars.

## Do not

- Commit `.p8`, `.pem`, or Sparkle private key files
- Skip notarization/stapling for public downloads
- Reuse an old `BUILD` in `appcast.xml`
