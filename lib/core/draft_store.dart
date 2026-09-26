import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

/// Returns the lowercase extension of [path]'s file name (e.g. `.jpg`), or `.jpg`
/// when the name has none. Directory names are never considered.
String imageExtension(String path) {
  final name = path.split(RegExp(r'[/\\]')).last;
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return '.jpg';
  final ext = name.substring(dot).toLowerCase();
  return RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(ext) ? ext : '.jpg';
}

/// iOS gives the app a new container path after reinstalls and some updates, so a stored
/// absolute path can go stale. Originals always live in `<root>/<draftId>/originals/`,
/// so a missing file is looked up there by name.
String relocateOriginal(String storedPath, String root, String draftId) {
  if (File(storedPath).existsSync()) return storedPath;
  final name = storedPath.split(RegExp(r'[/\\]')).last;
  final candidate = '$root/$draftId/originals/$name';
  return File(candidate).existsSync() ? candidate : storedPath;
}

class DraftStore {
  Future<Directory> get _root async { final base = await getApplicationDocumentsDirectory(); return Directory('${base.path}/documents')..createSync(recursive: true); }
  Future<void> save(DocumentDraft draft) async { final root = await _root; final file = File('${root.path}/${draft.id}/draft.json'); file.parent.createSync(recursive: true); await file.writeAsString(draft.encode(), flush: true); }
  Future<List<DocumentDraft>> loadAll() async {
    final root = await _root; final out = <DocumentDraft>[];
    await for (final entity in root.list()) { final file = File('${entity.path}/draft.json'); if (await file.exists()) { try {
      final draft = DocumentDraft.decode(await file.readAsString());
      out.add(draft.copyWith(pages: [for (final p in draft.pages) p.copyWith(originalPath: relocateOriginal(p.originalPath, root.path, draft.id))]).withUpdatedAt(draft.updatedAt));
    } on FormatException { /* Keep a corrupt draft on disk for recovery. */ } } }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt)); return out;
  }
  /// Copies [source] into private storage. Temporary hand-off files (scanner output,
  /// shared images) are removed afterwards when [consumeSource] is true.
  Future<String> preserveOriginal(String draftId, String source, String pageId, {bool consumeSource = false}) async {
    final root = await _root;
    final target = File('${root.path}/$draftId/originals/$pageId${imageExtension(source)}'); target.parent.createSync(recursive: true); await File(source).copy(target.path);
    if (consumeSource) { try { await File(source).delete(); } on FileSystemException { /* Temporary directory is cleaned by the OS. */ } }
    return target.path;
  }
  Future<void> deleteOriginal(String path) async { final file = File(path); if (await file.exists()) await file.delete(); }
  Future<void> delete(String id) async { final root = await _root; final dir = Directory('${root.path}/$id'); if (await dir.exists()) await dir.delete(recursive: true); }
}
