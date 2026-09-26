import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'image_pipeline.dart';
import 'models.dart';

/// Decodes every QR payload in an image file. Supplied by the platform scanner.
typedef QrAnalyzer = Future<List<String>> Function(String path);

/// Image variants tried after the original fails, cheapest first.
enum QrVariant { enhanced, rotated90, rotated180, rotated270 }

/// Runs the platform decoder on the original image, then on processed variants,
/// stopping at the first that finds codes. All decoding stays on-device.
class QrDecoder {
  QrDecoder(this._analyze, {required this.workDirectory});
  final QrAnalyzer _analyze;
  final Directory workDirectory;

  Future<List<String>> decodeFile(String path) async {
    final first = await _safeAnalyze(path);
    if (first.isNotEmpty) return first;
    await workDirectory.create(recursive: true);
    for (final variant in QrVariant.values) {
      final target = '${workDirectory.path}/${DateTime.now().microsecondsSinceEpoch}_${variant.name}.png';
      try {
        await Isolate.run(() => writeVariant(path, target, variant));
        final found = await _safeAnalyze(target);
        if (found.isNotEmpty) return found;
      } on FormatException { return const []; }
      finally { try { await File(target).delete(); } on FileSystemException { /* Cleared with temporary files. */ } }
    }
    return const [];
  }

  /// Crops [path] to [quad] (perspective-corrected), then decodes with the same retries.
  Future<List<String>> decodeCrop(String path, CropQuad quad) async {
    await workDirectory.create(recursive: true);
    final target = '${workDirectory.path}/${DateTime.now().microsecondsSinceEpoch}_crop.png';
    try {
      await Isolate.run(() => File(target).writeAsBytesSync(img.encodePng(ImagePipeline.perspectiveCrop(ImagePipeline.decodeUpright(path), quad))));
      return await decodeFile(target);
    } finally { try { await File(target).delete(); } on FileSystemException { /* Cleared with temporary files. */ } }
  }

  Future<List<String>> _safeAnalyze(String path) async {
    try { return _dedupe(await _analyze(path)); } on Exception { return const []; }
  }

  static List<String> _dedupe(List<String> values) => values.where((v) => v.isNotEmpty).toSet().toList();

  /// Small codes are upscaled so modules span several pixels; contrast is stretched to
  /// help faded prints and low-contrast screenshots.
  static void writeVariant(String source, String target, QrVariant variant) {
    var image = ImagePipeline.decodeUpright(source);
    switch (variant) {
      case QrVariant.enhanced:
        final longest = math.max(image.width, image.height);
        if (longest < 1200) image = image.width >= image.height ? img.copyResize(image, width: 1600, interpolation: img.Interpolation.cubic) : img.copyResize(image, height: 1600, interpolation: img.Interpolation.cubic);
        image = img.normalize(img.grayscale(image), min: 0, max: 255);
      case QrVariant.rotated90: image = img.copyRotate(image, angle: 90);
      case QrVariant.rotated180: image = img.copyRotate(image, angle: 180);
      case QrVariant.rotated270: image = img.copyRotate(image, angle: 270);
    }
    File(target).writeAsBytesSync(img.encodePng(image, level: 1));
  }
}
