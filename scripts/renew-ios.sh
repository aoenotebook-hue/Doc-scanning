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

# --- Finding the iPhone -------------------------------------------------------
# A wireless iPhone is often asleep and needs a moment to answer, so look several times.
# Two lookups: `flutter devices` first, then CoreDevice (`devicectl`), which also lists
# wireless devices that Flutter sometimes misses.
TRIES="${RENEW_TRIES:-6}"; WAIT="${RENEW_WAIT:-20}"

find_with_flutter() {
  flutter devices --machine 2>/dev/null | /usr/bin/python3 -c '
import json, os, sys
want = os.environ.get("DEVICE", "").lower()
try: devices = json.load(sys.stdin)
except Exception: devices = []
for d in devices:
    if d.get("targetPlatform") != "ios" or d.get("emulator"): continue
    if want and want not in (d.get("name", "").lower(), d.get("id", "").lower()): continue
    print(d["id"]); break
'
}

find_with_devicectl() {
  local json; json="$(mktemp -t scan-and-open-devices)"
  xcrun devicectl list devices --json-output "$json" >/dev/null 2>&1 || { rm -f "$json"; return; }
  /usr/bin/python3 - "$json" <<'PY'
import json, os, sys
want = os.environ.get("DEVICE", "").lower()
try: devices = json.load(open(sys.argv[1])).get("result", {}).get("devices", [])
except Exception: devices = []
for d in devices:
    hw, dev, conn = d.get("hardwareProperties", {}), d.get("deviceProperties", {}), d.get("connectionProperties", {})
    if hw.get("platform") not in ("iOS", None) or hw.get("deviceType") not in ("iPhone", None): continue
    if conn.get("tunnelState") == "unavailable": continue
    name = dev.get("name", "").lower()
    ids = [x for x in (hw.get("udid"), d.get("identifier")) if x]
    if want and want != name and want not in [i.lower() for i in ids]: continue
    if ids: print(ids[0]); break
PY
  rm -f "$json"
}

find_device() { local id; id="$(find_with_flutter)"; [ -n "$id" ] || id="$(find_with_devicectl)"; echo "$id"; }

DEVICE_ID=""
for attempt in $(seq 1 "$TRIES"); do
  DEVICE_ID="$(find_device)"
  [ -n "$DEVICE_ID" ] && break
  echo "iPhone not found (attempt $attempt of $TRIES)."
  [ "$attempt" -lt "$TRIES" ] && sleep "$WAIT"
done

if [ -z "$DEVICE_ID" ]; then
  echo "--- diagnostics ---"; xcrun devicectl list devices 2>&1 | head -20; flutter devices 2>&1 | head -20
  notify "iPhone not reachable. Unlock it and put it on the same Wi-Fi as this Mac (or connect the cable), then run scripts/renew-ios.sh."
  exit 0   # not an error: the next scheduled run tries again
fi
echo "Device: $DEVICE_ID"

# --check only reports whether the iPhone can be reached (use it to test wireless).
if [ "${1:-}" = "--check" ]; then
  notify "iPhone reachable: $DEVICE_ID. Renewal should work without the cable."
  xcrun devicectl list devices 2>&1 | head -10
  exit 0
fi

# Keep the code current when the checkout is clean; never overwrite local edits.
if [ -z "$(git status --porcelain)" ] && git fetch -q origin 2>/dev/null; then
  git merge -q --ff-only origin/main 2>/dev/null || echo "Not fast-forwarding (not on main); using the current checkout."
fi

flutter pub get                    || fail "flutter pub get"
flutter build ios --release        || fail "build (open ios/Runner.xcworkspace once and check Signing & Capabilities)"
APP="$REPO/build/ios/iphoneos/Runner.app"
[ -d "$APP" ] || fail "built app not found"

# The first wireless attempt can fail while the connection wakes up, so retry.
installed=0
for attempt in 1 2 3; do
  if xcrun devicectl device install app --device "$DEVICE_ID" "$APP"; then installed=1; break; fi
  echo "Install attempt $attempt failed; retrying in 15 s."; sleep 15
done
[ "$installed" = 1 ] || fail "install on iPhone (keep it unlocked and on the same Wi-Fi)"
notify "Scan & Open renewed for another 7 days."
