import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../app_strings.dart';
import '../core/export_service.dart';
import '../core/models.dart';
import '../core/platform_bridge.dart';
import 'document_editor.dart';

String formatBytes(int bytes) => bytes < 1048576 ? '${(bytes / 1024).toStringAsFixed(0)} KB' : '${(bytes / 1048576).toStringAsFixed(1)} MB';

String pageSizeLabel(S s, PageSize v) => switch (v) { PageSize.a4 => 'A4', PageSize.letter => 'Letter', PageSize.auto => s.t('Fit image', 'ตามขนาดภาพ') };
String resolutionLabel(S s, OutputResolution v) => switch (v) {
  OutputResolution.small => s.t('Small · 1280 px', 'เล็ก · 1280 px'),
  OutputResolution.standard => s.t('Standard · 2048 px', 'มาตรฐาน · 2048 px'),
  OutputResolution.high => s.t('High · 3508 px', 'สูง · 3508 px'),
};

enum _Stage { idle, preparing, saving }

class ExportScreen extends StatefulWidget {
  const ExportScreen({required this.draft, required this.defaults, super.key});
  final DocumentDraft draft; final ExportOptions defaults;
  @override State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  late ExportOptions options = widget.defaults;
  late final TextEditingController name = TextEditingController(text: widget.draft.title);
  late final Set<String> chosen = {for (final p in widget.draft.pages) p.id};
  final service = ExportService();
  int? estimate; int _estimateToken = 0; GeneratedExport? last; _Stage stage = _Stage.idle; int done = 0;

  List<DocumentPage> get pages => widget.draft.pages.where((p) => chosen.contains(p.id)).toList();
  String get extension => ExportService.extensionFor(options, pages.length);
  S get s => S.of(context);

  @override void initState() { super.initState(); _estimate(); }
  @override void dispose() { name.dispose(); super.dispose(); }

  void _update(ExportOptions next) { setState(() { options = next; last = null; }); _estimate(); }
  Future<void> _estimate() async {
    final token = ++_estimateToken; final value = await service.estimate(pages, options);
    if (mounted && token == _estimateToken) setState(() => estimate = value);
  }

  void _say(String message, {SnackBarAction? action}) { if (mounted) ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message), action: action, duration: const Duration(seconds: 6))); }

  Future<GeneratedExport?> _generate() async {
    setState(() { stage = _Stage.preparing; done = 0; });
    try {
      final out = await service.generate(pages, options, name.text, onProgress: (d, _) { if (mounted) setState(() => done = d); });
      if (mounted) setState(() => last = out);
      return out;
    } on ExportException catch (e) {
      _say(switch (e.reason) {
        ExportFailure.storageFull => s.t('Not enough storage to create the file. Free up space or choose a smaller resolution.', 'พื้นที่ไม่พอสำหรับสร้างไฟล์ โปรดเพิ่มพื้นที่หรือเลือกความละเอียดที่เล็กลง'),
        ExportFailure.unreadableImage => s.t('One of the pages could not be read. Replace or delete it, then try again.', 'อ่านบางหน้าไม่ได้ โปรดแทนที่หรือลบหน้านั้นแล้วลองอีกครั้ง'),
        ExportFailure.noPages => s.t('Select at least one page.', 'โปรดเลือกอย่างน้อยหนึ่งหน้า'),
        ExportFailure.unknown => s.t('The file could not be created. Your document is unchanged.', 'สร้างไฟล์ไม่ได้ เอกสารของคุณไม่เปลี่ยนแปลง'),
      }, action: SnackBarAction(label: s.t('Retry', 'ลองใหม่'), onPressed: _save));
      return null;
    } finally { if (mounted) setState(() => stage = _Stage.idle); }
  }

  Future<void> _save() async {
    final out = await _generate(); if (out == null || !mounted) return;
    setState(() => stage = _Stage.saving);
    try {
      final saved = await PlatformBridge().saveAs(out.path, out.mime, out.filename);
      if (!mounted) return;
      // Only a confirmed write to the chosen destination counts as saved.
      _say(saved == true
        ? s.t('Saved "${out.filename}" (${formatBytes(out.bytes)})', 'บันทึก "${out.filename}" แล้ว (${formatBytes(out.bytes)})')
        : s.t('Not saved. Your document is still here.', 'ยังไม่ได้บันทึก เอกสารของคุณยังอยู่'));
    } on PlatformException {
      _say(s.t('That location could not save the file. Check free space and access, or choose another location.', 'ตำแหน่งนั้นบันทึกไฟล์ไม่ได้ โปรดตรวจสอบพื้นที่และสิทธิ์ หรือเลือกตำแหน่งอื่น'),
        action: SnackBarAction(label: s.t('Try again', 'ลองอีกครั้ง'), onPressed: _save));
    } finally { if (mounted) setState(() => stage = _Stage.idle); }
  }

  Future<void> _share() async {
    final out = await _generate(); if (out == null || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    try {
      final result = await SharePlus.instance.share(ShareParams(files: [XFile(out.path, mimeType: out.mime)], fileNameOverrides: [out.filename], subject: out.filename,
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size));
      if (result.status == ShareResultStatus.success) _say(s.t('Shared "${out.filename}"', 'แชร์ "${out.filename}" แล้ว'));
    } on PlatformException { _say(s.t('Sharing is unavailable right now. Try Save As instead.', 'ขณะนี้แชร์ไม่ได้ โปรดใช้บันทึกเป็นแทน')); }
  }

  Widget _section(String title, List<Widget> children) => Padding(padding: const EdgeInsets.only(top: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleMedium)), const SizedBox(height: 8), ...children]));
  Widget _note(String text) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(text, style: Theme.of(context).textTheme.bodySmall));

  @override Widget build(BuildContext context) {
    final pdf = options.format == ExportFormat.pdf, fixedPdf = pdf && options.pageSize != PageSize.auto, total = pages.length;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('Export', 'ส่งออก'))),
      body: AbsorbPointer(absorbing: stage != _Stage.idle, child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
        TextField(controller: name, onChanged: (_) => setState(() => last = null), decoration: InputDecoration(labelText: s.t('File name', 'ชื่อไฟล์'), suffixText: '.$extension')),
        _section(s.t('Pages', 'หน้า'), [
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilterChip(label: Text(s.t('All ${widget.draft.pages.length}', 'ทั้งหมด ${widget.draft.pages.length}')), selected: chosen.length == widget.draft.pages.length,
              onSelected: (v) { setState(() { v ? chosen.addAll(widget.draft.pages.map((p) => p.id)) : chosen.clear(); last = null; }); _estimate(); }),
            for (var i = 0; i < widget.draft.pages.length; i++) FilterChip(
              avatar: SizedBox(width: 24, height: 32, child: PagePreview(page: widget.draft.pages[i], thumbnail: true, fit: BoxFit.cover)),
              label: Text('${i + 1}'), tooltip: s.t('Page ${i + 1}', 'หน้า ${i + 1}'), selected: chosen.contains(widget.draft.pages[i].id),
              onSelected: (v) { setState(() { v ? chosen.add(widget.draft.pages[i].id) : chosen.remove(widget.draft.pages[i].id); last = null; }); _estimate(); }),
          ]),
          if (total == 0) _note(s.t('Select at least one page.', 'โปรดเลือกอย่างน้อยหนึ่งหน้า')),
        ]),
        _section(s.t('File type', 'ชนิดไฟล์'), [
          SegmentedButton<ExportFormat>(segments: [
            ButtonSegment(value: ExportFormat.pdf, label: const Text('PDF'), icon: const Icon(Icons.picture_as_pdf_outlined)),
            const ButtonSegment(value: ExportFormat.jpg, label: Text('JPG')), const ButtonSegment(value: ExportFormat.png, label: Text('PNG'))],
            selected: {options.format}, onSelectionChanged: (v) => _update(options.copyWith(format: v.first))),
          _note(pdf ? s.t('All selected pages in one PDF.', 'รวมทุกหน้าที่เลือกในไฟล์ PDF เดียว')
            : total > 1 ? s.t('One image per page, packed together in a ZIP file so no page is left out.', 'หนึ่งภาพต่อหน้า รวมในไฟล์ ZIP เพื่อให้ครบทุกหน้า') : s.t('One image file.', 'ไฟล์ภาพหนึ่งไฟล์')),
        ]),
        if (pdf) _section(s.t('1 · Page size', '1 · ขนาดหน้า'), [
          SegmentedButton<PageSize>(segments: [for (final v in PageSize.values) ButtonSegment(value: v, label: Text(pageSizeLabel(s, v)))], selected: {options.pageSize}, onSelectionChanged: (v) => _update(options.copyWith(pageSize: v.first))),
          _note(s.t('Pages are centred and never stretched.', 'หน้าจะอยู่กึ่งกลางและไม่ถูกยืด')),
        ]),
        _section(pdf ? s.t('2 · Resolution', '2 · ความละเอียด') : s.t('1 · Resolution', '1 · ความละเอียด'), [
          if (fixedPdf) SegmentedButton<int>(segments: const [ButtonSegment(value: 150, label: Text('150 DPI')), ButtonSegment(value: 200, label: Text('200 DPI')), ButtonSegment(value: 300, label: Text('300 DPI'))], selected: {options.dpi}, onSelectionChanged: (v) => _update(options.copyWith(dpi: v.first)))
          else SegmentedButton<OutputResolution>(segments: [for (final v in OutputResolution.values) ButtonSegment(value: v, label: Text(resolutionLabel(s, v), textAlign: TextAlign.center))], selected: {options.resolution}, onSelectionChanged: (v) => _update(options.copyWith(resolution: v.first))),
          if (pdf && !fixedPdf) ExpansionTile(tilePadding: EdgeInsets.zero, title: Text(s.t('Advanced: PDF page scale', 'ขั้นสูง: สเกลหน้า PDF')), children: [
            SegmentedButton<int>(segments: const [ButtonSegment(value: 150, label: Text('150 DPI')), ButtonSegment(value: 200, label: Text('200 DPI')), ButtonSegment(value: 300, label: Text('300 DPI'))], selected: {options.dpi}, onSelectionChanged: (v) => _update(options.copyWith(dpi: v.first))),
            _note(s.t('Sets the printed size of each fitted page.', 'กำหนดขนาดเมื่อพิมพ์ของแต่ละหน้า')),
          ]),
          _note(s.t('Longest side up to ${options.maxSide} px. A higher setting cannot add detail that the original photo does not have.', 'ด้านยาวสุดไม่เกิน ${options.maxSide} px การตั้งค่าที่สูงขึ้นไม่สามารถเพิ่มรายละเอียดที่ไม่มีในภาพต้นฉบับ')),
        ]),
        _section(pdf ? s.t('3 · Compression', '3 · การบีบอัด') : s.t('2 · Compression', '2 · การบีบอัด'), [
          if (options.format == ExportFormat.png) Text(s.t('PNG is lossless, so it has no quality setting. To make it smaller, choose a lower resolution.', 'PNG ไม่สูญเสียคุณภาพจึงไม่มีการตั้งค่าคุณภาพ หากต้องการไฟล์เล็กลงให้เลือกความละเอียดที่ต่ำลง'))
          else ...[
            Row(children: [Text(s.t('Smaller file', 'ไฟล์เล็ก')), Expanded(child: Slider(value: options.jpegQuality.toDouble(), min: 45, max: 95, divisions: 10,
              label: s.t('Quality ${options.jpegQuality}%', 'คุณภาพ ${options.jpegQuality}%'), semanticFormatterCallback: (v) => s.t('Quality ${v.round()} percent', 'คุณภาพ ${v.round()} เปอร์เซ็นต์'),
              onChanged: (v) => setState(() => options = options.copyWith(jpegQuality: v.round())), onChangeEnd: (_) { last = null; _estimate(); })), Text(s.t('Sharper', 'คมชัด'))]),
            _note(s.t('JPEG quality ${options.jpegQuality}%', 'คุณภาพ JPEG ${options.jpegQuality}%')),
          ],
        ]),
        const SizedBox(height: 24),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Semantics(liveRegion: true, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.t('Estimated size (approximate): ', 'ขนาดโดยประมาณ: ') + (estimate == null || total == 0 ? '—' : '~${formatBytes(estimate!)}'), style: Theme.of(context).textTheme.titleMedium),
          if (last != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.t('Created file: ${last!.filename} · ${formatBytes(last!.bytes)}', 'ไฟล์ที่สร้าง: ${last!.filename} · ${formatBytes(last!.bytes)}'))),
        ])))),
        const SizedBox(height: 20),
        if (stage != _Stage.idle) Semantics(liveRegion: true, child: Column(children: [
          LinearProgressIndicator(value: stage == _Stage.preparing && total > 0 ? done / total : null), const SizedBox(height: 8),
          Text(stage == _Stage.preparing ? s.t('Preparing page ${done < total ? done + 1 : total} of $total…', 'กำลังเตรียมหน้า ${done < total ? done + 1 : total} จาก $total…') : s.t('Waiting for you to choose a location…', 'กำลังรอให้คุณเลือกตำแหน่ง…')),
        ]))
        else Row(children: [
          Expanded(child: SizedBox(height: 52, child: FilledButton.icon(onPressed: total == 0 ? null : _save, icon: const Icon(Icons.save_alt), label: Text(s.t('Save As…', 'บันทึกเป็น…'))))),
          const SizedBox(width: 12),
          Expanded(child: SizedBox(height: 52, child: OutlinedButton.icon(onPressed: total == 0 ? null : _share, icon: const Icon(Icons.share), label: Text(s.t('Share', 'แชร์'))))),
        ]),
        _note(s.t('Available locations depend on the apps and accounts set up on this device.', 'ตำแหน่งที่ใช้ได้ขึ้นอยู่กับแอปและบัญชีที่ตั้งค่าไว้ในอุปกรณ์นี้')),
      ])),
    );
  }
}
