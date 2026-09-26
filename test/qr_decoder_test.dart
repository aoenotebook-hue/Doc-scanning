import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_and_open/core/models.dart';
import 'package:scan_and_open/core/qr_decoder.dart';
import 'test_images.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('qr'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('returns the first successful pass and removes duplicates', () async {
    final path = writeImage(dir, 'shot.png', 100, 100);
    final seen = <String>[];
    final decoder = QrDecoder((p) async { seen.add(p); return ['https://a.example', 'https://a.example', 'text']; }, workDirectory: Directory('${dir.path}/work'));
    expect(await decoder.decodeFile(path), ['https://a.example', 'text']);
    expect(seen, [path]);
  });

  test('falls back to processed variants when the original has no code', () async {
    final path = writeImage(dir, 'tiny.png', 80, 60);
    var calls = 0;
    final decoder = QrDecoder((p) async { calls++; return p.endsWith('_rotated180.png') ? ['found'] : <String>[]; }, workDirectory: Directory('${dir.path}/work'));
    expect(await decoder.decodeFile(path), ['found']);
    expect(calls, 4); // original, enhanced, 90°, 180°
    expect(Directory('${dir.path}/work').listSync(), isEmpty); // Variant files cleaned up.
  });

  test('reports no codes after every retry fails, without throwing', () async {
    final path = writeImage(dir, 'blank.png', 50, 50);
    final decoder = QrDecoder((p) async => throw Exception('platform failure'), workDirectory: Directory('${dir.path}/work'));
    expect(await decoder.decodeFile(path), isEmpty);
  });

  test('crop-and-retry decodes the cropped region', () async {
    final path = writeImage(dir, 'crop.png', 400, 400);
    final decoder = QrDecoder((p) async => p.endsWith('_crop.png') ? ['cropped'] : <String>[], workDirectory: Directory('${dir.path}/work'));
    expect(await decoder.decodeCrop(path, const CropQuad([.25, .25, .75, .25, .75, .75, .25, .75])), ['cropped']);
  });
}
