import 'dart:convert';

enum PageFilter { original, enhanced, grayscale, blackAndWhite }
enum ExportFormat { pdf, jpg, png }
enum PageSize { a4, letter, auto }
enum OutputResolution { small, standard, high }

class DocumentPage {
  const DocumentPage({required this.id, required this.originalPath, this.rotation = 0, this.filter = PageFilter.original});
  final String id;
  final String originalPath;
  final int rotation;
  final PageFilter filter;

  DocumentPage copyWith({int? rotation, PageFilter? filter}) => DocumentPage(
    id: id, originalPath: originalPath, rotation: rotation ?? this.rotation, filter: filter ?? this.filter);
  Map<String, Object> toJson() => {'id': id, 'originalPath': originalPath, 'rotation': rotation, 'filter': filter.name};
  factory DocumentPage.fromJson(Map<String, dynamic> value) => DocumentPage(
    id: value['id'] as String, originalPath: value['originalPath'] as String,
    rotation: value['rotation'] as int? ?? 0,
    filter: PageFilter.values.byName(value['filter'] as String? ?? 'original'));
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
}
