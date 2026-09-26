import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_strings.dart';
import '../core/draft_store.dart';
import '../core/models.dart';
import '../core/platform_bridge.dart';
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
    try { final paths = await PlatformBridge().consumeSharedImages(); if (paths.isNotEmpty && mounted) await _newWith(paths, consume: true); } finally { _importingShared = false; }
  }
  Future<void> _newWith(List<String> paths, {bool consume = false}) async {
    final id = const Uuid().v4(); final pages = <DocumentPage>[];
    for (final path in paths) { final pageId = const Uuid().v4(); pages.add(DocumentPage(id: pageId, originalPath: await store.preserveOriginal(id, path, pageId, consumeSource: consume))); }
    final now = DateTime.now(); String two(int v) => v.toString().padLeft(2, '0');
    final draft = DocumentDraft(id: id, title: 'Scan_${now.year}-${two(now.month)}-${two(now.day)}_${two(now.hour)}${two(now.minute)}', updatedAt: now, pages: pages);
    if (pages.isNotEmpty) await store.save(draft);
    if (!mounted) return; await _open(draft);
  }
  Future<void> _open(DocumentDraft draft) async { await Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentEditor(initial: draft))); await _load(); }
  Future<void> _scan() async {
    try { final paths = await PlatformBridge().scanDocument(); if (paths.isNotEmpty) await _newWith(paths, consume: true); }
    on Exception { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of(context).t('Camera scanning is unavailable. Import images instead.', 'ไม่สามารถใช้กล้องสแกนได้ โปรดนำเข้ารูปภาพแทน')))); }
  }
  Future<void> _import() async { final result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.image); final paths = result?.paths.whereType<String>().toList() ?? const []; if (paths.isNotEmpty) await _newWith(paths); }
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
      _HomeAction(icon: Icons.document_scanner_outlined, title: s.t('Scan Document','สแกนเอกสาร'), subtitle: s.t('Capture pages with the camera','ถ่ายภาพเอกสารด้วยกล้อง'), onTap: _scan), const SizedBox(height: 12),
      _HomeAction(icon: Icons.add_photo_alternate_outlined, title: s.t('Import Images','นำเข้ารูปภาพ'), subtitle: s.t('Build a document from existing images','สร้างเอกสารจากรูปภาพที่มีอยู่'), onTap: _import), const SizedBox(height: 12),
      _HomeAction(icon: Icons.qr_code_scanner, title: s.t('Read QR','อ่านคิวอาร์'), subtitle: s.t('Camera, photos, files, and screenshots','กล้อง รูปภาพ ไฟล์ และภาพหน้าจอ'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrInputScreen()))), const SizedBox(height: 28),
      Text(s.t('Recent documents','เอกสารล่าสุด'), style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8),
      if (loading) const Center(child: CircularProgressIndicator()) else if (drafts.isEmpty) Text(s.t('Your recent documents will appear here.','เอกสารล่าสุดจะแสดงที่นี่')) else ...drafts.map((d) => Card(child: ListTile(minVerticalPadding: 14, leading: const Icon(Icons.description_outlined), title: Text(d.title), subtitle: Text(s.t(d.pages.length == 1 ? '1 page' : '${d.pages.length} pages', '${d.pages.length} หน้า')),
        trailing: IconButton(tooltip: s.t('Delete document', 'ลบเอกสาร'), icon: const Icon(Icons.delete_outline), onPressed: () => _delete(d)), onTap: () => _open(d)))),
    ])),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _newWith(const []), icon: const Icon(Icons.add), label: Text(s.t('New draft','ฉบับร่างใหม่'))),
  ); }
}
class _HomeAction extends StatelessWidget { const _HomeAction({required this.icon, required this.title, required this.subtitle, required this.onTap}); final IconData icon; final String title, subtitle; final VoidCallback onTap; @override Widget build(BuildContext context) => Card(elevation: 1, child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: Semantics(button: true, label: title, child: Padding(padding: const EdgeInsets.all(22), child: Row(children: [Icon(icon, size: 44), const SizedBox(width: 18), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 4), Text(subtitle)])), const Icon(Icons.chevron_right)]))))); }
