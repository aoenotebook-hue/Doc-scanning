import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_strings.dart';
import '../core/draft_store.dart';
import '../core/models.dart';
import '../core/platform_bridge.dart';
import 'capture.dart';
import 'qr_decode.dart';
import '../core/settings.dart';
import 'document_editor.dart';
import 'qr_input.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget { const HomeScreen({required this.settings, super.key}); final AppSettings settings; @override State<HomeScreen> createState() => _HomeScreenState(); }
class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final store = DraftStore(); List<DocumentDraft> drafts = []; bool loading = true; bool _importingShared = false;
  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); unawaited(_load()); unawaited(_shared()); }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) unawaited(_shared()); }
  Future<void> _load() async {
    final all = await store.loadAll();
    // A draft left without pages (e.g. every page deleted) is discarded rather than listed.
    for (final d in all.where((d) => d.pages.isEmpty)) { await store.delete(d.id); }
    drafts = all.where((d) => d.pages.isNotEmpty).toList(); if (mounted) setState(() => loading = false);
  }
  Future<void> _shared() async {
    if (_importingShared) return; _importingShared = true;
    try {
      final paths = await PlatformBridge().consumeSharedImages();
      if (paths.isEmpty || !mounted) return;
      final s = S.of(context);
      final choice = await showModalBottomSheet<String>(context: context, showDragHandle: true, isDismissible: false, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 8), child: Text(s.t(paths.length == 1 ? 'You shared 1 image' : 'You shared ${paths.length} images', 'คุณแชร์รูปภาพ ${paths.length} รูป'), style: Theme.of(c).textTheme.titleMedium)),
        ListTile(minTileHeight: 64, leading: const Icon(Icons.description_outlined), title: Text(s.t('Make a document', 'สร้างเอกสาร')), onTap: () => Navigator.pop(c, 'doc')),
        ListTile(minTileHeight: 64, leading: const Icon(Icons.qr_code_scanner), title: Text(s.t('Read QR code', 'อ่านคิวอาร์โค้ด')), subtitle: paths.length > 1 ? Text(s.t('Uses the first image', 'ใช้รูปภาพแรก')) : null, onTap: () => Navigator.pop(c, 'qr')),
        ListTile(minTileHeight: 64, leading: const Icon(Icons.close), title: Text(MaterialLocalizations.of(c).cancelButtonLabel), onTap: () => Navigator.pop(c)),
      ])));
      if (!mounted) return;
      if (choice == 'doc') { await _newWith(paths, consume: true); }
      else if (choice == 'qr') { await decodeImageAndShow(context, paths.first); }
    } finally { _importingShared = false; }
  }
  Future<void> _newWith(List<String> paths, {bool consume = false, bool cropFirst = false}) async {
    final id = const Uuid().v4(); final pages = <DocumentPage>[];
    for (final path in paths) { final pageId = const Uuid().v4(); pages.add(DocumentPage(id: pageId, originalPath: await store.preserveOriginal(id, path, pageId, consumeSource: consume))); }
    final now = DateTime.now();
    final draft = DocumentDraft(id: id, title: DocumentDraft.defaultTitle(now), updatedAt: now, pages: pages);
    if (pages.isNotEmpty) await store.save(draft);
    if (!mounted) return; await _open(draft, cropFirst: cropFirst);
  }
  Future<void> _open(DocumentDraft draft, {bool cropFirst = false}) async { await Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentEditor(initial: draft, settings: widget.settings, cropFirst: cropFirst))); await _load(); }
  Future<void> _scan() async { final c = await scanDocument(context); if (!c.isEmpty) await _newWith(c.paths, consume: c.temporary, cropFirst: c.needsCrop); }
  Future<void> _import() async { final c = await importImages(context); if (!c.isEmpty) await _newWith(c.paths); }
  Future<void> _delete(DocumentDraft d) async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text(s.t('Delete "${d.title}"?', 'ลบ "${d.title}" หรือไม่')), content: Text(s.t('This cannot be undone.', 'ไม่สามารถย้อนกลับได้')),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(MaterialLocalizations.of(c).cancelButtonLabel)), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.t('Delete', 'ลบ')))]));
    if (confirmed == true) { await store.delete(d.id); await _load(); }
  }
  @override Widget build(BuildContext context) { final s = S.of(context); return Scaffold(
    appBar: AppBar(title: Text(s.t('Scan & Open','สแกนและเปิด')), actions: [IconButton(tooltip: s.t('Settings','การตั้งค่า'), onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(settings: widget.settings))); await _load(); }, icon: const Icon(Icons.settings_outlined))]),
    body: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(20), children: [
      Text(s.t('Private tools for paper and QR codes', 'เครื่องมือส่วนตัวสำหรับเอกสารและคิวอาร์'), style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 20),
      _HomeAction(icon: Icons.document_scanner_outlined, title: s.t('Scan Document','สแกนเอกสาร'), subtitle: s.t('Camera with automatic edge detection','กล้องพร้อมตรวจจับขอบอัตโนมัติ'), onTap: _scan), const SizedBox(height: 12),
            _HomeAction(icon: Icons.qr_code_scanner, title: s.t('Read QR','อ่านคิวอาร์'), subtitle: s.t('Camera, photos, files, and screenshots','กล้อง รูปภาพ ไฟล์ และภาพหน้าจอ'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrInputScreen()))), const SizedBox(height: 28),
      Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _import, icon: const Icon(Icons.add_photo_alternate_outlined), label: Text(s.t('Or make a document from existing images','หรือสร้างเอกสารจากรูปภาพที่มีอยู่')))), const SizedBox(height: 16),
      Semantics(header: true, child: Text(s.t('Recent documents','เอกสารล่าสุด'), style: Theme.of(context).textTheme.titleLarge)), const SizedBox(height: 8),
      if (loading) const Center(child: CircularProgressIndicator()) else if (drafts.isEmpty) Text(s.t('Your recent documents will appear here.','เอกสารล่าสุดจะแสดงที่นี่')) else ...drafts.map((d) => Card(child: ListTile(minVerticalPadding: 14, leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(width: 44, height: 56, child: PagePreview(page: d.pages.first, thumbnail: true, fit: BoxFit.cover))), title: Text(d.title), subtitle: Text('${s.t(d.pages.length == 1 ? '1 page' : '${d.pages.length} pages', '${d.pages.length} หน้า')} · ${MaterialLocalizations.of(context).formatShortDate(d.updatedAt)}'),
        trailing: IconButton(tooltip: s.t('Delete document', 'ลบเอกสาร'), icon: const Icon(Icons.delete_outline), onPressed: () => _delete(d)), onTap: () => _open(d)))),
    ])),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _newWith(const []), icon: const Icon(Icons.add), label: Text(s.t('New draft','ฉบับร่างใหม่'))),
  ); }
}
class _HomeAction extends StatelessWidget { const _HomeAction({required this.icon, required this.title, required this.subtitle, required this.onTap}); final IconData icon; final String title, subtitle; final VoidCallback onTap; @override Widget build(BuildContext context) => Card(elevation: 1, child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: Semantics(button: true, label: title, child: Padding(padding: const EdgeInsets.all(22), child: Row(children: [Icon(icon, size: 44), const SizedBox(width: 18), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 4), Text(subtitle)])), const Icon(Icons.chevron_right)]))))); }
