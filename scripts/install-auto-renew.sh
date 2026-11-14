#!/bin/bash
# Installs (or removes with --uninstall) a macOS launch agent that runs renew-ios.sh
# every 3 hours (and at login). Each run does nothing unless the last successful renewal
# is at least 3 days old; then it tries, and keeps trying every 3 hours until the iPhone
# is reachable. So one moment with the Mac awake and the iPhone unlocked on the same
# Wi-Fi, any time within about 4 days, is enough.
set -euo pipefail
LABEL="com.scanandopen.renew"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "${1:-}" = "--uninstall" ]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"; echo "Auto-renew removed."; exit 0
fi

chmod +x "$REPO/scripts/renew-ios.sh"
mkdir -p "$HOME/Library/LaunchAgents"
cat >"$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$REPO/scripts/renew-ios.sh</string><string>--if-due</string></array>
  <key>StartInterval</key><integer>10800</integer>
  <key>RunAtLoad</key><true/>
</dict></plist>
PLIST
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Auto-renew installed: checks every 3 hours, renews when the last renewal is 3+ days old."
echo "Log: ~/Library/Logs/scan-and-open-renew.log"
echo "Renew right now: $REPO/scripts/renew-ios.sh"
