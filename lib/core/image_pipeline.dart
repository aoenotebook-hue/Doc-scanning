import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'models.dart';

/// Pure image transformations shared by previews, export and QR retries.
/// Everything here is synchronous and UI-free so it can run inside `Isolate.run`.
class ImagePipeline {
  /// Decodes [path] and applies EXIF orientation, so every later step sees an upright image.
  static img.Image decodeUpright(String path) {
    img.Image? decoded;
    // Corrupt data can make decoders throw arbitrary errors rather than return null.
    try { decoded = img.decodeImage(File(path).readAsBytesSync()); } on FileSystemException { rethrow; } on Object { decoded = null; }
    if (decoded == null) throw const FormatException('The image could not be read.');
    return img.bakeOrientation(decoded);
  }

  /// Order: orientation → rotation → perspective crop → downscale → filter.
  /// Downscaling before filtering keeps memory and time proportional to the output.
  static img.Image applyEdits(img.Image upright, DocumentPage page, {int? maxSide, bool includeCrop = true, bool includeFilter = true}) {
    var out = rotate(upright, page.rotation);
    if (includeCrop && page.crop != null && !page.crop!.isFull) out = perspectiveCrop(out, page.crop!);
    if (maxSide != null) out = fit(out, maxSide);
    if (includeFilter) out = applyFilter(out, page.filter);
    return out;
  }

  static img.Image rotate(img.Image source, int degrees) {
    final turns = (degrees ~/ 90) % 4;
    return turns == 0 ? source : img.copyRotate(source, angle: turns * 90);
  }

  /// Shrinks so the longest side is at most [maxSide], preserving aspect ratio.
  /// Never enlarges: upscaling cannot add detail missing from the source.
  static img.Image fit(img.Image source, int maxSide) {
    if (math.max(source.width, source.height) <= maxSide) return source;
    return source.width >= source.height
      ? img.copyResize(source, width: maxSide, interpolation: img.Interpolation.average)
      : img.copyResize(source, height: maxSide, interpolation: img.Interpolation.average);
  }

  /// Output size of a rectified quad: the longer of each pair of opposite edges.
  static (int, int) rectifiedSize(img.Image source, CropQuad quad) {
    double dist(int a, int b) => math.sqrt(math.pow((quad.x(a) - quad.x(b)) * source.width, 2) + math.pow((quad.y(a) - quad.y(b)) * source.height, 2));
    final w = math.max(dist(0, 1), dist(3, 2)).round();
    final h = math.max(dist(0, 3), dist(1, 2)).round();
    return (math.max(1, w), math.max(1, h));
  }

  /// Maps the quad onto an upright rectangle (perspective correction).
  static img.Image perspectiveCrop(img.Image source, CropQuad quad) {
    final (w, h) = rectifiedSize(source, quad);
    img.Point p(int i) => img.Point(quad.x(i) * (source.width - 1), quad.y(i) * (source.height - 1));
    return img.copyRectify(source, topLeft: p(0), topRight: p(1), bottomRight: p(2), bottomLeft: p(3),
      interpolation: img.Interpolation.linear, toImage: img.Image(width: w, height: h, numChannels: source.numChannels));
  }

  static img.Image applyFilter(img.Image source, PageFilter filter) => switch (filter) {
    PageFilter.original => source,
    PageFilter.enhanced => img.adjustColor(source.clone(), contrast: 1.14, saturation: 1.05),
    PageFilter.grayscale => img.grayscale(source.clone()),
    PageFilter.blackAndWhite => img.luminanceThreshold(img.grayscale(source.clone()), threshold: 0.55),
  };

  static Uint8List encode(img.Image image, ExportFormat format, int jpegQuality) => format == ExportFormat.png
    ? Uint8List.fromList(img.encodePng(image, level: 6))
    : Uint8List.fromList(img.encodeJpg(image, quality: jpegQuality));

  /// Renders a page for export. Only the encoded bytes cross back to the caller.
  static RenderedPage renderPage(DocumentPage page, ExportOptions options) {
    final out = applyEdits(decodeUpright(page.originalPath), page, maxSide: options.maxSide);
    return RenderedPage(encode(out, options.format, options.jpegQuality), out.width, out.height);
  }

  /// Writes a screen-sized JPEG preview to [target]. With [forCropping], the crop and
  /// filter are skipped so the corner editor shows the whole page.
  static void writePreview(DocumentPage page, String target, {int maxSide = 1600, bool forCropping = false}) {
    final out = applyEdits(decodeUpright(page.originalPath), page, maxSide: maxSide, includeCrop: !forCropping, includeFilter: !forCropping);
    File(target)..parent.createSync(recursive: true)..writeAsBytesSync(img.encodeJpg(out, quality: 85));
  }
}

class RenderedPage {
  const RenderedPage(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
}
