import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scan_and_open/core/image_pipeline.dart';
import 'package:scan_and_open/core/models.dart';
import 'test_images.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('pipeline'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('EXIF orientation 6 is baked so a sideways photo exports upright', () {
    // Stored 400x200 landscape with "rotate 90° CW" EXIF → displayed as 200x400 portrait.
    final path = writeImage(dir, 'rotated.jpg', 400, 200, exifOrientation: 6);
    final upright = ImagePipeline.decodeUpright(path);
    expect([upright.width, upright.height], [200, 400]);
    final rendered = ImagePipeline.renderPage(DocumentPage(id: 'p', originalPath: path), const ExportOptions(format: ExportFormat.png, pageSize: PageSize.auto));
    expect([rendered.width, rendered.height], [200, 400]);
  });

  test('user rotation turns the page and the crop follows it', () {
    final path = writeImage(dir, 'page.png', 300, 100);
    final page = DocumentPage(id: 'p', originalPath: path, crop: const CropQuad([0, 0, .5, 0, .5, 1, 0, 1])).rotated();
    expect(page.rotation, 90);
    final out = ImagePipeline.applyEdits(ImagePipeline.decodeUpright(path), page);
    // Rotated page is 100x300; the left half of the original is now the top half.
    expect([out.width, out.height], [100, 150]);
  });

  test('four rotations return the crop to where it started', () {
    const quad = CropQuad([.1, .2, .9, .1, .8, .9, .2, .8]);
    var q = quad; for (var i = 0; i < 4; i++) { q = q.rotatedClockwise(); }
    for (var i = 0; i < 8; i++) { expect(q.points[i], closeTo(quad.points[i], 1e-9)); }
  });

  test('perspective crop rectifies a skewed quad to its edge lengths', () {
    final source = img.Image(width: 1000, height: 1000);
    final out = ImagePipeline.perspectiveCrop(source, const CropQuad([.1, .1, .9, .2, .9, .8, .1, .9]));
    expect(out.width, closeTo(806, 2)); // Longest horizontal edge.
    expect(out.height, closeTo(800, 2)); // Longest vertical edge.
  });

  test('downscaling preserves aspect ratio and never enlarges', () {
    final big = img.Image(width: 4000, height: 3000);
    final fitted = ImagePipeline.fit(big, 2048);
    expect([fitted.width, fitted.height], [2048, 1536]);
    final small = img.Image(width: 800, height: 600);
    expect(identical(ImagePipeline.fit(small, 2048), small), isTrue);
  });

  test('black & white produces only pure black and white pixels', () {
    final path = writeImage(dir, 'bw.png', 64, 64, r: 120, g: 120, b: 120);
    final out = ImagePipeline.applyEdits(ImagePipeline.decodeUpright(path), DocumentPage(id: 'p', originalPath: path, filter: PageFilter.blackAndWhite));
    final levels = <num>{for (final p in out) p.r};
    expect(levels.difference({0, 255}), isEmpty);
  });

  test('filters never alter the preserved original file', () {
    final path = writeImage(dir, 'orig.png', 32, 32);
    final before = File(path).readAsBytesSync();
    ImagePipeline.renderPage(DocumentPage(id: 'p', originalPath: path, filter: PageFilter.grayscale, rotation: 90), const ExportOptions());
    expect(File(path).readAsBytesSync(), before);
  });

  test('an unreadable image fails with FormatException', () {
    final path = '${dir.path}/broken.jpg'; File(path).writeAsStringSync('not an image');
    expect(() => ImagePipeline.decodeUpright(path), throwsFormatException);
  });
}
