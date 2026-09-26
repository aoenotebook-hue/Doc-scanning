import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../app_strings.dart';
import 'capture.dart';
import 'qr_decode.dart';
import 'qr_result.dart';

class QrInputScreen extends StatefulWidget { const QrInputScreen({super.key}); @override State<QrInputScreen> createState() => _QrInputScreenState(); }

class _QrInputScreenState extends State<QrInputScreen> {
  // The camera starts only on this screen, so permission is requested when needed.
  final scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode], detectionSpeed: DetectionSpeed.noDuplicates);
  bool showing = false;
  S get s => S.of(context);

  Future<void> _photo() async {
    try {
      final value = await ImagePicker().pickImage(source: ImageSource.gallery, requestFullMetadata: false);
      if (value != null && mounted) await _still(value.path);
    } on PlatformException { if (mounted) showPermissionHelp(context, s.t('Photos could not be opened. Check access in Settings, or use Files.', 'เปิดรูปภาพไม่ได้ โปรดตรวจสอบสิทธิ์ในการตั้งค่า หรือใช้ไฟล์')); }
  }
  Future<void> _file() async {
    try {
      final value = await FilePicker.platform.pickFiles(type: FileType.image); final path = value?.files.single.path;
      if (path != null && mounted) await _still(path);
    } on PlatformException { if (mounted) showPermissionHelp(context, s.t('Files could not be opened. Try again.', 'เปิดไฟล์ไม่ได้ โปรดลองอีกครั้ง')); }
  }
  Future<void> _still(String path) async { await scanner.stop(); if (mounted) await decodeImageAndShow(context, path); if (mounted) await scanner.start(); }

  /// Live detections never navigate on their own: they open the review screen once,
  /// and the camera pauses until the user comes back.
  Future<void> _live(BarcodeCapture capture) async {
    if (showing) return;
    final values = capture.barcodes.map((b) => b.rawValue).whereType<String>().where((v) => v.isNotEmpty).toSet().toList();
    if (values.isEmpty) return;
    showing = true; await scanner.stop(); HapticFeedback.selectionClick();
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => QrResultScreen(values: values)));
    showing = false; if (mounted) await scanner.start();
  }

  @override void dispose() { scanner.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(s.t('Read QR', 'อ่านคิวอาร์'))),
    body: Column(children: [
      Expanded(child: Stack(fit: StackFit.expand, children: [
        Semantics(label: s.t('Camera viewfinder. Point at a QR code.', 'ช่องมองกล้อง หันไปที่คิวอาร์โค้ด'), child: MobileScanner(controller: scanner, onDetect: _live,
          errorBuilder: (_, error) => ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.no_photography_outlined, size: 48), const SizedBox(height: 12),
            Text(error.errorCode == MobileScannerErrorCode.permissionDenied
              ? s.t('Camera access is off. Allow it in Settings, or choose an image below.', 'การเข้าถึงกล้องปิดอยู่ โปรดอนุญาตในการตั้งค่า หรือเลือกรูปภาพด้านล่าง')
              : s.t('The camera is unavailable. Choose an image below instead.', 'ใช้กล้องไม่ได้ โปรดเลือกรูปภาพด้านล่างแทน'), textAlign: TextAlign.center),
          ])))))),
        IgnorePointer(child: Center(child: Container(width: 240, height: 240, decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(20))))),
      ])),
      SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Text(s.t('Nothing opens automatically. You will see every result first.', 'จะไม่มีการเปิดอัตโนมัติ คุณจะเห็นผลลัพธ์ก่อนเสมอ'), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: SizedBox(height: 52, child: FilledButton.icon(onPressed: _photo, icon: const Icon(Icons.photo_outlined), label: Text(s.t('Photos', 'รูปภาพ'))))),
          const SizedBox(width: 12),
          Expanded(child: SizedBox(height: 52, child: OutlinedButton.icon(onPressed: _file, icon: const Icon(Icons.folder_outlined), label: Text(s.t('Files', 'ไฟล์'))))),
        ]),
        const SizedBox(height: 10),
        Text(s.t('Have a screenshot? Choose it from Photos, or share it to Scan & Open from any app.', 'มีภาพหน้าจอไหม? เลือกจากรูปภาพ หรือแชร์มายังสแกนและเปิดจากแอปใดก็ได้'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      ]))),
    ]),
  );
}
