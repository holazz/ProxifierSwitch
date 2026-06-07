#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
XCODEGEN="${XCODEGEN:-$HOME/.local/bin/xcodegen}"

cd "$ROOT_DIR"
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
  -derivedDataPath "$ROOT_DIR/.build" \
  CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}" \
  build
