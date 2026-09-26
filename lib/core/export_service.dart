import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'models.dart';

class GeneratedExport {
  const GeneratedExport(this.path, this.bytes, this.isTemporary);
  final String path;
  final int bytes;
  final bool isTemporary;
}

class ExportService {
  Future<int> estimate(DocumentDraft draft, ExportOptions options) async {
    var originals = 0; for (final page in draft.pages) { originals += await File(page.originalPath).length(); }
    final scale = options.format == ExportFormat.pdf && options.pageSize != PageSize.auto
      ? math.pow(options.dpi / 300, 2).toDouble()
      : switch (options.resolution) { OutputResolution.small => .35, OutputResolution.standard => .65, OutputResolution.high => 1.0 };
    final codec = options.format == ExportFormat.png ? 1.25 : options.jpegQuality / 100;
    return math.max(1024, (originals * scale * codec).round());
  }

  Future<GeneratedExport> generate(DocumentDraft draft, ExportOptions options, String filename) async {
    if (draft.pages.isEmpty) throw StateError('A document needs at least one page.');
    final temp = await getTemporaryDirectory(); final dir = Directory('${temp.path}/scan_and_open_exports')..createSync(recursive: true);
    await _removeExpired(dir);
    if (options.format == ExportFormat.pdf) {
      final pdf = pw.Document(compress: true);
      for (final page in draft.pages) {
        final bytes = await Isolate.run(() => _render(page, options));
        final decoded = img.decodeImage(bytes)!;
        final format = options.pageSize == PageSize.letter ? PdfPageFormat.letter : options.pageSize == PageSize.a4 ? PdfPageFormat.a4 : PdfPageFormat(decoded.width.toDouble(), decoded.height.toDouble());
        pdf.addPage(pw.Page(pageFormat: format, margin: pw.EdgeInsets.zero, build: (_) => pw.Center(child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain))));
      }
      final output = File('${dir.path}/${_safe(filename, 'pdf')}'); await output.writeAsBytes(await pdf.save(), flush: true); return GeneratedExport(output.path, await output.length(), true);
    }
    final archive = Archive(); var index = 1;
    for (final page in draft.pages) {
      final bytes = await Isolate.run(() => _render(page, options));
      final ext = options.format.name; archive.addFile(ArchiveFile('page_${index.toString().padLeft(3, '0')}.$ext', bytes.length, bytes)); index++;
    }
    // A ZIP makes every selected image explicit and prevents platform share sheets dropping pages.
    final output = File('${dir.path}/${_safe(filename, 'zip')}'); await output.writeAsBytes(ZipEncoder().encode(archive), flush: true); return GeneratedExport(output.path, await output.length(), true);
  }

  static Uint8List _render(DocumentPage page, ExportOptions options) {
    var source = img.decodeImage(File(page.originalPath).readAsBytesSync()); if (source == null) throw FormatException('The image could not be read.');
    source = img.bakeOrientation(source);
    for (var degrees = 0; degrees < page.rotation % 360; degrees += 90) { source = img.copyRotate(source, angle: 90); }
    // Fixed PDF sheets derive raster dimensions from the selected physical size and DPI.
    // Image/auto exports instead expose straightforward pixel presets.
    final maxSide = options.format == ExportFormat.pdf && options.pageSize != PageSize.auto
      ? ((options.pageSize == PageSize.a4 ? 11.69 : 11.0) * options.dpi).round()
      : switch (options.resolution) { OutputResolution.small => 1280, OutputResolution.standard => 2048, OutputResolution.high => 3508 };
    if (math.max(source.width, source.height) > maxSide) source = source.width >= source.height ? img.copyResize(source, width: maxSide) : img.copyResize(source, height: maxSide);
    if (page.filter == PageFilter.grayscale) source = img.grayscale(source);
    if (page.filter == PageFilter.blackAndWhite) { source = img.grayscale(source); source = img.luminanceThreshold(source, threshold: 0.55); }
    if (page.filter == PageFilter.enhanced) source = img.adjustColor(source, contrast: 1.14, saturation: 1.05);
    return options.format == ExportFormat.png ? Uint8List.fromList(img.encodePng(source, level: 6)) : Uint8List.fromList(img.encodeJpg(source, quality: options.jpegQuality));
  }

  String _safe(String input, String ext) { final base = input.replaceAll(RegExp(r'[^A-Za-z0-9 _.-]'), '_').replaceAll(RegExp(r'\.[^.]+$'), ''); return '${base.isEmpty ? 'Scan' : base}.$ext'; }
  Future<void> _removeExpired(Directory dir) async { final cutoff = DateTime.now().subtract(const Duration(days: 1)); await for (final item in dir.list()) { if ((await item.stat()).modified.isBefore(cutoff)) { try { await item.delete(recursive: true); } on FileSystemException { /* Retry next launch. */ } } } }
}
