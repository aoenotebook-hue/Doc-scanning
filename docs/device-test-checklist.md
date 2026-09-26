# Physical-device acceptance checklist

Run on at least one Android phone and one iPhone. For each row record: device model, OS version,
app commit, Pass/Fail, and evidence (screenshot, video, or exported-file name and size).
Turn on airplane mode for the rows marked ✈ to confirm on-device operation.

| # | Test | Expected |
| --- | --- | --- |
| 1 | ✈ Scan 3 pages, reorder to 3,1,2, export PDF, open it | PDF has 3 pages in order 3,1,2 |
| 2 | Scanner: adjust all four corners, retake page 2, use the manual shutter | Corrected page used; retake replaces page 2 |
| 3 | Deny/disable the scanner (e.g. no Play services) → Take photo | Photo opens the corner editor; page is cropped |
| 4 | Import a sideways (EXIF-rotated) photo, export JPG/PNG/PDF | Preview and all exports upright |
| 5 | Crop, rotate and change colour mode; then reset crop and choose Original | Preview matches export each time; original restored |
| 6 | Save As → choose a folder → reopen the file in another app | "Saved …" shown only after success; file opens |
| 7 | Save As → cancel | "Not saved. Your document is still here." Draft unchanged |
| 8 | Save As to a full or removed location | Friendly error with Try again; draft kept |
| 9 | Export 3 pages as JPG and as PNG | ZIP contains page_001…page_003; one page gives a single image |
| 10 | Small vs High; JPEG quality 45 vs 95; 150 vs 300 DPI | Created size changes accordingly; estimate labelled approximate |
| 11 | Force-quit during editing, relaunch | Document, order, rotation, crop, colour mode all restored |
| 12 | ✈ Read QR from a screenshot via Photos | Result shown; nothing opened automatically |
| 13 | Image with two QR codes | Both listed; selecting each updates the result |
| 14 | Image with no QR code | "No QR code found" with Crop and try again |
| 15 | Tiny QR in a large photo → Crop and try again | Code decoded |
| 16 | Live camera on a code; go back | Result opens once; camera resumes, no repeats |
| 17 | Share 1 and 3 images from Gallery/Photos into the app | Asked: make a document / read QR; document has all pages |
| 18 | QR with https link → Open | Hostname shown; browser/app opens only after tap |
| 19 | QR with mailto: and tel:, with and without a mail/phone app | System app opens, or "No app… copy instead" |
| 20 | QR with plain text, javascript:, data:, file:, intent:, myapp:// | Shown as text; no Open button |
| 21 | Deny camera permission, then use Photos/Files | Clear message; still-image paths work |
| 22 | 50-page document export | Progress per page; no crash; note peak memory |
| 23 | TalkBack / VoiceOver through every screen | All controls announced; thumbnails say "Page n of m" |
| 24 | Largest font size, Thai language, dark theme | No clipped text; Thai strings everywhere |
| 25 | Settings → Clear temporary files; Delete all documents | Documents kept / all removed respectively |
