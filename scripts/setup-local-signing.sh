#!/bin/bash
# Saves your personal signing settings in ios/Flutter/Local.xcconfig, which Git ignores.
# Because the tracked project files stay untouched, `git pull` and the automatic update
# in renew-ios.sh work without conflicts.
#
# Usage: ./scripts/setup-local-signing.sh <TEAM_ID> [BUNDLE_ID]
#   e.g. ./scripts/setup-local-signing.sh C579R8WY72 com.admin.scanandopen2026
set -euo pipefail
TEAM="${1:-}"; BUNDLE="${2:-app.scanandopen}"
if [ -z "$TEAM" ]; then echo "Usage: $0 <TEAM_ID> [BUNDLE_ID]"; exit 1; fi
if ! [[ "$TEAM" =~ ^[A-Z0-9]{10}$ ]]; then echo "TEAM_ID should be 10 letters/digits (for example C579R8WY72)."; exit 1; fi
if ! [[ "$BUNDLE" =~ ^[A-Za-z0-9.-]+$ ]]; then echo "BUNDLE_ID may only contain letters, digits, dots and hyphens."; exit 1; fi
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cat >"$REPO/ios/Flutter/Local.xcconfig" <<CFG
DEVELOPMENT_TEAM = $TEAM
APP_BUNDLE_ID = $BUNDLE
CFG
echo "Saved ios/Flutter/Local.xcconfig (team $TEAM, bundle ID $BUNDLE)."
