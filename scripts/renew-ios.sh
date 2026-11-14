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
# --if-due (used by the scheduler, which runs every few hours): do nothing unless the last
# successful renewal is at least RENEW_EVERY_DAYS old. A run that could not reach the
# iPhone leaves no stamp, so the next scheduled run tries again a few hours later.
STAMP="$HOME/Library/Application Support/ScanAndOpen/last-renewal"
MODE="${1:-}"
days_since_renewal() {
  [ -f "$STAMP" ] || { echo 999; return; }
  echo $(( ( $(date +%s) - $(cat "$STAMP") ) / 86400 ))
}
if [ "$MODE" = "--if-due" ] && [ "$(days_since_renewal)" -lt "${RENEW_EVERY_DAYS:-3}" ]; then
  exit 0
fi
echo; echo "=== $(date '+%Y-%m-%d %H:%M:%S') renew start (last renewal: $(days_since_renewal) day(s) ago) ==="

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
  local json; json="$(mktemp "${TMPDIR:-/tmp}/scan-and-open-devices.XXXXXX")"
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
  MSG="iPhone not reachable. Unlock it and put it on the same Wi-Fi as this Mac (or connect the cable), then run scripts/renew-ios.sh."
  # Scheduled runs retry every few hours, so only interrupt the user once time is running out.
  if [ "$MODE" = "--if-due" ] && [ "$(days_since_renewal)" -lt 5 ]; then echo "$MSG (will retry at the next scheduled run)"; else notify "$MSG"; fi
  exit 0   # not an error: the next scheduled run tries again
fi
echo "Device: $DEVICE_ID"

# --check only reports whether the iPhone can be reached (use it to test wireless).
if [ "$MODE" = "--check" ]; then
  notify "iPhone reachable: $DEVICE_ID. Renewal should work without the cable."
  xcrun devicectl list devices 2>&1 | head -10
  exit 0
fi

# --- Auto-update ----------------------------------------------------------------
# Pull the newest code from main when the checkout is clean (your personal signing
# settings live in the untracked ios/Flutter/Local.xcconfig, so they never block this).
# If the new code fails to build, go back to the previous version so renewal still works.
OLD="$(git rev-parse HEAD)"
if [ -n "$(git status --porcelain)" ]; then
  echo "Local changes present: not updating the code (see docs/USER_GUIDE.md, 'Automatic updates')."
elif [ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then
  echo "Not on main: not updating the code."
elif git fetch -q origin 2>/dev/null; then
  BAD_FILE="$(git rev-parse --git-dir)/scan-and-open-bad-version"
  if [ -f "$BAD_FILE" ] && [ "$(cat "$BAD_FILE")" = "$(git rev-parse origin/main)" ]; then
    echo "Skipping $(git rev-parse --short origin/main): it failed to build last time. Waiting for a newer version."
  else
    git merge -q --ff-only origin/main 2>/dev/null || echo "Could not fast-forward to origin/main."
    [ "$(git rev-parse HEAD)" != "$OLD" ] && echo "Updated code: ${OLD:0:7} -> $(git rev-parse --short HEAD)"
  fi
else
  echo "Could not reach GitHub; using the current code."
fi

BUILD_OUT="$(mktemp "${TMPDIR:-/tmp}/scan-and-open-build.XXXXXX")"
build_app() { { flutter pub get && flutter build ios --release; } 2>&1 | tee "$BUILD_OUT"; return "${PIPESTATUS[0]}"; }
# A signing failure is about this Mac's Apple ID, not about the code: say so plainly and
# never treat it as a bad app version.
signing_problem() { grep -qE "No Accounts|No profiles for|could not code sign|No signing certificate|Provisioning profile" "$BUILD_OUT"; }
SIGN_MSG="Xcode is not signed in to your Apple ID. Open Xcode > Settings > Accounts, add your Apple ID, then run scripts/renew-ios.sh"
if ! build_app; then
  if signing_problem; then
    [ "$(git rev-parse HEAD)" != "$OLD" ] && git reset -q --hard "$OLD"
    rm -f "$BUILD_OUT"; fail "$SIGN_MSG"
  elif [ "$(git rev-parse HEAD)" != "$OLD" ]; then
    echo "The new version failed to build; returning to ${OLD:0:7} so the renewal still works."
    git rev-parse HEAD > "$(git rev-parse --git-dir)/scan-and-open-bad-version"   # don't retry this version
    git reset -q --hard "$OLD"
    build_app || fail "build of the previous version (see log)"
    notify "New app version failed to build; renewed the previous version instead (see log)."
  else
    rm -f "$BUILD_OUT"; fail "build (see log)"
  fi
fi
rm -f "$BUILD_OUT"
APP="$REPO/build/ios/iphoneos/Runner.app"
[ -d "$APP" ] || fail "built app not found"

# The first wireless attempt can fail while the connection wakes up, so retry.
installed=0
for attempt in 1 2 3; do
  if xcrun devicectl device install app --device "$DEVICE_ID" "$APP"; then installed=1; break; fi
  echo "Install attempt $attempt failed; retrying in 15 s."; sleep 15
done
[ "$installed" = 1 ] || fail "install on iPhone (keep it unlocked and on the same Wi-Fi)"
mkdir -p "$(dirname "$STAMP")" && date +%s > "$STAMP"
notify "Scan & Open renewed for another 7 days."
