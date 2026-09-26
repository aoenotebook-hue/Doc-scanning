import 'package:flutter/material.dart';
import '../app_strings.dart';
import '../core/draft_store.dart';
import '../core/export_service.dart';
import '../core/models.dart';
import '../core/settings.dart';
import 'export_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.settings, super.key});
  final AppSettings settings;

  Future<bool> _confirm(BuildContext context, String title, String body, String action) async => await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    title: Text(title), content: Text(body),
    actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(MaterialLocalizations.of(c).cancelButtonLabel)), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(action))])) == true;

  @override Widget build(BuildContext context) {
    final s = S.of(context);
    Widget header(String text) => Padding(padding: const EdgeInsets.only(top: 28, bottom: 8), child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleLarge)));
    return Scaffold(appBar: AppBar(title: Text(s.t('Settings', 'การตั้งค่า'))), body: ListenableBuilder(listenable: settings, builder: (context, _) {
      final d = settings.exportDefaults;
      return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
        header(s.t('Appearance', 'การแสดงผล')),
        DropdownButtonFormField<String>(initialValue: settings.locale?.languageCode ?? 'system', decoration: InputDecoration(labelText: s.t('Language', 'ภาษา')),
          items: [DropdownMenuItem(value: 'system', child: Text(s.t('Device language', 'ตามภาษาของอุปกรณ์'))), const DropdownMenuItem(value: 'en', child: Text('English')), const DropdownMenuItem(value: 'th', child: Text('ไทย'))],
          onChanged: (v) => settings.setLocale(v == 'system' ? null : Locale(v!))),
        const SizedBox(height: 16),
        DropdownButtonFormField<ThemeMode>(initialValue: settings.themeMode, decoration: InputDecoration(labelText: s.t('Theme', 'ธีม')),
          items: ThemeMode.values.map((v) => DropdownMenuItem(value: v, child: Text(switch (v) { ThemeMode.system => s.t('Device setting', 'ตามอุปกรณ์'), ThemeMode.light => s.t('Light', 'สว่าง'), ThemeMode.dark => s.t('Dark', 'มืด') }))).toList(),
          onChanged: (v) => settings.setTheme(v!)),

        header(s.t('Default export', 'ค่าเริ่มต้นการส่งออก')),
        DropdownButtonFormField<ExportFormat>(initialValue: d.format, decoration: InputDecoration(labelText: s.t('File type', 'ชนิดไฟล์')),
          items: ExportFormat.values.map((v) => DropdownMenuItem(value: v, child: Text(v.name.toUpperCase()))).toList(), onChanged: (v) => settings.setExportDefaults(d.copyWith(format: v))),
        const SizedBox(height: 16),
        DropdownButtonFormField<PageSize>(initialValue: d.pageSize, decoration: InputDecoration(labelText: s.t('PDF page size', 'ขนาดหน้า PDF')),
          items: PageSize.values.map((v) => DropdownMenuItem(value: v, child: Text(pageSizeLabel(s, v)))).toList(), onChanged: (v) => settings.setExportDefaults(d.copyWith(pageSize: v))),
        const SizedBox(height: 16),
        DropdownButtonFormField<OutputResolution>(initialValue: d.resolution, decoration: InputDecoration(labelText: s.t('Image resolution', 'ความละเอียดภาพ')),
          items: OutputResolution.values.map((v) => DropdownMenuItem(value: v, child: Text(resolutionLabel(s, v)))).toList(), onChanged: (v) => settings.setExportDefaults(d.copyWith(resolution: v))),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(initialValue: d.dpi, decoration: InputDecoration(labelText: s.t('PDF resolution', 'ความละเอียด PDF')),
          items: const [150, 200, 300].map((v) => DropdownMenuItem(value: v, child: Text('$v DPI'))).toList(), onChanged: (v) => settings.setExportDefaults(d.copyWith(dpi: v))),
        TextButton(onPressed: () => settings.setExportDefaults(const ExportOptions()), child: Text(s.t('Restore defaults (PDF, A4, Standard)', 'คืนค่าเริ่มต้น (PDF, A4, มาตรฐาน)'))),

        header(s.t('Your data', 'ข้อมูลของคุณ')),
        ListTile(contentPadding: EdgeInsets.zero, minTileHeight: 56, leading: const Icon(Icons.cleaning_services_outlined), title: Text(s.t('Clear temporary files', 'ล้างไฟล์ชั่วคราว')),
          subtitle: Text(s.t('Removes generated exports and previews. Your documents are kept.', 'ลบไฟล์ส่งออกและภาพตัวอย่างที่สร้างไว้ เอกสารของคุณจะยังอยู่')),
          onTap: () async { await ExportService.clearTemporaryFiles(); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('Temporary files cleared', 'ล้างไฟล์ชั่วคราวแล้ว')))); }),
        ListTile(contentPadding: EdgeInsets.zero, minTileHeight: 56, leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error), title: Text(s.t('Delete all documents', 'ลบเอกสารทั้งหมด')),
          subtitle: Text(s.t('Deletes every document and its original photos from this device.', 'ลบเอกสารทั้งหมดและภาพต้นฉบับออกจากอุปกรณ์นี้')),
          onTap: () async {
            if (!await _confirm(context, s.t('Delete all documents?', 'ลบเอกสารทั้งหมดหรือไม่'), s.t('This cannot be undone. Files you already saved elsewhere are not affected.', 'ไม่สามารถย้อนกลับได้ ไฟล์ที่บันทึกไว้ที่อื่นแล้วจะไม่ได้รับผลกระทบ'), s.t('Delete', 'ลบ'))) return;
            final store = DraftStore(); for (final draft in await store.loadAll()) { await store.delete(draft.id); }
            await ExportService.clearTemporaryFiles();
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('All documents deleted', 'ลบเอกสารทั้งหมดแล้ว'))));
          }),

        header(s.t('Privacy', 'ความเป็นส่วนตัว')),
        Text(s.t(
          'Scanning, editing, file creation and QR reading all happen on this device. There is no account, no uploads and no content analytics. Documents and settings are kept in the app\'s private storage. QR results are not saved.\n\n'
          'Backups: on iPhone, app data may be included in your iCloud or computer backup, depending on your device settings. On Android, this app turns off system backup of its data.\n\n'
          'Opening a link, saving or sharing sends content only to the app or location you choose.',
          'การสแกน การแก้ไข การสร้างไฟล์ และการอ่านคิวอาร์ ทั้งหมดทำในอุปกรณ์นี้ ไม่มีบัญชี ไม่มีการอัปโหลด และไม่มีการวิเคราะห์เนื้อหา เอกสารและการตั้งค่าเก็บในพื้นที่ส่วนตัวของแอป ผลคิวอาร์จะไม่ถูกบันทึก\n\n'
          'การสำรองข้อมูล: บน iPhone ข้อมูลแอปอาจรวมอยู่ในการสำรองข้อมูล iCloud หรือคอมพิวเตอร์ตามการตั้งค่าอุปกรณ์ บน Android แอปนี้ปิดการสำรองข้อมูลของระบบ\n\n'
          'การเปิดลิงก์ บันทึก หรือแชร์ จะส่งเนื้อหาไปยังแอปหรือตำแหน่งที่คุณเลือกเท่านั้น')),
      ]);
    }));
  }
}
