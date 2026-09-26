import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

class DraftStore {
  Future<Directory> get _root async { final base = await getApplicationDocumentsDirectory(); return Directory('${base.path}/documents')..createSync(recursive: true); }
  Future<void> save(DocumentDraft draft) async { final root = await _root; final file = File('${root.path}/${draft.id}/draft.json'); file.parent.createSync(recursive: true); await file.writeAsString(draft.encode(), flush: true); }
  Future<List<DocumentDraft>> loadAll() async {
    final root = await _root; final out = <DocumentDraft>[];
    await for (final entity in root.list()) { final file = File('${entity.path}/draft.json'); if (await file.exists()) { try { out.add(DocumentDraft.decode(await file.readAsString())); } on FormatException { /* Keep a corrupt draft on disk for recovery. */ } } }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt)); return out;
  }
  Future<String> preserveOriginal(String draftId, String source, String pageId) async {
    final root = await _root; final extension = source.contains('.') ? source.substring(source.lastIndexOf('.')) : '.jpg';
    final target = File('${root.path}/$draftId/originals/$pageId$extension'); target.parent.createSync(recursive: true); await File(source).copy(target.path); return target.path;
  }
  Future<void> delete(String id) async { final root = await _root; final dir = Directory('${root.path}/$id'); if (await dir.exists()) await dir.delete(recursive: true); }
}
