import 'package:flutter_test/flutter_test.dart';
import 'package:scan_and_open/core/models.dart';

void main() {
  test('draft round trip preserves page order, rotation, filter, and originals', () {
    final draft = DocumentDraft(id: 'd', title: 'Three pages', updatedAt: DateTime.utc(2026), pages: const [
      DocumentPage(id: '3', originalPath: '/3.jpg'),
      DocumentPage(id: '1', originalPath: '/1.jpg', rotation: 90),
      DocumentPage(id: '2', originalPath: '/2.jpg', filter: PageFilter.grayscale),
    ]);
    final restored = DocumentDraft.decode(draft.encode());
    expect(restored.pages.map((p) => p.id), ['3', '1', '2']);
    expect(restored.pages[1].rotation, 90);
    expect(restored.pages[2].filter, PageFilter.grayscale);
    expect(restored.pages[0].originalPath, '/3.jpg');
  });
  test('copying a draft does not mutate its previous page list', () {
    final original = DocumentDraft(id: 'd', title: 'x', updatedAt: DateTime.utc(2026), pages: const [DocumentPage(id: 'a', originalPath: '/a')]);
    final changed = original.copyWith(pages: [...original.pages, const DocumentPage(id: 'b', originalPath: '/b')]);
    expect(original.pages, hasLength(1)); expect(changed.pages, hasLength(2));
  });
  test('crop survives a save/restore round trip; old drafts without crop still load', () {
    const page = DocumentPage(id: 'p', originalPath: '/p.jpg', crop: CropQuad([.1, .1, .9, .1, .9, .9, .1, .9]));
    final restored = DocumentDraft.decode(DocumentDraft(id: 'd', title: 't', updatedAt: DateTime.utc(2026), pages: const [page]).encode());
    expect(restored.pages.single.crop!.points, page.crop!.points);
    final legacy = DocumentDraft.decode('{"id":"d","title":"t","updatedAt":"2026-01-01T00:00:00.000Z","pages":[{"id":"p","originalPath":"/p.jpg"}]}');
    expect(legacy.pages.single.crop, isNull);
  });
  test('default title follows Scan_YYYY-MM-DD_HHMM', () {
    expect(DocumentDraft.defaultTitle(DateTime(2026, 9, 26, 10, 5)), 'Scan_2026-09-26_1005');
  });
  test('export defaults persist and fall back safely', () {
    const custom = ExportOptions(format: ExportFormat.png, pageSize: PageSize.letter, resolution: OutputResolution.high, dpi: 300, jpegQuality: 60);
    final restored = ExportOptions.fromJson(custom.toJson());
    expect([restored.format, restored.pageSize, restored.resolution, restored.dpi, restored.jpegQuality], [ExportFormat.png, PageSize.letter, OutputResolution.high, 300, 60]);
    expect(ExportOptions.fromJson('garbage').format, ExportFormat.pdf);
  });
}
