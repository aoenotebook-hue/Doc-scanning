import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'models.dart';

class DraftStore {
  static final RegExp _identifier = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final RegExp _extension = RegExp(r'^\.[A-Za-z0-9]{1,8}$');

  Future<Directory> get _root async {
    final base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}/documents')..createSync(recursive: true);
  }

  Future<void> save(DocumentDraft draft) async {
    _checkIdentifier(draft.id, 'draftId');
    final root = await _root;
    final file = File('${root.path}/${draft.id}/draft.json');
    file.parent.createSync(recursive: true);
    await file.writeAsString(draft.encode(), flush: true);
  }

  Future<List<DocumentDraft>> loadAll() async {
    final root = await _root;
    final output = <DocumentDraft>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final directoryId = entity.uri.pathSegments.where((part) => part.isNotEmpty).last;
      if (!_identifier.hasMatch(directoryId)) continue;
      final file = File('${entity.path}/draft.json');
      if (!await file.exists()) continue;
      try {
        final draft = DocumentDraft.decode(await file.readAsString());
        // Never let serialized content redirect future writes or deletion outside the
        // directory from which the draft was loaded.
        if (draft.id == directoryId && _identifier.hasMatch(draft.id)) output.add(draft);
      } on Object {
        // Preserve corrupt or newer-version drafts on disk for explicit recovery.
      }
    }
    output.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return output;
  }

  Future<String> preserveOriginal(String draftId, String source, String pageId) async {
    _checkIdentifier(draftId, 'draftId');
    _checkIdentifier(pageId, 'pageId');
    final root = await _root;
    final sourceName = source.split(Platform.pathSeparator).last;
    final dot = sourceName.lastIndexOf('.');
    final candidate = dot < 0 ? '' : sourceName.substring(dot);
    final extension = _extension.hasMatch(candidate) ? candidate.toLowerCase() : '.img';
    final target = File('${root.path}/$draftId/originals/$pageId$extension');
    target.parent.createSync(recursive: true);
    await File(source).copy(target.path);
    return target.path;
  }

  Future<void> delete(String id) async {
    _checkIdentifier(id, 'draftId');
    final root = await _root;
    final directory = Directory('${root.path}/$id');
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  static void _checkIdentifier(String value, String name) {
    if (!_identifier.hasMatch(value)) throw ArgumentError.value(value, name, 'Invalid identifier');
  }
}
