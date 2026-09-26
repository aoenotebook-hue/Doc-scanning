import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import '../app_strings.dart';
import '../core/models.dart';
import '../core/qr_decoder.dart';
import 'crop_screen.dart';
import 'qr_result.dart';

Future<QrDecoder> _decoder() async {
  final controller = MobileScannerController(autoStart: false, formats: const [BarcodeFormat.qrCode]);
  final work = Directory('${(await getTemporaryDirectory()).path}/qr_work');
  return QrDecoder((path) async {
    final capture = await controller.analyzeImage(path, formats: const [BarcodeFormat.qrCode]);
    return (capture?.barcodes ?? const <Barcode>[]).map((b) => b.rawValue).whereType<String>().toList();
  }, workDirectory: work);
}

/// Decodes a still image (photo, file, screenshot or shared image) on-device and shows
/// the results, or a clear "No QR code found" screen with crop-and-retry.
Future<void> decodeImageAndShow(BuildContext context, String path, {CropQuad? crop, bool replace = false}) async {
  final s = S.of(context);
  showDialog<void>(context: context, barrierDismissible: false, builder: (_) => PopScope(canPop: false, child: AlertDialog(content: Row(children: [
    const CircularProgressIndicator(), const SizedBox(width: 20), Expanded(child: Semantics(liveRegion: true, child: Text(s.t('Looking for QR codes…', 'กำลังค้นหาคิวอาร์โค้ด…')))),
  ]))));
  List<String> values;
  try { final decoder = await _decoder(); values = crop == null ? await decoder.decodeFile(path) : await decoder.decodeCrop(path, crop); }
  on Object { values = const []; }
  if (!context.mounted) return;
  Navigator.of(context).pop();
  final route = MaterialPageRoute<void>(builder: (_) => values.isEmpty ? NoQrScreen(imagePath: path) : QrResultScreen(values: values));
  replace ? await Navigator.pushReplacement(context, route) : await Navigator.push(context, route);
}

class NoQrScreen extends StatelessWidget {
  const NoQrScreen({required this.imagePath, super.key});
  final String imagePath;
  @override Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(appBar: AppBar(title: Text(s.t('Read QR', 'อ่านคิวอาร์'))), body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      Icon(Icons.qr_code_2, size: 72, color: Theme.of(context).colorScheme.outline, semanticLabel: ''),
      const SizedBox(height: 12),
      Semantics(header: true, liveRegion: true, child: Text(s.t('No QR code found', 'ไม่พบคิวอาร์โค้ด'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall)),
      const SizedBox(height: 8),
      Text(s.t('If the code is small or part of a larger picture, crop closely around it and try again.', 'หากโค้ดมีขนาดเล็กหรืออยู่ในภาพใหญ่ ให้ครอบตัดรอบโค้ดให้ชิดแล้วลองอีกครั้ง'), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      ClipRRect(borderRadius: BorderRadius.circular(12), child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 260), child: Image.file(File(imagePath), fit: BoxFit.contain, semanticLabel: s.t('The image you chose', 'ภาพที่คุณเลือก')))),
      const SizedBox(height: 24),
      SizedBox(height: 52, child: FilledButton.icon(icon: const Icon(Icons.crop), label: Text(s.t('Crop and try again', 'ครอบตัดแล้วลองอีกครั้ง')), onPressed: () async {
        final quad = await Navigator.push<CropQuad>(context, MaterialPageRoute(builder: (_) => CropScreen(imagePath: imagePath, title: s.t('Crop around the code', 'ครอบตัดรอบโค้ด'), confirmLabel: s.t('Read QR', 'อ่านคิวอาร์'))));
        if (quad != null && context.mounted) await decodeImageAndShow(context, imagePath, crop: quad, replace: true);
      })),
      const SizedBox(height: 12),
      SizedBox(height: 52, child: OutlinedButton.icon(icon: const Icon(Icons.arrow_back), label: Text(s.t('Choose another image', 'เลือกภาพอื่น')), onPressed: () => Navigator.pop(context))),
    ])));
  }
}
