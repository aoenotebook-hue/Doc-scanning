#!/bin/bash
# Installs (or removes with --uninstall) a macOS launch agent that runs renew-ios.sh
# every Sunday and Thursday at 12:00. The Mac must be awake, logged in, and the iPhone
# reachable; if it isn't, the next run tries again and the app keeps working until its
# 7 days are up.
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
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$REPO/scripts/renew-ios.sh</string></array>
  <key>StartCalendarInterval</key><array>
    <dict><key>Weekday</key><integer>0</integer><key>Hour</key><integer>12</integer><key>Minute</key><integer>0</integer></dict>
    <dict><key>Weekday</key><integer>4</integer><key>Hour</key><integer>12</integer><key>Minute</key><integer>0</integer></dict>
  </array>
</dict></plist>
PLIST
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Auto-renew installed: every Sunday and Thursday at 12:00."
echo "Log: ~/Library/Logs/scan-and-open-renew.log"
echo "Test now: launchctl kickstart -k gui/$(id -u)/$LABEL"
