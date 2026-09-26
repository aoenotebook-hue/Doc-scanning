# Scan & Open

Scan & Open is a Flutter application for iPhone and Android. Document images, drafts,
exports, and QR decoding stay on-device. It has no account, backend, advertising, or
content analytics.

**How to install and use the app: see [docs/USER_GUIDE.md](docs/USER_GUIDE.md).**

## Architecture

* `lib/screens` contains accessible Material 3 screens and orchestration only.
* `lib/core` contains immutable draft/export models, crash-recoverable private storage,
  URI allowlisting, sequential export, and the narrow native bridge.
* Full-resolution originals are copied into a private per-draft directory. Edits are
  non-destructive metadata. Export decodes one page at a time in an isolate, bakes EXIF
  orientation, and applies edits; only the encoded page returns to the UI isolate. A PDF
  holds each encoded page until the file is written, so peak memory grows with page count.
* Android uses ML Kit's on-device document scanner and Storage Access Framework. iOS
  uses VisionKit and `UIDocumentPickerViewController`. Flutter provides still/live QR
  recognition through ML Kit/Apple Vision via `mobile_scanner`.
* Android SEND/SEND_MULTIPLE intents and an iOS Share Extension transfer incoming images
  to private app/App Group storage. A screenshot is simply an existing selected/shared image;
  the app never monitors the screen.

## Setup and run

Prerequisites: Flutter 3.41+ (stable), Android Studio with Android SDK 35, and,
for iOS, current Xcode and CocoaPods on macOS.

```sh
flutter pub get
flutter test
flutter run
```

The repository includes the Android and iOS projects. If platform scaffolding must be
regenerated after a Flutter upgrade, run `flutter create --platforms=android,ios .`, keep
the application IDs, then reapply/retain the checked-in manifest, Gradle, entitlements,
AppDelegate, and Share Extension target files.

### Android

The manifest requests camera access and advertises image SEND/SEND_MULTIPLE handlers.
No broad media/storage permission is requested: system pickers provide scoped access.
`ACTION_CREATE_DOCUMENT` provides a genuine destination chooser and reports cancellation
without deleting the draft. Build with `flutter build appbundle`.

### iOS signing and Share Extension

1. Open `ios/Runner.xcworkspace` in Xcode and select a development team for Runner.
2. Add a **Share Extension** target named `ShareExtension`; use the checked-in
   `ios/ShareExtension` source and plist and embed it in Runner.
3. Enable App Groups for both targets, create `group.app.scanandopen.shared`, and select
   the checked-in entitlements files. The group identifier must match all three Swift files.
4. Assign a unique bundle ID to Runner and a child bundle ID to the extension, install on
   a signed device, and build with `flutter build ipa` when distribution signing is ready.

Camera and photo permission strings are purpose-specific. VisionKit supplies automatic
edge detection, perspective correction, manual corner adjustment, retake, and a manual
capture fallback. The OS export picker exposes whichever local/cloud providers the user
has installed and configured; no provider is promised.

## Export behavior

PDF uses pages in editor order and fits without stretching. JPG and PNG multipage exports
are explicit ZIP archives named `page_001`, `page_002`, etc., so no page is silently lost.
The UI separates page size, output dimensions, PDF DPI, and meaningful JPEG compression.
PNG has no fake quality control. Size shown before generation is explicitly estimated;
the success message shows actual bytes after generation and destination confirmation.
Temporary generated exports older than one day are cleaned on the next export.

## Privacy and backup

Drafts and originals live in application documents storage. QR history is off (nothing is
stored). Temporary export/share files are cache data. Saved files belong to the user-chosen
provider. The app does **not** configure blanket backup exclusion: iOS/Android may back up
private application documents according to OS, device, and user backup settings.

## Verification report

Automated pure-Dart tests cover document serialization/order, non-mutating state, defaults,
and rejection of executable/arbitrary URI schemes. This container has no Flutter/Dart SDK,
Android SDK, Xcode, simulator, or physical devices, so builds and hardware integrations
could not be executed here.

The following require physical-device validation before release:

* three-page VisionKit/ML Kit capture, corner editing, manual fallback, retake, and denial;
* EXIF-rotated imports and 150/200/300 DPI visual/metadata inspection;
* save, cancellation, insufficient-storage/provider failure, reopen, and share sheets;
* live QR deduplication, tiny-code crop/retry, multi-code detection, rotations, and no-code;
* Android single/multiple incoming shares and signed iOS Share Extension activation;
* supported website, mail, and telephone routing with and without handler apps;
* large-document memory profiling, interruption/relaunch recovery, and offline operation;
* VoiceOver/TalkBack, Dynamic Type/font scaling, Thai copy, light/dark themes.

Use `docs/device-test-checklist.md` to record device, OS, expected result, actual result,
and evidence. Do not treat generation of a temporary file as successful saving.

## Known first-release limitations / next steps

* Manual crop/retry for imported QR images currently relies on cropping in the system photo
  editor before reselecting; add an in-app crop overlay before production acceptance.
* Editor filtering is previewed on export rather than destructively changing originals.
  Add a processed-preview cache to make filter previews immediate on low-memory devices.
* iOS project/workspace and dependency lockfiles must be generated on a macOS Flutter host,
  then the Share Extension target must be added/signed as described above.
* OCR, searchable PDF, accounts, subscriptions, and cloud synchronization are intentionally
  out of scope.

## Dependencies

Dependencies are pinned to compatible release ranges in `pubspec.yaml`. Candidate package
metadata lookup against the official pub.dev API was attempted on 2026-09-26 but this build
environment's outbound proxy returned HTTP 403. Before release, rerun `flutter pub outdated`,
review each package's pub.dev platform matrix and linked LICENSE, run `flutter pub get` to
commit `pubspec.lock`, and retain license notices. The chosen packages are replaceable behind
core/service boundaries; the native scanning/save/share bridges do not depend on a paid API.
