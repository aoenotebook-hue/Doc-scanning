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

To use existing photos instead, tap **Or make a document from existing images** on the home screen.

If the document scanner isn't available on your phone, the app offers **Take photo**: take a normal photo, then drag the four corners to the page edges.

## Edit pages

| Button | What it does |
| --- | --- |
| Scan / Import | Add more pages to this document |
| Crop | Drag the four corners to the page edges; the page is straightened |
| Rotate | Turn the selected page 90° |
| Filter | Original, Enhanced, Grayscale, or Black & white (shown in the preview) |
| ← / → | Move the selected page earlier or later (or long-press a thumbnail and drag) |
| Replace page | Rescan, retake or choose a different image for this page |
| Delete page | Remove the selected page (tap Undo to bring it back) |
| ✎ (top bar) | Rename the document |

Pinch the page to zoom. Changes save automatically, even if the app closes. Your original photos are never altered, so every edit can be changed back.

## Export or share

1. In the editor tap **Export**.
2. Pick which pages to include (all by default).
3. Choose **PDF** (one file), or **JPG/PNG** (one page = one image; several pages are packed into a ZIP).
4. Set **page size** (PDF only), **resolution**, and **compression**. The estimated size updates as you
   change them; the real size is shown once the file is created. PNG has no quality setting — pick a lower
   resolution to make it smaller.
4. **Save As** lets you pick a folder (Files / Drive / Downloads). **Share** sends it to
   any app (email, chat…).

## Read a QR code

1. Tap **Read QR** and point the camera at the code, or tap **Photos**/**Files** to read
   one from a screenshot or picture. If several codes are found, pick one from the list.
   If none is found, tap **Crop and try again** and draw closely around the code.
2. The result is shown first — nothing opens automatically. Web links show the real
   destination hostname so you can spot fakes.
3. Tap **Open** (web, email, phone), **Copy**, or **Share**.

## Share images into the app

From Gallery/Photos, select images → **Share** → **Scan & Open**, then open the app. It asks whether
to **Make a document** or **Read QR code**.

## Manage documents and settings

* Home screen lists recent documents; tap one to continue, 🗑 to delete it.
* ⚙ **Settings**: language (device, English, ไทย), theme, default export settings,
  *Clear temporary files*, and *Delete all documents*.

## Troubleshooting

* **"Camera unavailable"** — allow Camera permission in phone Settings, or use Import.
  On Android the scanner needs Google Play services.
* **"No QR code found"** — crop the image closer to the code and try again.
* **Nothing saved** — you cancelled the folder picker; the document is still in the app.
