# Proxifier Switch

Proxifier Switch is a macOS menu bar app that opens Proxifier when the current Wi-Fi matches the configured target Wi-Fi and closes Proxifier otherwise.

## Defaults

- App name: `Proxifier Switch`
- Bundle ID: `com.local.ProxifierSwitch`
- Target Wi-Fi: none by default; configure it in the app settings
- Proxifier path: `/Applications/Proxifier.app`

## Build

```bash
scripts/build.sh
```

For local Debug builds without installing XcodeGen:

```bash
xcodebuild \
  -project ProxifierSwitch.xcodeproj \
  -scheme ProxifierSwitch \
  -configuration Debug \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath .build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

`project.yml` is kept as the project source definition. If a compatible XcodeGen binary is available at `$HOME/.local/bin/xcodegen` or `XCODEGEN=/path/to/xcodegen`, the scripts regenerate `ProxifierSwitch.xcodeproj`; otherwise they use the checked-in/generated project directly.

## Install Locally

```bash
scripts/install.sh
```

The install script builds a Release app with ad-hoc signing by default, which does not require a paid Apple Developer account and is closer to the GitHub Release artifact.

## Release

Create a version commit, tag it, and push the tag:

```bash
scripts/release.sh 1.0.0
```

Pushing a `v*` tag triggers the GitHub Actions release workflow, which builds an ad-hoc signed, non-notarized DMG and uploads it to the GitHub Release.
