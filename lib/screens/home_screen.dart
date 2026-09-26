import 'dart:async';
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
  final store = DraftStore(); List<DocumentDraft> drafts = []; bool loading = true;
  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); unawaited(_load()); unawaited(_shared()); }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) unawaited(_shared()); }
  Future<void> _load() async { drafts = await store.loadAll(); if (mounted) setState(() => loading = false); }
  Future<void> _shared() async { final paths = await PlatformBridge().consumeSharedImages(); if (paths.isNotEmpty && mounted) await _newWith(paths); }
  Future<void> _newWith(List<String> paths) async {
    final id = const Uuid().v4(); final pages = <DocumentPage>[];
    for (final path in paths) { final pageId = const Uuid().v4(); pages.add(DocumentPage(id: pageId, originalPath: await store.preserveOriginal(id, path, pageId))); }
    final now = DateTime.now(); final draft = DocumentDraft(id: id, title: 'Scan_${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}_${now.hour.toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')}', updatedAt: now, pages: pages);
    await store.save(draft); if (!mounted) return; await Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentEditor(initial: draft))); await _load();
  }
  Future<void> _scan() async { try { final paths = await PlatformBridge().scanDocument(); if (paths.isNotEmpty) await _newWith(paths); } on Exception { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of(context).t('Camera scanning is unavailable. Import images instead.', 'ไม่สามารถใช้กล้องสแกนได้ โปรดนำเข้ารูปภาพแทน')))); } }
  @override Widget build(BuildContext context) { final s = S.of(context); return Scaffold(
    appBar: AppBar(title: Text(s.t('Scan & Open','สแกนและเปิด')), actions: [IconButton(tooltip: s.t('Settings','การตั้งค่า'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(settings: widget.settings))), icon: const Icon(Icons.settings_outlined))]),
    body: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(20), children: [
      Text(s.t('Private tools for paper and QR codes', 'เครื่องมือส่วนตัวสำหรับเอกสารและคิวอาร์'), style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 20),
      _HomeAction(icon: Icons.document_scanner_outlined, title: s.t('Scan Document','สแกนเอกสาร'), subtitle: s.t('Capture pages or import images','ถ่ายภาพหรือนำเข้ารูปภาพ'), onTap: _scan), const SizedBox(height: 12),
      _HomeAction(icon: Icons.qr_code_scanner, title: s.t('Read QR','อ่านคิวอาร์'), subtitle: s.t('Camera, photos, files, and screenshots','กล้อง รูปภาพ ไฟล์ และภาพหน้าจอ'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrInputScreen()))), const SizedBox(height: 28),
      Text(s.t('Recent documents','เอกสารล่าสุด'), style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8),
      if (loading) const Center(child: CircularProgressIndicator()) else if (drafts.isEmpty) Text(s.t('Your recent documents will appear here.','เอกสารล่าสุดจะแสดงที่นี่')) else ...drafts.map((d) => Card(child: ListTile(minVerticalPadding: 14, leading: const Icon(Icons.description_outlined), title: Text(d.title), subtitle: Text(s.t('${d.pages.length} pages','${d.pages.length} หน้า')), onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentEditor(initial: d))); await _load(); }))),
    ])),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _newWith(const []), icon: const Icon(Icons.add), label: Text(s.t('New draft','ฉบับร่างใหม่'))),
  ); }
}
class _HomeAction extends StatelessWidget { const _HomeAction({required this.icon, required this.title, required this.subtitle, required this.onTap}); final IconData icon; final String title, subtitle; final VoidCallback onTap; @override Widget build(BuildContext context) => Card(elevation: 1, child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: Semantics(button: true, label: title, child: Padding(padding: const EdgeInsets.all(22), child: Row(children: [Icon(icon, size: 44), const SizedBox(width: 18), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 4), Text(subtitle)])), const Icon(Icons.chevron_right)]))))); }
