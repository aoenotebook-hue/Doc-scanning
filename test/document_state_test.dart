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
}
