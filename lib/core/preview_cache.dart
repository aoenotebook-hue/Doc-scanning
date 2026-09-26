import 'dart:io';
import 'dart:isolate';
import 'package:path_provider/path_provider.dart';
import 'image_pipeline.dart';
import 'models.dart';

/// Screen-sized renders of pages, generated off the UI thread and cached by edit state,
/// so previews match the export without decoding full-resolution originals on screen.
class PreviewCache {
  PreviewCache._();
  static final instance = PreviewCache._();
  final _inFlight = <String, Future<String>>{};

  Future<String> preview(DocumentPage page, {bool forCropping = false}) {
    final key = '${forCropping ? 'crop' : 'page'}|${page.editKey}';
    return _inFlight.putIfAbsent(key, () async {
      final dir = '${(await getTemporaryDirectory()).path}/previews';
      final target = '$dir/${_hash(key)}.jpg';
      if (!await File(target).exists()) {
        await Isolate.run(() => ImagePipeline.writePreview(page, target, forCropping: forCropping));
      }
      return target;
    }).catchError((Object e) { _inFlight.remove(key); throw e; });
  }

  /// FNV-1a: stable across runs, unlike String.hashCode.
  static String _hash(String value) {
    var h = 0xcbf29ce484222325;
    for (final unit in value.codeUnits) { h ^= unit; h = (h * 0x100000001b3) & 0x7fffffffffffffff; }
    return h.toRadixString(16);
  }
}
