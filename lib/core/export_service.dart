import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'image_pipeline.dart';
import 'models.dart';

/// A generated file in temporary storage. It is not "saved" until the user's chosen
/// destination accepts it.
class GeneratedExport {
  const GeneratedExport(this.path, this.bytes, this.mime, this.filename);
  final String path;
  final int bytes;
  final String mime;
  final String filename;
}

enum ExportFailure { noPages, unreadableImage, storageFull, unknown }

class ExportException implements Exception {
  const ExportException(this.reason);
  final ExportFailure reason;
  @override String toString() => 'ExportException(${reason.name})';
}

typedef ExportProgress = void Function(int done, int total);

class ExportService {
  ExportService({Future<Directory> Function()? outputDirectory}) : _outputDirectory = outputDirectory ?? _defaultDirectory;
  final Future<Directory> Function() _outputDirectory;
  static const _folder = 'scan_and_open_exports';
  static Future<Directory> _defaultDirectory() async => Directory('${(await getTemporaryDirectory()).path}/$_folder');

  /// A rough size, clearly labelled as an estimate in the UI.
  Future<int> estimate(List<DocumentPage> pages, ExportOptions options) async {
    var originals = 0; for (final page in pages) { try { originals += await File(page.originalPath).length(); } on FileSystemException { /* Missing file: counted as zero. */ } }
    // Scale by output pixel area relative to a typical 12 MP capture (~4000 px long side).
    final scale = math.min(1.0, math.pow(options.maxSide / 4000, 2).toDouble());
    final codec = options.format == ExportFormat.png ? 2.2 : 0.25 + options.jpegQuality / 100 * .9;
    return math.max(1024, (originals * scale * codec).round());
  }

  /// One file: a PDF, a single JPG/PNG, or a ZIP holding every page for multi-page images.
  static String extensionFor(ExportOptions options, int pageCount) => options.format == ExportFormat.pdf ? 'pdf' : pageCount == 1 ? options.format.name : 'zip';
  static String mimeFor(String extension) => switch (extension) { 'pdf' => 'application/pdf', 'jpg' => 'image/jpeg', 'png' => 'image/png', _ => 'application/zip' };

  Future<GeneratedExport> generate(List<DocumentPage> pages, ExportOptions options, String filename, {ExportProgress? onProgress}) async {
    if (pages.isEmpty) throw const ExportException(ExportFailure.noPages);
    final dir = await _outputDirectory(); await dir.create(recursive: true);
    await removeExpired(dir);
    final ext = extensionFor(options, pages.length); final name = safeFilename(filename, ext);
    final output = File('${dir.path}/$name');
    try {
      if (options.format == ExportFormat.pdf) {
        final pdf = pw.Document(compress: true);
        for (var i = 0; i < pages.length; i++) {
          // Pages render one at a time in an isolate; only the encoded page returns.
          final page = pages[i]; final rendered = await Isolate.run(() => ImagePipeline.renderPage(page, options));
          final format = switch (options.pageSize) {
            PageSize.a4 => PdfPageFormat.a4, PageSize.letter => PdfPageFormat.letter,
            // Fit-image pages match the image at the chosen DPI so physical size stays sensible.
            PageSize.auto => PdfPageFormat(rendered.width * 72 / options.dpi, rendered.height * 72 / options.dpi),
          };
          pdf.addPage(pw.Page(pageFormat: format, margin: pw.EdgeInsets.zero, build: (_) => pw.Center(child: pw.Image(pw.MemoryImage(rendered.bytes), fit: pw.BoxFit.contain))));
          onProgress?.call(i + 1, pages.length);
        }
        await output.writeAsBytes(await pdf.save(), flush: true);
      } else if (pages.length == 1) {
        final page = pages.single; final rendered = await Isolate.run(() => ImagePipeline.renderPage(page, options));
        onProgress?.call(1, 1);
        await output.writeAsBytes(rendered.bytes, flush: true);
      } else {
        // A ZIP makes every page explicit, so no share target can silently drop pages.
        final archive = Archive();
        for (var i = 0; i < pages.length; i++) {
          final page = pages[i]; final bytes = (await Isolate.run(() => ImagePipeline.renderPage(page, options))).bytes;
          archive.addFile(ArchiveFile('page_${(i + 1).toString().padLeft(3, '0')}.${options.format.name}', bytes.length, bytes));
          onProgress?.call(i + 1, pages.length);
        }
        await output.writeAsBytes(ZipEncoder().encode(archive), flush: true);
      }
    } on FormatException { throw const ExportException(ExportFailure.unreadableImage); }
    on FileSystemException catch (e) {
      try { if (await output.exists()) await output.delete(); } on FileSystemException { /* Best effort. */ }
      // ENOSPC is 28 on Linux/Android and iOS.
      throw ExportException(e.osError?.errorCode == 28 ? ExportFailure.storageFull : ExportFailure.unknown);
    }
    return GeneratedExport(output.path, await output.length(), mimeFor(ext), name);
  }

  /// A filename safe for every destination: no path separators or reserved characters.
  static String safeFilename(String input, String ext) {
    final base = input.trim().replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').replaceAll(RegExp(r'\.(pdf|zip|jpe?g|png)$', caseSensitive: false), '').replaceAll(RegExp(r'^\.+'), '');
    return '${base.isEmpty ? 'Scan' : base}.$ext';
  }

  /// Deletes temporary exports older than [maxAge]. Saved documents live elsewhere and are never touched.
  static Future<int> removeExpired(Directory dir, {Duration maxAge = const Duration(days: 1)}) async {
    if (!await dir.exists()) return 0;
    final cutoff = DateTime.now().subtract(maxAge); var removed = 0;
    await for (final item in dir.list()) {
      if ((await item.stat()).modified.isBefore(cutoff)) { try { await item.delete(recursive: true); removed++; } on FileSystemException { /* Retry next time. */ } }
    }
    return removed;
  }

  /// Removes every temporary export and incoming hand-off file.
  static Future<void> clearTemporaryFiles() async {
    final temp = await getTemporaryDirectory();
    for (final name in [_folder, 'incoming', 'qr_work', 'previews']) {
      final dir = Directory('${temp.path}/$name'); if (await dir.exists()) { try { await dir.delete(recursive: true); } on FileSystemException { /* Retry next time. */ } }
    }
  }
}
