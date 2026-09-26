import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../app_strings.dart';
import '../core/platform_bridge.dart';

/// Images obtained for a document.
class Captured {
  const Captured(this.paths, {this.temporary = false, this.needsCrop = false});
  final List<String> paths;
  /// Hand-off files that may be deleted once copied into the draft.
  final bool temporary;
  /// Plain photos have no automatic edge detection, so the user sets corners manually.
  final bool needsCrop;
  bool get isEmpty => paths.isEmpty;
}

/// Opens the native document scanner (edge detection, auto crop, manual corners).
/// If it is unavailable, offers a plain camera photo or import instead.
Future<Captured> scanDocument(BuildContext context, {bool single = false}) async {
  try {
    final paths = await PlatformBridge().scanDocument();
    return Captured(single ? paths.take(1).toList() : paths, temporary: true);
  } on PlatformException {
    if (!context.mounted) return const Captured([]);
    final s = S.of(context);
    final choice = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: Text(s.t('Document scanner unavailable', 'ใช้ตัวสแกนเอกสารไม่ได้')),
      content: Text(s.t('You can take a regular photo and adjust the corners yourself, or import an existing image.', 'คุณสามารถถ่ายภาพปกติแล้วปรับมุมเอง หรือนำเข้ารูปภาพที่มีอยู่')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(MaterialLocalizations.of(c).cancelButtonLabel)),
        TextButton(onPressed: () => Navigator.pop(c, 'import'), child: Text(s.t('Import', 'นำเข้า'))),
        FilledButton(onPressed: () => Navigator.pop(c, 'photo'), child: Text(s.t('Take photo', 'ถ่ายภาพ'))),
      ]));
    if (!context.mounted) return const Captured([]);
    if (choice == 'photo') return takePhoto(context);
    if (choice == 'import') return importImages(context, single: single);
    return const Captured([]);
  }
}

/// Manual capture: a regular camera photo, followed by manual corner adjustment.
Future<Captured> takePhoto(BuildContext context) async {
  try {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera, requestFullMetadata: false);
    return photo == null ? const Captured([]) : Captured([photo.path], temporary: true, needsCrop: true);
  } on PlatformException {
    if (context.mounted) showPermissionHelp(context, S.of(context).t('Camera access is off. Allow it in Settings, or import an image instead.', 'การเข้าถึงกล้องปิดอยู่ โปรดอนุญาตในการตั้งค่า หรือนำเข้ารูปภาพแทน'));
    return const Captured([]);
  }
}

/// System picker: no broad photo-library permission is needed.
Future<Captured> importImages(BuildContext context, {bool single = false}) async {
  try {
    final result = await FilePicker.platform.pickFiles(allowMultiple: !single, type: FileType.image);
    return Captured(result?.paths.whereType<String>().toList() ?? const []);
  } on PlatformException {
    if (context.mounted) showPermissionHelp(context, S.of(context).t('Images could not be opened. Check photo access in Settings and try again.', 'เปิดรูปภาพไม่ได้ โปรดตรวจสอบสิทธิ์รูปภาพในการตั้งค่าแล้วลองอีกครั้ง'));
    return const Captured([]);
  }
}

void showPermissionHelp(BuildContext context, String message) =>
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 6)));
