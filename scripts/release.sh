#!/bin/zsh
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: scripts/release.sh <version>"
  echo "Example: scripts/release.sh 1.0.0"
  exit 1
fi

VERSION="${1#v}"
TAG="v$VERSION"
INFO_PLIST="ProxifierSwitch/Info.plist"

if [[ ! "$VERSION" =~ '^[0-9]+(\.[0-9]+){0,2}$' ]]; then
  echo "Invalid version: $1"
  echo "Use a numeric version like 1.0.0"
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree is not clean. Commit or stash changes before releasing."
  exit 1
fi

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "Tag already exists: $TAG"
  exit 1
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$INFO_PLIST"

git add "$INFO_PLIST"
git commit -m "chore: release $TAG"
git tag -a "$TAG" -m "Release $TAG"
git push origin HEAD
git push origin "$TAG"
