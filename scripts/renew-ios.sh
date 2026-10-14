#!/bin/bash
# Rebuilds Scan & Open and reinstalls it on your iPhone, which restarts the 7-day
# limit of a free Apple ID. Run by hand, or automatically via install-auto-renew.sh.
# Documents are kept: the app is installed over itself with the same bundle ID.
#
# Optional: DEVICE="<name or id from 'flutter devices'>" ./scripts/renew-ios.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$HOME/Library/Logs/scan-and-open-renew.log"
mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1
echo; echo "=== $(date '+%Y-%m-%d %H:%M:%S') renew start ==="

notify() { osascript -e "display notification \"$1\" with title \"Scan & Open\"" >/dev/null 2>&1 || true; echo "$1"; }
fail()   { notify "Renewal failed: $1 (see $LOG)"; exit 1; }

export PATH="$HOME/flutter/bin:$HOME/development/flutter/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
command -v flutter >/dev/null || fail "flutter not found"
cd "$REPO" || fail "repo not found"

# Find the iPhone: the DEVICE override, otherwise the first physical iOS device.
DEVICE_ID="$(flutter devices --machine 2>/dev/null | /usr/bin/python3 -c '
import json, os, sys
want = os.environ.get("DEVICE", "").lower()
try: devices = json.load(sys.stdin)
except Exception: devices = []
for d in devices:
    if d.get("targetPlatform") != "ios" or d.get("emulator"): continue
    if want and want not in (d.get("name", "").lower(), d.get("id", "").lower()): continue
    print(d["id"]); break
')"
if [ -z "$DEVICE_ID" ]; then
  notify "iPhone not reachable. Unlock it and connect it (cable or same Wi-Fi), then run scripts/renew-ios.sh."
  exit 0   # not an error: the next scheduled run tries again
fi
echo "Device: $DEVICE_ID"

# Keep the code current when the checkout is clean; never overwrite local edits.
if [ -z "$(git status --porcelain)" ] && git fetch -q origin 2>/dev/null; then
  git merge -q --ff-only origin/main 2>/dev/null || echo "Not fast-forwarding (not on main); using the current checkout."
fi

flutter pub get                    || fail "flutter pub get"
flutter build ios --release        || fail "build (open ios/Runner.xcworkspace once and check Signing & Capabilities)"
APP="$REPO/build/ios/iphoneos/Runner.app"
[ -d "$APP" ] || fail "built app not found"

xcrun devicectl device install app --device "$DEVICE_ID" "$APP" || fail "install on iPhone"
notify "Scan & Open renewed for another 7 days."
