import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_strings.dart';
import '../core/draft_store.dart';
import '../core/models.dart';
import '../core/preview_cache.dart';
import '../core/settings.dart';
import 'capture.dart';
import 'crop_screen.dart';
import 'export_screen.dart';

/// Localized, human-readable filter name.
String filterLabel(S s, PageFilter f) => switch (f) {
  PageFilter.original => s.t('Original', 'ต้นฉบับ'),
  PageFilter.enhanced => s.t('Enhanced', 'ปรับปรุงสี'),
  PageFilter.grayscale => s.t('Grayscale', 'โทนเทา'),
  PageFilter.blackAndWhite => s.t('Black & white', 'ขาวดำ'),
};

/// Shows the rendered page (rotation, crop and filter applied), exactly as it will export.
class PagePreview extends StatelessWidget {
  const PagePreview({required this.page, this.fit = BoxFit.contain, this.thumbnail = false, super.key});
  final DocumentPage page; final BoxFit fit; final bool thumbnail;
  @override Widget build(BuildContext context) => FutureBuilder<String>(
    key: ValueKey(page.editKey), future: PreviewCache.instance.preview(page),
    builder: (context, snap) {
      // If the edited preview can't be rendered, show the untouched original so the page is never blank.
      if (snap.hasError) {
        return RotatedBox(quarterTurns: page.rotation ~/ 90, child: Image.file(File(page.originalPath), fit: fit, cacheWidth: thumbnail ? 200 : 1600, excludeFromSemantics: true,
        errorBuilder: (context, error, stack) => Center(child: Icon(Icons.broken_image_outlined, size: thumbnail ? 24 : 48, semanticLabel: S.of(context).t('This page could not be displayed', 'ไม่สามารถแสดงหน้านี้')))));
      }
      if (!snap.hasData) return Center(child: SizedBox.square(dimension: thumbnail ? 20 : 36, child: const CircularProgressIndicator(strokeWidth: 3)));
      return Image.file(File(snap.data!), fit: fit, cacheWidth: thumbnail ? 200 : null, gaplessPlayback: true, excludeFromSemantics: true);
    });
}

class DocumentEditor extends StatefulWidget {
  const DocumentEditor({required this.initial, required this.settings, this.cropFirst = false, super.key});
  final DocumentDraft initial; final AppSettings settings;
  /// Opens the corner editor for the first page, e.g. after a plain camera photo.
  final bool cropFirst;
  @override State<DocumentEditor> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends State<DocumentEditor> {
  late DocumentDraft draft; int selected = 0; bool busy = false; final store = DraftStore();
  @override void initState() { super.initState(); draft = widget.initial; if (widget.cropFirst && draft.pages.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _crop()); }

  /// Every change is written to disk immediately so drafts survive the app closing.
  Future<void> _persist(List<DocumentPage> pages, {String? title}) async {
    draft = draft.copyWith(pages: pages, title: title); await store.save(draft);
    if (mounted) setState(() => selected = pages.isEmpty ? 0 : selected.clamp(0, pages.length - 1));
  }
  Future<void> _busy(Future<void> Function() work) async { setState(() => busy = true); try { await work(); } finally { if (mounted) setState(() => busy = false); } }
  S get s => S.of(context);
  void _say(String message) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))); }

  Future<void> _add(Captured captured) async {
    if (captured.isEmpty) return;
    await _busy(() async {
      final pages = [...draft.pages];
      for (final path in captured.paths) { final id = const Uuid().v4(); pages.add(DocumentPage(id: id, originalPath: await store.preserveOriginal(draft.id, path, id, consumeSource: captured.temporary))); }
      selected = pages.length - 1; await _persist(pages);
    });
    if (captured.needsCrop) await _crop();
  }

  Future<void> _replace() async {
    final choice = await showModalBottomSheet<String>(context: context, showDragHandle: true, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.document_scanner_outlined), title: Text(s.t('Rescan this page', 'สแกนหน้านี้ใหม่')), onTap: () => Navigator.pop(c, 'scan')),
      ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(s.t('Retake with camera', 'ถ่ายใหม่ด้วยกล้อง')), onTap: () => Navigator.pop(c, 'photo')),
      ListTile(leading: const Icon(Icons.image_outlined), title: Text(s.t('Choose an image', 'เลือกรูปภาพ')), onTap: () => Navigator.pop(c, 'import')),
    ])));
    if (choice == null || !mounted) return;
    final Captured captured;
    switch (choice) {
      case 'scan': captured = await scanDocument(context, single: true);
      case 'photo': captured = await takePhoto(context);
      default: captured = await importImages(context, single: true);
    }
    if (captured.isEmpty || !mounted) return;
    final old = draft.pages[selected];
    await _busy(() async {
      final path = await store.preserveOriginal(draft.id, captured.paths.first, const Uuid().v4(), consumeSource: captured.temporary);
      // A fresh capture starts with no rotation or crop; the chosen filter is kept.
      await _persist([...draft.pages]..[selected] = DocumentPage(id: old.id, originalPath: path, filter: old.filter));
      await store.deleteOriginal(old.originalPath);
    });
    if (captured.needsCrop) await _crop();
  }

  Future<void> _crop() async {
    if (draft.pages.isEmpty) return;
    final page = draft.pages[selected];
    String source;
    try { source = await PreviewCache.instance.preview(page, forCropping: true); }
    on Object { _say(s.t('This page could not be opened. Try replacing it.', 'เปิดหน้านี้ไม่ได้ ลองแทนที่หน้านี้')); return; }
    if (!mounted) return;
    final quad = await Navigator.push<CropQuad>(context, MaterialPageRoute(builder: (_) => CropScreen(imagePath: source, initial: page.crop, title: s.t('Adjust corners', 'ปรับมุม'), confirmLabel: s.t('Apply crop', 'ใช้การครอบตัด'))));
    if (quad != null) await _persist([...draft.pages]..[selected] = quad.isFull ? page.copyWith(clearCrop: true) : page.copyWith(crop: quad));
  }

  void _move(int delta) { final target = selected + delta; if (target < 0 || target >= draft.pages.length) return; final pages = [...draft.pages]; final page = pages.removeAt(selected); pages.insert(target, page); selected = target; _persist(pages); }

  Future<void> _deletePage() async {
    final removed = draft.pages[selected]; final index = selected;
    await _persist([...draft.pages]..removeAt(selected));
    if (!mounted) return;
    // Undo keeps the original on disk until the message is gone.
    final result = await ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('Page deleted', 'ลบหน้าแล้ว')), action: SnackBarAction(label: s.t('Undo', 'เลิกทำ'), onPressed: () {}))).closed;
    if (result == SnackBarClosedReason.action) { selected = index.clamp(0, draft.pages.length); await _persist([...draft.pages]..insert(selected, removed)); }
    else { await store.deleteOriginal(removed.originalPath); }
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: draft.title);
    final value = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: Text(s.t('Rename document', 'เปลี่ยนชื่อเอกสาร')),
      content: TextField(controller: controller, autofocus: true, onSubmitted: (v) => Navigator.pop(c, v)),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(MaterialLocalizations.of(c).cancelButtonLabel)), FilledButton(onPressed: () => Navigator.pop(c, controller.text), child: Text(MaterialLocalizations.of(c).okButtonLabel))]));
    controller.dispose();
    if (value != null && value.trim().isNotEmpty) await _persist(draft.pages, title: value.trim());
  }

  @override Widget build(BuildContext context) {
    final page = draft.pages.isEmpty ? null : draft.pages[selected];
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Semantics(button: true, hint: s.t('Rename', 'เปลี่ยนชื่อ'), child: InkWell(onTap: _rename, child: Text(draft.title, overflow: TextOverflow.ellipsis))), actions: [
        IconButton(tooltip: s.t('Rename', 'เปลี่ยนชื่อ'), onPressed: _rename, icon: const Icon(Icons.edit_outlined)),
        Padding(padding: const EdgeInsets.only(right: 8), child: FilledButton.tonalIcon(onPressed: draft.pages.isEmpty || busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExportScreen(draft: draft, defaults: widget.settings.exportDefaults))), icon: const Icon(Icons.ios_share), label: Text(s.t('Export', 'ส่งออก')))),
      ]),
      body: Column(children: [
        if (busy) const LinearProgressIndicator(),
        Expanded(child: page == null
          ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.note_add_outlined, size: 64, color: scheme.primary), const SizedBox(height: 16),
              Text(s.t('Add a page by scanning or importing images.', 'เพิ่มหน้าโดยการสแกนหรือนำเข้ารูปภาพ'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 20),
              Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
                FilledButton.icon(onPressed: () async => _add(await scanDocument(context)), icon: const Icon(Icons.document_scanner_outlined), label: Text(s.t('Scan', 'สแกน'))),
                OutlinedButton.icon(onPressed: () async => _add(await importImages(context)), icon: const Icon(Icons.add_photo_alternate_outlined), label: Text(s.t('Import', 'นำเข้า'))),
              ]),
            ])))
          : Semantics(label: s.t('Page ${selected + 1} of ${draft.pages.length}. Pinch to zoom.', 'หน้า ${selected + 1} จาก ${draft.pages.length} บีบเพื่อซูม'),
              child: InteractiveViewer(minScale: 1, maxScale: 6, child: Padding(padding: const EdgeInsets.all(12), child: PagePreview(page: page))))),
        if (draft.pages.isNotEmpty) SizedBox(height: 104, child: ReorderableListView.builder(
          scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), itemCount: draft.pages.length,
          onReorderItem: (oldIndex, newIndex) { final pages = [...draft.pages]; final p = pages.removeAt(oldIndex); pages.insert(newIndex, p); selected = newIndex; _persist(pages); },
          itemBuilder: (_, i) => Semantics(key: ValueKey(draft.pages[i].id), selected: i == selected, button: true,
            label: s.t('Page ${i + 1} of ${draft.pages.length}', 'หน้า ${i + 1} จาก ${draft.pages.length}'), hint: s.t('Long press and drag to reorder', 'กดค้างแล้วลากเพื่อจัดลำดับ'),
            child: InkWell(onTap: () => setState(() => selected = i), child: Container(width: 72, margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(border: Border.all(color: i == selected ? scheme.primary : scheme.outlineVariant, width: i == selected ? 3 : 1), borderRadius: BorderRadius.circular(6)),
              child: Stack(fit: StackFit.expand, children: [ClipRRect(borderRadius: BorderRadius.circular(4), child: PagePreview(page: draft.pages[i], fit: BoxFit.cover, thumbnail: true)),
                Positioned(right: 2, bottom: 2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 5), decoration: BoxDecoration(color: scheme.surface.withValues(alpha: .85), borderRadius: BorderRadius.circular(4)), child: ExcludeSemantics(child: Text('${i + 1}', style: Theme.of(context).textTheme.labelSmall))))])))),
        )),
        SafeArea(top: false, child: SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Row(children: [
          _tool(Icons.document_scanner_outlined, s.t('Scan pages', 'สแกนหน้า'), busy ? null : () async => _add(await scanDocument(context))),
          _tool(Icons.add_photo_alternate_outlined, s.t('Import images', 'นำเข้ารูปภาพ'), busy ? null : () async => _add(await importImages(context))),
          _tool(Icons.crop, s.t('Crop / adjust corners', 'ครอบตัด / ปรับมุม'), page == null || busy ? null : _crop),
          _tool(Icons.rotate_right, s.t('Rotate', 'หมุน'), page == null || busy ? null : () => _persist([...draft.pages]..[selected] = page.rotated())),
          PopupMenuButton<PageFilter>(enabled: page != null && !busy, tooltip: s.t('Color mode', 'โหมดสี'), icon: const Icon(Icons.tune), initialValue: page?.filter,
            onSelected: (v) => _persist([...draft.pages]..[selected] = page!.copyWith(filter: v)),
            itemBuilder: (_) => PageFilter.values.map((f) => CheckedPopupMenuItem(value: f, checked: f == page?.filter, child: Text(filterLabel(s, f)))).toList()),
          _tool(Icons.find_replace, s.t('Replace page', 'แทนที่หน้า'), page == null || busy ? null : _replace),
          _tool(Icons.arrow_back, s.t('Move earlier', 'ย้ายไปก่อน'), page == null || busy || selected == 0 ? null : () => _move(-1)),
          _tool(Icons.arrow_forward, s.t('Move later', 'ย้ายไปหลัง'), page == null || busy || selected == draft.pages.length - 1 ? null : () => _move(1)),
          _tool(Icons.delete_outline, s.t('Delete page', 'ลบหน้า'), page == null || busy ? null : _deletePage),
        ]))),
      ]),
    );
  }
  Widget _tool(IconData icon, String label, VoidCallback? action) => IconButton(onPressed: action, tooltip: label, icon: Icon(icon), constraints: const BoxConstraints(minWidth: 52, minHeight: 52));
}
