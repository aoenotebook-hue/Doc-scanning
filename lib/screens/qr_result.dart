import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_strings.dart';
import '../core/link_policy.dart';

class QrResultScreen extends StatefulWidget {
  const QrResultScreen({required this.values, super.key});
  final List<String> values;
  @override State<QrResultScreen> createState() => _QrResultScreenState();
}

class _QrResultScreenState extends State<QrResultScreen> {
  int selected = 0;
  S get s => S.of(context);

  String _kind(LinkDecision d) => switch (d.action) {
    QrAction.web => s.t('Website', 'เว็บไซต์'), QrAction.email => s.t('Email', 'อีเมล'),
    QrAction.telephone => s.t('Phone number', 'หมายเลขโทรศัพท์'), QrAction.none => s.t('Text', 'ข้อความ') };
  IconData _icon(LinkDecision d) => switch (d.action) { QrAction.web => Icons.public, QrAction.email => Icons.email_outlined, QrAction.telephone => Icons.call_outlined, QrAction.none => Icons.notes };
  String _openLabel(LinkDecision d) => switch (d.action) { QrAction.email => s.t('Write email', 'เขียนอีเมล'), QrAction.telephone => s.t('Call', 'โทร'), _ => s.t('Open', 'เปิด') };

  Future<void> _open(LinkDecision d) async {
    // Only allowlisted http(s)/mailto/tel URIs reach the system; the OS picks the app.
    var ok = false;
    try { ok = await launchUrl(d.uri!, mode: LaunchMode.externalApplication); } on PlatformException { ok = false; }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('No app on this device could open it. You can copy it instead.', 'ไม่มีแอปในอุปกรณ์ที่เปิดได้ คุณคัดลอกแทนได้')),
        action: SnackBarAction(label: s.t('Copy', 'คัดลอก'), onPressed: () => Clipboard.setData(ClipboardData(text: widget.values[selected])))));
    }
  }

  @override Widget build(BuildContext context) {
    final value = widget.values[selected], d = LinkPolicy.inspect(value), text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('QR result', 'ผลคิวอาร์'))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (widget.values.length > 1) ...[
          Semantics(header: true, child: Text(s.t('${widget.values.length} codes found. Choose one:', 'พบ ${widget.values.length} โค้ด เลือกหนึ่งรายการ:'), style: text.titleMedium)),
          const SizedBox(height: 8),
          RadioGroup<int>(groupValue: selected, onChanged: (i) => setState(() => selected = i!), child: Card(child: Column(children: [
            for (var i = 0; i < widget.values.length; i++) RadioListTile<int>(value: i,
              secondary: Icon(_icon(LinkPolicy.inspect(widget.values[i]))),
              title: Text(LinkPolicy.inspect(widget.values[i]).hostname ?? widget.values[i], maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(_kind(LinkPolicy.inspect(widget.values[i])))),
          ]))),
          const SizedBox(height: 20),
        ],
        Row(children: [Icon(_icon(d), color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Text(_kind(d), style: text.labelLarge)]),
        const SizedBox(height: 12),
        if (d.hostname != null) ...[
          Text(s.t('Goes to', 'ไปยัง'), style: text.labelMedium),
          SelectableText(d.hostname!, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Card(color: Theme.of(context).colorScheme.secondaryContainer, child: Padding(padding: const EdgeInsets.all(12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline), const SizedBox(width: 10),
            Expanded(child: Text(s.t('Check that this is the site you expect before opening. A secure (https) link does not mean the site is trustworthy.', 'ตรวจสอบว่าเป็นเว็บไซต์ที่คุณต้องการก่อนเปิด ลิงก์ที่ปลอดภัย (https) ไม่ได้หมายความว่าเว็บไซต์น่าเชื่อถือ'))),
          ]))),
          const SizedBox(height: 12),
          ExpansionTile(tilePadding: EdgeInsets.zero, title: Text(s.t('Full address', 'ที่อยู่เต็ม')), initiallyExpanded: value.length < 80, children: [Align(alignment: Alignment.centerLeft, child: SelectableText(value))]),
        ] else ...[
          Text(s.t('Content', 'เนื้อหา'), style: text.labelMedium), const SizedBox(height: 4),
          SelectableText(value, style: text.bodyLarge),
          if (!d.canOpen) Padding(padding: const EdgeInsets.only(top: 12), child: Text(s.t('This content is shown as text only. You can copy or share it.', 'เนื้อหานี้แสดงเป็นข้อความเท่านั้น คุณคัดลอกหรือแชร์ได้'), style: text.bodySmall)),
        ],
        const SizedBox(height: 28),
        Wrap(spacing: 12, runSpacing: 12, children: [
          if (d.canOpen) SizedBox(height: 52, child: FilledButton.icon(onPressed: () => _open(d), icon: const Icon(Icons.open_in_new), label: Text(_openLabel(d)))),
          SizedBox(height: 52, child: OutlinedButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: value)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('Copied', 'คัดลอกแล้ว')))); }, icon: const Icon(Icons.copy), label: Text(s.t('Copy', 'คัดลอก')))),
          SizedBox(height: 52, child: OutlinedButton.icon(onPressed: () => SharePlus.instance.share(ShareParams(text: value)), icon: const Icon(Icons.share), label: Text(s.t('Share', 'แชร์')))),
        ]),
      ]),
    );
  }
}
