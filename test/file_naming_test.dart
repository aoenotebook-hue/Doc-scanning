import 'package:flutter_test/flutter_test.dart';
import 'package:scan_and_open/core/draft_store.dart';
import 'package:scan_and_open/core/export_service.dart';

void main() {
  group('imageExtension', () {
    test('ignores dots in directory names', () {
      expect(imageExtension('/data/user/0/app.scanandopen/cache/incoming/shared_1'), '.jpg');
      expect(imageExtension('/data/user/0/app.scanandopen/cache/scan_0.JPEG'), '.jpeg');
    });
    test('keeps ordinary image extensions', () {
      expect(imageExtension('/tmp/photo.png'), '.png');
      expect(imageExtension(r'C:\images\scan.heic'), '.heic');
    });
    test('falls back for hidden, trailing-dot, or odd names', () {
      expect(imageExtension('/tmp/.hidden'), '.jpg');
      expect(imageExtension('/tmp/name.'), '.jpg');
      expect(imageExtension('/tmp/name.not an ext'), '.jpg');
    });
  });
  group('safeFilename', () {
    test('strips path separators and reserved characters', () {
      expect(ExportService.safeFilename('../a/b:c*?', 'pdf'), '_a_b_c__.pdf');
    });
    test('keeps non-Latin names and replaces a duplicate extension', () {
      expect(ExportService.safeFilename('ใบเสร็จ.pdf', 'pdf'), 'ใบเสร็จ.pdf');
      expect(ExportService.safeFilename('  ', 'zip'), 'Scan.zip');
    });
  });
}
