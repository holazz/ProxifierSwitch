#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Proxifier Switch.app"
DEST_DIR="$HOME/Applications"
BUILD_DIR="$PROJECT_DIR/.build"
XCODEGEN="${XCODEGEN:-$HOME/.local/bin/xcodegen}"

cd "$PROJECT_DIR"
if [[ -x "$XCODEGEN" ]]; then
  "$XCODEGEN" generate
elif [[ ! -d ProxifierSwitch.xcodeproj ]]; then
  echo "Missing ProxifierSwitch.xcodeproj and no executable xcodegen found at $XCODEGEN" >&2
  exit 1
fi

xcodebuild \
  -project ProxifierSwitch.xcodeproj \
  -scheme ProxifierSwitch \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}" \
  build

mkdir -p "$DEST_DIR"
rm -rf "$DEST_DIR/$APP_NAME"
cp -R "$BUILD_DIR/Build/Products/Release/$APP_NAME" "$DEST_DIR/"
open -gj -a "$DEST_DIR/$APP_NAME"
