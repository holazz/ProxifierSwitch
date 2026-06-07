#!/bin/zsh
set -euo pipefail

osascript -e 'tell application id "com.local.ProxifierSwitch" to quit' >/dev/null 2>&1 || true
rm -rf "$HOME/Applications/Proxifier Switch.app"
