import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_strings.dart';
import '../core/draft_store.dart';
import '../core/models.dart';
import '../core/platform_bridge.dart';
import 'export_screen.dart';

class DocumentEditor extends StatefulWidget { const DocumentEditor({required this.initial, super.key}); final DocumentDraft initial; @override State<DocumentEditor> createState() => _DocumentEditorState(); }
class _DocumentEditorState extends State<DocumentEditor> {
  late DocumentDraft draft; int selected = 0; final store = DraftStore();
  @override void initState() { super.initState(); draft = widget.initial; }
  Future<void> _persist(List<DocumentPage> pages) async { draft = draft.copyWith(pages: pages); await store.save(draft); if (mounted) setState(() => selected = pages.isEmpty ? 0 : selected.clamp(0, pages.length - 1)); }
  Future<void> _addPaths(List<String> paths) async { final pages = [...draft.pages]; for (final path in paths) { final id = const Uuid().v4(); pages.add(DocumentPage(id: id, originalPath: await store.preserveOriginal(draft.id, path, id))); } await _persist(pages); }
  Future<void> _import() async { final result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.image); if (result != null) await _addPaths(result.paths.whereType<String>().toList()); }
  Future<void> _scan() async { try { await _addPaths(await PlatformBridge().scanDocument()); } on Exception { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Camera unavailable. You can import images.'))); } }
  void _move(int delta) { if (draft.pages.isEmpty) return; final target = selected + delta; if (target < 0 || target >= draft.pages.length) return; final pages = [...draft.pages]; final page = pages.removeAt(selected); pages.insert(target, page); selected = target; _persist(pages); }
  @override Widget build(BuildContext context) { final s = S.of(context); final page = draft.pages.isEmpty ? null : draft.pages[selected]; return Scaffold(
    appBar: AppBar(title: Text(draft.title), actions: [TextButton.icon(onPressed: draft.pages.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExportScreen(draft: draft))), icon: const Icon(Icons.ios_share), label: Text(s.t('Export','ส่งออก')))]),
    body: Column(children: [Expanded(child: page == null ? Center(child: Text(s.t('Add a scan or import one or more images.','เพิ่มภาพสแกนหรือนำเข้ารูปภาพ'))) : InteractiveViewer(minScale: .5, maxScale: 5, child: Center(child: RotatedBox(quarterTurns: page.rotation ~/ 90, child: Image.file(File(page.originalPath), fit: BoxFit.contain, semanticLabel: s.t('Selected document page','หน้าเอกสารที่เลือก')))))),
      if (draft.pages.isNotEmpty) SizedBox(height: 92, child: ReorderableListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), itemCount: draft.pages.length, onReorder: (oldIndex,newIndex) { final pages=[...draft.pages]; if(newIndex>oldIndex)newIndex--; final p=pages.removeAt(oldIndex);pages.insert(newIndex,p);selected=newIndex;_persist(pages); }, itemBuilder: (_, i) => InkWell(key: ValueKey(draft.pages[i].id), onTap: () => setState(() => selected=i), child: Container(width: 72, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(border: Border.all(color: i==selected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3)), child: Image.file(File(draft.pages[i].originalPath), fit: BoxFit.cover))))),
      SafeArea(top: false, child: SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), child: Row(children: [
        _tool(Icons.document_scanner, s.t('Scan','สแกน'), _scan), _tool(Icons.add_photo_alternate_outlined,s.t('Import','นำเข้า'),_import),
        _tool(Icons.rotate_right,s.t('Rotate','หมุน'), page==null?null:()=>_persist([...draft.pages]..[selected]=page.copyWith(rotation:(page.rotation+90)%360))),
        PopupMenuButton<PageFilter>(enabled: page!=null, tooltip: s.t('Filter','ฟิลเตอร์'), icon: const Icon(Icons.tune), onSelected:(v)=>_persist([...draft.pages]..[selected]=page!.copyWith(filter:v)), itemBuilder:(_)=>PageFilter.values.map((f)=>PopupMenuItem(value:f,child:Text(f.name))).toList()),
        _tool(Icons.arrow_back,s.t('Move left','ย้ายซ้าย'),page==null?null:()=>_move(-1)), _tool(Icons.arrow_forward,s.t('Move right','ย้ายขวา'),page==null?null:()=>_move(1)),
        _tool(Icons.delete_outline,s.t('Delete','ลบ'),page==null?null:()=>_persist([...draft.pages]..removeAt(selected))),
      ])))
    ])); }
  Widget _tool(IconData icon,String label,VoidCallback? action)=>Semantics(button:true,label:label,child:IconButton(onPressed:action,tooltip:label,icon:Icon(icon),constraints:const BoxConstraints(minWidth:52,minHeight:52)));
}
