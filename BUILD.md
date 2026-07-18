# Build and Release

This repo now includes `scripts/build_dmg.sh` for local packaging.

By default it:

- builds `Latest.app` with `xcodebuild`
- uses `generic/platform=macOS` so the app bundle is universal on a normal Xcode setup
- writes `dist/Latest.app`
- writes `dist/Latest.dmg`
- writes checksum and manifest files in `dist/`

## Unsigned local build

```bash
scripts/build_dmg.sh
```

That produces an unsigned app and DMG, which is useful for local verification.

## Signed and notarized build

```bash
APP_SIGN_IDENTITY="Developer ID Application: Your Name (ABCDE12345)" \
NOTARY_PROFILE="LATEST_NOTARY" \
scripts/build_dmg.sh
```

`NOTARY_PROFILE` should be a keychain profile created with `xcrun notarytool store-credentials`.

The script keeps the app's existing target `Info.plist` from Xcode and only applies explicit
`--version` / `--build` overrides after the build, before signing.

## Version overrides

```bash
scripts/build_dmg.sh --version 0.11.1 --build 1308
```

You can also set the same values with environment variables:

```bash
APP_VERSION=0.11.1 APP_BUILD=1308 scripts/build_dmg.sh
```

## Debug signing and entitlements

The script defaults to the target entitlements file:

```text
Latest/Resources/Latest.entitlements
```

You can override that with:

```bash
scripts/build_dmg.sh --entitlements /path/to/custom.entitlements
```

To produce a debug-signed app bundle with `get-task-allow`:

```bash
APP_SIGN_IDENTITY="-" scripts/build_dmg.sh --app-only --allow-debugging
```

`--allow-debugging` adds `com.apple.security.get-task-allow=true` on top of the base entitlements.
It is blocked when notarization is enabled.

## Useful options

```bash
scripts/build_dmg.sh --help
```

- `--app-only` builds and optionally signs/notarizes only the app bundle
- `--version 0.11.1` overrides `CFBundleShortVersionString`
- `--build 1308` overrides `CFBundleVersion`
- `--entitlements path/to/file.entitlements` uses a custom entitlements plist when signing
- `--allow-debugging` adds the debug entitlement when signing
- `--skip-notarization` skips notarization even if `NOTARY_PROFILE` is set
- `--configuration Release` selects the Xcode configuration
- `--destination 'generic/platform=macOS'` overrides the xcodebuild destination
- `--open` opens the finished app or DMG

## Signing notes

- If `APP_SIGN_IDENTITY` is unset, the script leaves the app and DMG unsigned.
- If `APP_SIGN_IDENTITY="-"`, the app is ad-hoc signed, which is useful for local checks but not for public distribution.
- Notarization requires a real `Developer ID Application` identity and a `NOTARY_PROFILE`.
