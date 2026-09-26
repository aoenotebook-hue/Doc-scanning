# Scan & Open

A Flutter app for iPhone and Android that:

1. scans paper documents (or imports images), edits the pages, and exports them as PDF, JPG or PNG to a location you choose;
2. reads QR codes from the camera, photos, files, screenshots or images shared from other apps, and opens supported destinations after you review them.

Everything runs on the device. There is no account, backend, paid service, upload or content analytics.

**How to install and use the app:** see [docs/USER_GUIDE.md](docs/USER_GUIDE.md).

## Architecture

```
lib/
  main.dart                 app shell, themes, locale
  app_strings.dart          inline English/Thai strings (device language by default, manual override)
  core/                     no widgets: testable logic
    models.dart             DocumentDraft / DocumentPage / CropQuad / ExportOptions
    draft_store.dart        private per-draft folders: draft.json + untouched originals
    image_pipeline.dart     EXIF → rotation → 4-corner perspective crop → downscale → filter
    preview_cache.dart      screen-sized renders from the same pipeline, made in an isolate
    export_service.dart     sequential PDF / JPG / PNG / ZIP generation in isolates
    qr_decoder.dart         on-device QR decode with processed/rotated retries and crop
    link_policy.dart        allowlist: http(s), mailto, tel — everything else is text only
    platform_bridge.dart    method channel to the native code below
    settings.dart           language, theme, default export options
  screens/                  UI only: home, editor, crop, export, QR input/result, settings
android/app/src/main/kotlin/.../MainActivity.kt   ML Kit scanner, SAF Save As, share intents
ios/Runner/AppDelegate.swift                      VisionKit scanner, Files export, share inbox
ios/ShareExtension/                               Share Extension (images → App Group inbox)
```

* **Non-destructive editing.** Originals are copied into private storage and never modified. Rotation, crop corners and colour mode are stored in `draft.json` and applied when previewing or exporting, so any edit can be undone. Originals are deleted only when their page or document is deleted.
* **Drafts survive crashes.** Every edit rewrites `draft.json` (flushed) immediately.
* **Memory.** Each page is decoded, edited and encoded inside its own `Isolate.run`, one page at a time; only the encoded bytes return. Pages are downscaled before filtering. A PDF keeps each *encoded* page until the file is written, so peak memory grows with page count but never holds several decoded full-resolution pages.
* **Previews match exports.** The editor shows a render from the same pipeline (cached by edit state), not an approximation.
* **Scanning.** Android uses the ML Kit document scanner (edge detection, auto crop and perspective correction, manual corner adjustment, retake, manual shutter). iOS uses VisionKit's `VNDocumentCameraViewController` (the same features). If the native scanner is unavailable, the app offers a plain camera photo followed by the in-app corner editor, or import.
* **Saving.** Android `ACTION_CREATE_DOCUMENT` (Storage Access Framework); iOS `UIDocumentPickerViewController(forExporting:)`. The app reports "Saved" only after the destination confirms the write; cancel is not an error. Available providers (Drive, iCloud, etc.) depend on the device.
* **QR.** `mobile_scanner` (ML Kit on Android, Apple Vision on iOS) for live and still images. Still images are retried with an upscaled/contrast-normalised variant and three rotations before showing "No QR code found", which offers crop-and-retry. Nothing opens without a tap.

## Setup

Prerequisites: Flutter 3.41+ stable; Android Studio / Android SDK with Java 17; for iOS, a Mac with Xcode and CocoaPods.

```sh
flutter pub get
flutter analyze
flutter test
flutter run            # on a connected device
```

### Android

* Build an installable APK: `flutter build apk --release` (signed with the debug key so it can be sideloaded). For Google Play, create an upload key and replace `signingConfig` in `android/app/build.gradle.kts`, then `flutter build appbundle`.
* CI (`.github/workflows/ci.yml`) runs analyze, tests and the release APK build on every push and uploads it as the **scan-and-open-apk** artifact.
* **Permissions:** only `CAMERA` (requested when the QR camera or photo fallback opens). No storage or media permission: the system pickers and SAF grant per-file access. The ML Kit scanner runs in Google Play services and needs no app permission.
* **Incoming sharing:** `MainActivity` handles `SEND` / `SEND_MULTIPLE` for `image/*`; shared files are copied to the app cache before use, then moved into the document folder or deleted.
* **Backup:** `allowBackup="false"` and `data_extraction_rules.xml` exclude app data from Android backup and device transfer.

### iOS signing and Share Extension

The Runner project is checked in. The Share Extension target must be added once in Xcode because it needs your signing team:

1. `flutter pub get`, then open `ios/Runner.xcworkspace`.
2. Runner target → **Signing & Capabilities** → choose your Team. Keep or change the bundle ID `app.scanandopen`.
3. Add **App Groups** to Runner and create `group.app.scanandopen.shared` (Runner already points at `Runner/Runner.entitlements`, which contains it).
4. **File → New → Target → Share Extension**, name it `ShareExtension`, language Swift. Delete the generated Swift/storyboard/Info.plist and add the checked-in `ios/ShareExtension/ShareViewController.swift` and `Info.plist` instead; set the target's *Info.plist File* to `ShareExtension/Info.plist` and *Code Signing Entitlements* to `ShareExtension/ShareExtension.entitlements`.
5. Give the extension the bundle ID `app.scanandopen.ShareExtension`, the same Team, and the same App Group. Set its deployment target to match Runner.
6. Check that Runner → Build Phases → **Embed Foundation Extensions** contains `ShareExtension.appex`.
7. Run on a device. In Photos, share an image → **Open in Scan & Open**, then open the app: it asks whether to make a document or read a QR code.

If you change the App Group ID, update it in both entitlements files, `AppDelegate.swift` and `ShareViewController.swift`.

**iOS permissions** (`Info.plist`): `NSCameraUsageDescription` (QR camera, photo fallback) and `NSPhotoLibraryUsageDescription`. Photo picking uses the system picker. **Backup:** app documents may be included in iCloud/computer backups according to the user's settings; no exclusion is configured.

## Local data and privacy

| Data | Where | Removed when |
| --- | --- | --- |
| Drafts (`draft.json`) and original images | App documents folder, one folder per document | The document is deleted (home 🗑 or Settings → Delete all documents) |
| Page previews, generated exports, incoming shares, QR work files | App temporary/cache folder | Exports older than 1 day on next export; all via Settings → Clear temporary files; OS cache eviction |
| Settings (language, theme, export defaults) | Shared preferences | App uninstall |
| QR results | Not stored | — |

The app never logs document images, decoded QR content or URLs.

## Dependencies

All are maintained, published on pub.dev with Android and iOS support, and locked in `pubspec.lock`.

| Package | Locked | License | Use |
| --- | --- | --- | --- |
| archive | 4.3.0 | MIT | ZIP for multi-page image exports |
| file_picker | 10.3.10 | MIT | System file picker |
| image | 4.10.1 | MIT | Decode, EXIF, rotate, perspective crop, filters, encode |
| image_picker | 1.2.3 | BSD-3 | Photo picker, plain camera fallback |
| mobile_scanner | 7.4.2 | BSD-3 | Live and still QR decoding (ML Kit / Apple Vision) |
| path_provider | 2.1.6 | BSD-3 | App folders |
| pdf | 3.13.1 | Apache-2.0 | PDF generation |
| share_plus | 12.0.2 | BSD-3 | System share sheet |
| shared_preferences | 2.5.5 | BSD-3 | Settings |
| url_launcher | 6.3.2 | BSD-3 | Opening allowlisted links |
| uuid | 4.6.0 | MIT | IDs |
| ML Kit document scanner (Android, Gradle) | 16.0.0-beta1 | Google APIs ToS | Native scanning |

`file_picker` 13 and `share_plus` 13 are available (major versions); they were not adopted here because their API changes would need device re-testing.

## Verification report

### Verified here (automated, `flutter test` — 47 tests; `flutter analyze` clean; CI builds the release APK)

* **Page order:** a 3-page document reordered to 3,1,2 exports a PDF with 3 pages in that order.
* **Orientation:** an EXIF-rotated (orientation 6) image exports upright; user rotation turns the page and the crop follows it.
* **Perspective crop:** a skewed quad is rectified to its edge lengths; four rotations return the crop to the start.
* **Every page kept:** multi-page JPG and PNG exports contain `page_001…page_003` with the correct images; a single page exports as one image.
* **Settings affect output:** Small vs High changes pixel width (never upscales past the source); JPEG 45 vs 95 changes file size; 150 vs 300 DPI changes PDF raster height (1754 vs 3507 px for A4).
* **Filters:** black & white contains only pure black and white; originals are byte-identical after export.
* **Failures:** empty selection and unreadable images fail with a specific reason; expired temporary exports are removed and fresh ones kept.
* **QR logic:** duplicates removed; retries fall back to processed/rotated variants and clean up; platform failures give "no code"; crop-and-retry decodes the region.
* **Link policy:** `javascript:`, `data:`, `file:`, `intent:`, custom schemes, malformed mail/phone, and user-info URLs are never opened; phone numbers with spaces are normalised.
* **Screens:** plain text and executable schemes never show Open; web links show the hostname and the HTTPS caution; multiple codes appear in a selectable list; Thai text follows the locale; export defaults to PDF/A4/200 DPI with the document name, sections are separated, PNG has no quality slider, deselecting pages blocks export, and one page gives a single `.jpg`.
* **Drafts:** save/restore keeps order, rotation, filter and crop; older drafts without crop still load; default name `Scan_2026-09-26_1005`.

### Not verified — needs physical devices

No emulator, simulator or phone was available, so none of these have been run:

* Native scanning on both platforms: 3-page capture, edge detection, corner adjustment, retake, manual shutter; the plain-photo fallback.
* Save As to a chosen destination and reopening the file; cancel; full storage; revoked provider.
* Share sheet on both platforms.
* Live QR: camera permission denial, deduplication, the result screen opening once.
* Still-image QR from a real screenshot, a tiny code, several codes and no code (decoder is ML Kit / Vision, which cannot run in unit tests).
* Incoming shares: Android single/multiple; iOS Share Extension (also requires the Xcode setup above).
* Opening https/mailto/tel with and without a handler app installed.
* Draft recovery after force-quitting; 50-page memory; offline use (no network code is present, but not measured).
* TalkBack/VoiceOver, large font sizes, dark mode, Thai layout.

Record results in [docs/device-test-checklist.md](docs/device-test-checklist.md).

## Known limitations and next steps

1. **iOS Share Extension target** must be added in Xcode (steps above); the iOS app has not been built.
2. **Imported images** get manual corner adjustment but no automatic edge detection (only the native scanner detects edges).
3. **Large PDFs:** encoded pages are held in memory until the PDF is written; profile 50+ page documents on a low-memory device.
4. **Android release signing** uses the debug key; add an upload key before publishing.
5. Run the device checklist on at least one Android phone and one iPhone before release.
6. Deferred by design: OCR/searchable PDF, accounts, subscriptions, cloud sync, QR history.
