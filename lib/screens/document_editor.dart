import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_strings.dart';
import '../core/draft_store.dart';
import '../core/models.dart';
import '../core/platform_bridge.dart';
import 'export_screen.dart';

/// Localized, human-readable filter name.
String filterLabel(S s, PageFilter f) => switch (f) {
  PageFilter.original => s.t('Original', 'ต้นฉบับ'),
  PageFilter.enhanced => s.t('Enhanced', 'ปรับปรุง'),
  PageFilter.grayscale => s.t('Grayscale', 'ขาวดำเทา'),
  PageFilter.blackAndWhite => s.t('Black & white', 'ขาวดำ'),
};

/// Approximates the export filters on screen so the preview matches the output.
ColorFilter? previewFilter(PageFilter f) {
  const gray = <double>[.2126, .7152, .0722, 0, 0, .2126, .7152, .0722, 0, 0, .2126, .7152, .0722, 0, 0, 0, 0, 0, 1, 0];
  return switch (f) {
    PageFilter.original => null,
    PageFilter.grayscale => const ColorFilter.matrix(gray),
    PageFilter.blackAndWhite => const ColorFilter.matrix(<double>[
      5.3, 17.9, 1.8, 0, -3500, 5.3, 17.9, 1.8, 0, -3500, 5.3, 17.9, 1.8, 0, -3500, 0, 0, 0, 1, 0]),
    PageFilter.enhanced => const ColorFilter.matrix(<double>[
      1.14, 0, 0, 0, -17.9, 0, 1.14, 0, 0, -17.9, 0, 0, 1.14, 0, -17.9, 0, 0, 0, 1, 0]),
  };
}

Widget filtered(PageFilter f, Widget child) { final filter = previewFilter(f); return filter == null ? child : ColorFiltered(colorFilter: filter, child: child); }

class DocumentEditor extends StatefulWidget { const DocumentEditor({required this.initial, super.key}); final DocumentDraft initial; @override State<DocumentEditor> createState() => _DocumentEditorState(); }
class _DocumentEditorState extends State<DocumentEditor> {
  late DocumentDraft draft; int selected = 0; final store = DraftStore();
  @override void initState() { super.initState(); draft = widget.initial; }
  Future<void> _persist(List<DocumentPage> pages, {String? title}) async { draft = draft.copyWith(pages: pages, title: title); await store.save(draft); if (mounted) setState(() => selected = pages.isEmpty ? 0 : selected.clamp(0, pages.length - 1)); }
  Future<void> _addPaths(List<String> paths, {bool consume = false}) async {
    if (paths.isEmpty) return;
    final pages = [...draft.pages];
    for (final path in paths) { final id = const Uuid().v4(); pages.add(DocumentPage(id: id, originalPath: await store.preserveOriginal(draft.id, path, id, consumeSource: consume))); }
    selected = pages.length - 1; await _persist(pages);
  }
  Future<void> _import() async { final result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.image); if (result != null) await _addPaths(result.paths.whereType<String>().toList()); }
  Future<void> _scan() async {
    try { await _addPaths(await PlatformBridge().scanDocument(), consume: true); }
    on Exception { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of(context).t('Camera unavailable. You can import images.', 'ใช้กล้องไม่ได้ คุณสามารถนำเข้ารูปภาพได้')))); }
  }
  void _move(int delta) { final target = selected + delta; if (target < 0 || target >= draft.pages.length) return; final pages = [...draft.pages]; final page = pages.removeAt(selected); pages.insert(target, page); selected = target; _persist(pages); }
  Future<void> _deletePage() async { final pages = [...draft.pages]; final removed = pages.removeAt(selected); await _persist(pages); await store.deleteOriginal(removed.originalPath); }
  Future<void> _rename() async {
    final s = S.of(context); final controller = TextEditingController(text: draft.title);
    final value = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: Text(s.t('Rename document', 'เปลี่ยนชื่อเอกสาร')),
      content: TextField(controller: controller, autofocus: true, onSubmitted: (v) => Navigator.pop(c, v)),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(MaterialLocalizations.of(c).cancelButtonLabel)), FilledButton(onPressed: () => Navigator.pop(c, controller.text), child: Text(MaterialLocalizations.of(c).okButtonLabel))]));
    controller.dispose();
    if (value != null && value.trim().isNotEmpty) await _persist(draft.pages, title: value.trim());
  }
  @override Widget build(BuildContext context) { final s = S.of(context); final page = draft.pages.isEmpty ? null : draft.pages[selected]; return Scaffold(
    appBar: AppBar(title: InkWell(onTap: _rename, child: Text(draft.title, overflow: TextOverflow.ellipsis)), actions: [
      IconButton(tooltip: s.t('Rename', 'เปลี่ยนชื่อ'), onPressed: _rename, icon: const Icon(Icons.edit_outlined)),
      TextButton.icon(onPressed: draft.pages.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExportScreen(draft: draft))), icon: const Icon(Icons.ios_share), label: Text(s.t('Export','ส่งออก')))]),
    body: Column(children: [Expanded(child: page == null ? Center(child: Text(s.t('Add a scan or import one or more images.','เพิ่มภาพสแกนหรือนำเข้ารูปภาพ'))) : InteractiveViewer(minScale: .5, maxScale: 5, child: Center(child: RotatedBox(quarterTurns: page.rotation ~/ 90, child: filtered(page.filter, Image.file(File(page.originalPath), fit: BoxFit.contain, semanticLabel: s.t('Selected document page','หน้าเอกสารที่เลือก'))))))),
      if (draft.pages.isNotEmpty) SizedBox(height: 92, child: ReorderableListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), itemCount: draft.pages.length, onReorderItem: (oldIndex, newIndex) { final pages = [...draft.pages]; final p = pages.removeAt(oldIndex); pages.insert(newIndex, p); selected = newIndex; _persist(pages); }, itemBuilder: (_, i) => InkWell(key: ValueKey(draft.pages[i].id), onTap: () => setState(() => selected = i), child: Container(width: 72, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(border: Border.all(color: i == selected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3)), child: RotatedBox(quarterTurns: draft.pages[i].rotation ~/ 90, child: filtered(draft.pages[i].filter, Image.file(File(draft.pages[i].originalPath), fit: BoxFit.cover, cacheWidth: 200))))))),
      SafeArea(top: false, child: SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), child: Row(children: [
        _tool(Icons.document_scanner, s.t('Scan','สแกน'), _scan), _tool(Icons.add_photo_alternate_outlined, s.t('Import','นำเข้า'), _import),
        _tool(Icons.rotate_right, s.t('Rotate','หมุน'), page == null ? null : () => _persist([...draft.pages]..[selected] = page.copyWith(rotation: (page.rotation + 90) % 360))),
        PopupMenuButton<PageFilter>(enabled: page != null, tooltip: s.t('Filter','ฟิลเตอร์'), icon: const Icon(Icons.tune), initialValue: page?.filter, onSelected: (v) => _persist([...draft.pages]..[selected] = page!.copyWith(filter: v)), itemBuilder: (_) => PageFilter.values.map((f) => PopupMenuItem(value: f, child: Text(filterLabel(s, f)))).toList()),
        _tool(Icons.arrow_back, s.t('Move left','ย้ายซ้าย'), page == null || selected == 0 ? null : () => _move(-1)), _tool(Icons.arrow_forward, s.t('Move right','ย้ายขวา'), page == null || selected == draft.pages.length - 1 ? null : () => _move(1)),
        _tool(Icons.delete_outline, s.t('Delete page','ลบหน้า'), page == null ? null : _deletePage),
      ])))
    ])); }
  Widget _tool(IconData icon, String label, VoidCallback? action) => IconButton(onPressed: action, tooltip: label, icon: Icon(icon), constraints: const BoxConstraints(minWidth: 52, minHeight: 52));
}
