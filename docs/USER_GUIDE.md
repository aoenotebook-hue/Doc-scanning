# Scan & Open — User Guide

Everything stays on your phone: no account, no uploads.

## Install (Android)

1. On GitHub open **Actions → CI**, pick the latest green run, and download the
   **scan-and-open-apk** artifact. Unzip it to get `app-release.apk`.
2. Copy the APK to your phone (or download it there) and tap it.
3. Allow "Install unknown apps" for your browser/file manager when Android asks.

## Install (iPhone)

iOS needs a Mac with Xcode and an Apple developer account (free is enough for your own phone):

1. `flutter pub get`, then open `ios/Runner.xcworkspace` in Xcode.
2. Select the **Runner** target → *Signing & Capabilities* → choose your Team.
3. Connect the iPhone and press **Run**.
4. Optional, to share images into the app: add the Share Extension as described in the README.

## Scan a document

1. Tap **Scan Document**. The camera finds page edges automatically; take one or more pages.
2. Tap **Save/Done** in the scanner. The pages open in the editor.

No camera? Use **Import Images** on the home screen to build a document from existing photos.

## Edit pages

| Button | What it does |
| --- | --- |
| Scan / Import | Add more pages to this document |
| Rotate | Turn the selected page 90° |
| Filter | Original, Enhanced, Grayscale, or Black & white (shown in the preview) |
| ← / → | Move the selected page earlier or later (or long-press a thumbnail and drag) |
| Delete page | Remove the selected page |
| ✎ (top bar) | Rename the document |

Changes save automatically. Your original photos are never altered.

## Export or share

1. In the editor tap **Export**.
2. Choose **PDF** (one file), or **JPG/PNG** (pages packed into a ZIP).
3. For PDF, pick page size (A4, Letter, Fit image) and DPI. Lower DPI or JPEG quality
   = smaller file; the estimated size updates live.
4. **Save As** lets you pick a folder (Files / Drive / Downloads). **Share** sends it to
   any app (email, chat…).

## Read a QR code

1. Tap **Read QR** and point the camera at the code, or tap **Photos**/**Files** to read
   one from a screenshot or picture.
2. The result is shown first — nothing opens automatically. Web links show the real
   destination hostname so you can spot fakes.
3. Tap **Open** (web, email, phone), **Copy**, or **Share**.

## Share images into the app

From Gallery/Photos, select images → **Share** → **Scan & Open**. A new document is
created with those images.

## Manage documents and settings

* Home screen lists recent documents; tap one to continue, 🗑 to delete it.
* ⚙ **Settings**: language (English/ไทย), light/dark theme, and *Delete all local documents*.

## Troubleshooting

* **"Camera unavailable"** — allow Camera permission in phone Settings, or use Import.
  On Android the scanner needs Google Play services.
* **"No QR code found"** — crop the image closer to the code and try again.
* **Nothing saved** — you cancelled the folder picker; the document is still in the app.
