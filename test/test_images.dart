import 'dart:io';
import 'package:image/image.dart' as img;

/// Writes a solid-colour JPEG/PNG of the given size for pipeline tests.
String writeImage(Directory dir, String name, int width, int height, {int r = 200, int g = 40, int b = 40, int? exifOrientation}) {
  final image = img.Image(width: width, height: height)..clear(img.ColorRgb8(r, g, b));
  // Mark the top-left pixel block so orientation and rotation can be traced.
  img.fillRect(image, x1: 0, y1: 0, x2: width ~/ 4, y2: height ~/ 4, color: img.ColorRgb8(0, 0, 255));
  if (exifOrientation != null) image.exif.imageIfd.orientation = exifOrientation;
  final file = File('${dir.path}/$name');
  file.writeAsBytesSync(name.endsWith('.png') ? img.encodePng(image) : img.encodeJpg(image, quality: 95));
  return file.path;
}
