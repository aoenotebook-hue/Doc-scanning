import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_and_open/core/draft_store.dart';

void main() {
  test('originals are found again after the app container path changes', () {
    final root = Directory.systemTemp.createTempSync('docs'); addTearDown(() => root.deleteSync(recursive: true));
    final moved = File('${root.path}/d1/originals/p1.jpg')..createSync(recursive: true);
    // Path saved by a previous install whose container no longer exists.
    const stale = '/var/mobile/Containers/Data/Application/OLD-UUID/Documents/documents/d1/originals/p1.jpg';
    expect(relocateOriginal(stale, root.path, 'd1'), moved.path);
    expect(relocateOriginal(moved.path, root.path, 'd1'), moved.path);
    expect(relocateOriginal('/nowhere/missing.jpg', root.path, 'd1'), '/nowhere/missing.jpg');
  });
}
