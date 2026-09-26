import 'dart:io';
import 'package:flutter/material.dart';
import '../app_strings.dart';
import '../core/models.dart';

/// Lets the user drag four corners over [imagePath]; pops with the resulting [CropQuad].
class CropScreen extends StatefulWidget {
  const CropScreen({required this.imagePath, this.initial, required this.title, required this.confirmLabel, super.key});
  final String imagePath;
  final CropQuad? initial;
  final String title;
  final String confirmLabel;
  @override State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  late List<Offset> corners;
  Size? imageSize;

  @override void initState() {
    super.initState();
    final q = widget.initial ?? CropQuad.full;
    corners = [for (var i = 0; i < 4; i++) Offset(q.x(i), q.y(i))];
    final stream = FileImage(File(widget.imagePath)).resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener((info, _) { if (mounted) setState(() => imageSize = Size(info.image.width.toDouble(), info.image.height.toDouble())); stream.removeListener(listener); });
    stream.addListener(listener);
  }

  CropQuad get quad => CropQuad([for (final c in corners) ...[c.dx, c.dy]]);

  @override Widget build(BuildContext context) {
    final s = S.of(context);
    final names = [s.t('Top-left corner', 'มุมซ้ายบน'), s.t('Top-right corner', 'มุมขวาบน'), s.t('Bottom-right corner', 'มุมขวาล่าง'), s.t('Bottom-left corner', 'มุมซ้ายล่าง')];
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        TextButton(onPressed: () => setState(() => corners = [for (var i = 0; i < 4; i++) Offset(CropQuad.full.x(i), CropQuad.full.y(i))]), child: Text(s.t('Reset', 'รีเซ็ต'))),
      ]),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Text(s.t('Drag each corner to the edge of the document.', 'ลากแต่ละมุมไปที่ขอบของเอกสาร'), textAlign: TextAlign.center)),
        Expanded(child: imageSize == null ? const Center(child: CircularProgressIndicator()) : LayoutBuilder(builder: (context, box) {
          // Fit the image inside the available space, leaving room for the handles.
          const pad = 28.0;
          final scale = [ (box.maxWidth - pad * 2) / imageSize!.width, (box.maxHeight - pad * 2) / imageSize!.height ].reduce((a, b) => a < b ? a : b);
          final w = imageSize!.width * scale, h = imageSize!.height * scale;
          final origin = Offset((box.maxWidth - w) / 2, (box.maxHeight - h) / 2);
          Offset toScreen(Offset n) => origin + Offset(n.dx * w, n.dy * h);
          return Stack(children: [
            Positioned(left: origin.dx, top: origin.dy, width: w, height: h, child: Image.file(File(widget.imagePath), fit: BoxFit.fill, excludeFromSemantics: true)),
            Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _QuadPainter([for (final c in corners) toScreen(c)], Theme.of(context).colorScheme.primary)))),
            for (var i = 0; i < 4; i++) Positioned(
              left: toScreen(corners[i]).dx - 24, top: toScreen(corners[i]).dy - 24,
              child: Semantics(label: names[i], hint: s.t('Drag to adjust', 'ลากเพื่อปรับ'),
                child: GestureDetector(
                  onPanUpdate: (d) => setState(() {
                    final next = corners[i] + Offset(d.delta.dx / w, d.delta.dy / h);
                    corners[i] = Offset(next.dx.clamp(0.0, 1.0), next.dy.clamp(0.0, 1.0));
                  }),
                  child: Container(width: 48, height: 48, alignment: Alignment.center, color: Colors.transparent,
                    child: Container(width: 26, height: 26, decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary.withValues(alpha: .35), border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3)))),
                ))),
          ]);
        })),
        Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(
          onPressed: imageSize == null ? null : () => Navigator.pop(context, quad), icon: const Icon(Icons.check), label: Text(widget.confirmLabel)))),
      ])),
    );
  }
}

class _QuadPainter extends CustomPainter {
  _QuadPainter(this.points, this.color);
  final List<Offset> points; final Color color;
  @override void paint(Canvas canvas, Size size) {
    final path = Path()..addPolygon(points, true);
    canvas.drawPath(Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), path), Paint()..color = Colors.black45);
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.5);
  }
  @override bool shouldRepaint(_QuadPainter old) => old.points != points || old.color != color;
}
