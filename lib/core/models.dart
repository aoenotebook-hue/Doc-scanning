import 'dart:convert';

enum PageFilter { original, enhanced, grayscale, blackAndWhite }
enum ExportFormat { pdf, jpg, png }
enum PageSize { a4, letter, auto }
enum OutputResolution { small, standard, high }

/// A crop quadrilateral in normalized (0–1) coordinates of the upright, rotated page:
/// top-left, top-right, bottom-right, bottom-left.
class CropQuad {
  const CropQuad(this.points);
  static const full = CropQuad([0, 0, 1, 0, 1, 1, 0, 1]);
  /// x0, y0, x1, y1, x2, y2, x3, y3 in TL, TR, BR, BL order.
  final List<double> points;
  bool get isFull => _same(points, full.points);
  double x(int i) => points[i * 2];
  double y(int i) => points[i * 2 + 1];

  /// The same quad after the page turns 90° clockwise. Corners keep their roles
  /// (TL stays the visual top-left), so the crop follows the page.
  CropQuad rotatedClockwise() {
    // A point (x, y) moves to (1 - y, x); the old bottom-left becomes the new top-left.
    final moved = [for (var i = 0; i < 4; i++) [1 - y(i), x(i)]];
    return CropQuad([...moved[3], ...moved[0], ...moved[1], ...moved[2]]);
  }

  List<double> toJson() => points;
  static CropQuad? fromJson(Object? value) => value is List && value.length == 8 ? CropQuad([for (final v in value) (v as num).toDouble()]) : null;
  static bool _same(List<double> a, List<double> b) { for (var i = 0; i < a.length; i++) { if ((a[i] - b[i]).abs() > 1e-6) return false; } return true; }
}

class DocumentPage {
  const DocumentPage({required this.id, required this.originalPath, this.rotation = 0, this.filter = PageFilter.original, this.crop});
  final String id;
  /// Untouched capture; every edit below is applied non-destructively at render time.
  final String originalPath;
  final int rotation;
  final PageFilter filter;
  final CropQuad? crop;

  DocumentPage copyWith({String? originalPath, int? rotation, PageFilter? filter, CropQuad? crop, bool clearCrop = false}) => DocumentPage(
    id: id, originalPath: originalPath ?? this.originalPath, rotation: rotation ?? this.rotation, filter: filter ?? this.filter,
    crop: clearCrop ? null : crop ?? this.crop);

  /// Rotates 90° clockwise, carrying the crop with the page.
  DocumentPage rotated() => copyWith(rotation: (rotation + 90) % 360, crop: crop?.rotatedClockwise());

  /// A stable key for every edit that changes the rendered pixels.
  String get editKey => '$originalPath|$rotation|${filter.name}|${crop?.points.map((v) => v.toStringAsFixed(4)).join(',') ?? 'full'}';

  Map<String, Object?> toJson() => {'id': id, 'originalPath': originalPath, 'rotation': rotation, 'filter': filter.name, if (crop != null) 'crop': crop!.toJson()};
  factory DocumentPage.fromJson(Map<String, dynamic> value) => DocumentPage(
    id: value['id'] as String, originalPath: value['originalPath'] as String,
    rotation: value['rotation'] as int? ?? 0,
    filter: PageFilter.values.byName(value['filter'] as String? ?? 'original'),
    crop: CropQuad.fromJson(value['crop']));
}

class DocumentDraft {
  const DocumentDraft({required this.id, required this.title, required this.updatedAt, required this.pages});
  final String id;
  final String title;
  final DateTime updatedAt;
  final List<DocumentPage> pages;
  DocumentDraft copyWith({String? title, List<DocumentPage>? pages}) => DocumentDraft(
    id: id, title: title ?? this.title, updatedAt: DateTime.now(), pages: pages ?? this.pages);
  String encode() => jsonEncode({'id': id, 'title': title, 'updatedAt': updatedAt.toIso8601String(), 'pages': pages.map((e) => e.toJson()).toList()});
  factory DocumentDraft.decode(String raw) { final j = jsonDecode(raw) as Map<String, dynamic>; return DocumentDraft(
    id: j['id'], title: j['title'], updatedAt: DateTime.parse(j['updatedAt']),
    pages: (j['pages'] as List).map((e) => DocumentPage.fromJson(e)).toList()); }

  /// Default document name, e.g. `Scan_2026-09-26_1005`.
  static String defaultTitle(DateTime now) { String two(int v) => v.toString().padLeft(2, '0'); return 'Scan_${now.year}-${two(now.month)}-${two(now.day)}_${two(now.hour)}${two(now.minute)}'; }
}

class ExportOptions {
  const ExportOptions({this.format = ExportFormat.pdf, this.pageSize = PageSize.a4,
    this.resolution = OutputResolution.standard, this.dpi = 200, this.jpegQuality = 82});
  final ExportFormat format;
  final PageSize pageSize;
  final OutputResolution resolution;
  final int dpi;
  final int jpegQuality;
  ExportOptions copyWith({ExportFormat? format, PageSize? pageSize, OutputResolution? resolution, int? dpi, int? jpegQuality}) => ExportOptions(
    format: format ?? this.format, pageSize: pageSize ?? this.pageSize, resolution: resolution ?? this.resolution,
    dpi: dpi ?? this.dpi, jpegQuality: jpegQuality ?? this.jpegQuality);

  /// Longest output side in pixels. Fixed PDF sheets derive it from paper size × DPI;
  /// everything else uses the pixel presets.
  int get maxSide => format == ExportFormat.pdf && pageSize != PageSize.auto
    ? ((pageSize == PageSize.a4 ? 11.69 : 11.0) * dpi).round()
    : switch (resolution) { OutputResolution.small => 1280, OutputResolution.standard => 2048, OutputResolution.high => 3508 };

  String toJson() => jsonEncode({'format': format.name, 'pageSize': pageSize.name, 'resolution': resolution.name, 'dpi': dpi, 'jpegQuality': jpegQuality});
  factory ExportOptions.fromJson(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return ExportOptions(format: ExportFormat.values.byName(j['format']), pageSize: PageSize.values.byName(j['pageSize']),
        resolution: OutputResolution.values.byName(j['resolution']), dpi: j['dpi'] as int, jpegQuality: j['jpegQuality'] as int);
    } on Object { return const ExportOptions(); }
  }
}
