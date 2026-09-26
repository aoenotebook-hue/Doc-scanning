import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scan_and_open/core/export_service.dart';
import 'package:scan_and_open/core/models.dart';
import 'test_images.dart';

void main() {
  late Directory dir; late ExportService service;
  setUp(() { dir = Directory.systemTemp.createTempSync('export'); service = ExportService(outputDirectory: () async => Directory('${dir.path}/out')); });
  tearDown(() => dir.deleteSync(recursive: true));

  List<DocumentPage> threePages() => [
    // Distinct widths let us trace page order inside the outputs.
    DocumentPage(id: 'a', originalPath: writeImage(dir, 'a.jpg', 300, 400)),
    DocumentPage(id: 'b', originalPath: writeImage(dir, 'b.jpg', 310, 400)),
    DocumentPage(id: 'c', originalPath: writeImage(dir, 'c.jpg', 320, 400)),
  ];

  test('PDF contains every page in the reordered order', () async {
    final p = threePages(); final reordered = [p[2], p[0], p[1]];
    final out = await service.generate(reordered, const ExportOptions(pageSize: PageSize.auto), 'Doc');
    expect(out.filename, 'Doc.pdf'); expect(out.mime, 'application/pdf');
    final text = latin1.decode(File(out.path).readAsBytesSync());
    expect(RegExp(r'/Type\s*/Page[^s]').allMatches(text).length, 3);
    final widths = RegExp(r'/Width (\d+)').allMatches(text).map((m) => m.group(1)).toList();
    expect(widths, ['320', '300', '310']);
    expect(out.bytes, File(out.path).lengthSync());
  });

  test('multi-page JPG and PNG exports keep every page in a numbered ZIP', () async {
    for (final format in [ExportFormat.jpg, ExportFormat.png]) {
      final out = await service.generate(threePages(), ExportOptions(format: format), 'Pages');
      expect(out.filename, 'Pages.zip');
      final archive = ZipDecoder().decodeBytes(File(out.path).readAsBytesSync());
      expect(archive.files.map((f) => f.name), ['page_001.${format.name}', 'page_002.${format.name}', 'page_003.${format.name}']);
      expect(archive.files.map((f) => img.decodeImage(f.content)!.width), [300, 310, 320]);
    }
  });

  test('a single image page exports as that image, not a ZIP', () async {
    final out = await service.generate(threePages().take(1).toList(), const ExportOptions(format: ExportFormat.png), 'One');
    expect(out.filename, 'One.png'); expect(out.mime, 'image/png');
    expect(img.decodePng(File(out.path).readAsBytesSync())!.width, 300);
  });

  test('resolution preset changes the output pixel dimensions', () async {
    final page = [DocumentPage(id: 'big', originalPath: writeImage(dir, 'big.jpg', 3000, 2000))];
    final small = await service.generate(page, const ExportOptions(format: ExportFormat.jpg, resolution: OutputResolution.small), 's');
    final high = await service.generate(page, const ExportOptions(format: ExportFormat.jpg, resolution: OutputResolution.high), 'h');
    expect(img.decodeJpg(File(small.path).readAsBytesSync())!.width, 1280);
    expect(img.decodeJpg(File(high.path).readAsBytesSync())!.width, 3000); // Never upscaled past the source.
  });

  test('JPEG quality changes the generated file size', () async {
    final noisy = img.Image(width: 800, height: 800);
    for (final p in noisy) { p..r = (p.x * 7 + p.y * 13) % 256..g = (p.x * p.y) % 256..b = (p.y * 3) % 256; }
    final path = '${dir.path}/noisy.png'; File(path).writeAsBytesSync(img.encodePng(noisy));
    final page = [DocumentPage(id: 'n', originalPath: path)];
    final low = await service.generate(page, const ExportOptions(format: ExportFormat.jpg, jpegQuality: 45), 'low');
    final high = await service.generate(page, const ExportOptions(format: ExportFormat.jpg, jpegQuality: 95), 'high');
    expect(low.bytes, lessThan(high.bytes));
  });

  test('PDF DPI changes fixed-size page raster resolution', () async {
    final page = [DocumentPage(id: 'big', originalPath: writeImage(dir, 'tall.jpg', 2000, 4000))];
    Future<int> height(int dpi) async { final out = await service.generate(page, ExportOptions(dpi: dpi), 'd$dpi'); return int.parse(RegExp(r'/Height (\d+)').firstMatch(latin1.decode(File(out.path).readAsBytesSync()))!.group(1)!); }
    expect(await height(150), 1754); // 11.69 in × 150 DPI.
    expect(await height(300), 3507);
  });

  test('empty selection and unreadable images fail with a typed reason', () async {
    await expectLater(service.generate(const [], const ExportOptions(), 'x'), throwsA(isA<ExportException>().having((e) => e.reason, 'reason', ExportFailure.noPages)));
    final broken = '${dir.path}/broken.jpg'; File(broken).writeAsStringSync('nope');
    await expectLater(service.generate([DocumentPage(id: 'x', originalPath: broken)], const ExportOptions(), 'x'), throwsA(isA<ExportException>().having((e) => e.reason, 'reason', ExportFailure.unreadableImage)));
  });

  test('estimate grows with resolution and quality', () async {
    final pages = threePages();
    final small = await service.estimate(pages, const ExportOptions(format: ExportFormat.jpg, resolution: OutputResolution.small, jpegQuality: 50));
    final large = await service.estimate(pages, const ExportOptions(format: ExportFormat.jpg, resolution: OutputResolution.high, jpegQuality: 95));
    expect(small, lessThanOrEqualTo(large));
  });

  test('expired temporary exports are removed, fresh ones kept', () async {
    final tmp = Directory('${dir.path}/tmp')..createSync();
    final old = File('${tmp.path}/old.pdf')..writeAsStringSync('x'); old.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 2)));
    final fresh = File('${tmp.path}/fresh.pdf')..writeAsStringSync('x');
    expect(await ExportService.removeExpired(tmp), 1);
    expect(old.existsSync(), isFalse); expect(fresh.existsSync(), isTrue);
  });
}
