#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is required. Install the current stable SDK and add it to PATH." >&2
  exit 127
fi

# The initial repository intentionally keeps native integration files under source
# control. This fills in SDK-version-specific wrapper/workspace files when absent.
flutter create --platforms=android,ios --org app.scanandopen --project-name scan_and_open .

test -f android/app/src/main/kotlin/app/scanandopen/MainActivity.kt
test -f ios/Runner/AppDelegate.swift
test -f ios/ShareExtension/ShareViewController.swift

flutter pub get
dart format lib test
flutter gen-l10n
flutter analyze --fatal-infos --fatal-warnings
flutter test
flutter build apk --release

echo "Verified Android artifact: build/app/outputs/flutter-apk/app-release.apk"
echo "Run the documented signed Xcode Share Extension build on macOS for iOS."
