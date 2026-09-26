import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_and_open/core/models.dart';
import 'package:scan_and_open/screens/export_screen.dart';

void main() {
  final draft = DocumentDraft(id: 'd', title: 'Scan_2026-09-26_1005', updatedAt: DateTime(2026), pages: const [
    DocumentPage(id: 'a', originalPath: '/missing/a.jpg'), DocumentPage(id: 'b', originalPath: '/missing/b.jpg')]);
  Future<void> open(WidgetTester tester, ExportOptions defaults) async {
    tester.view.physicalSize = const Size(1200, 3000); addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(localizationsDelegates: GlobalMaterialLocalizations.delegates, home: ExportScreen(draft: draft, defaults: defaults)));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('defaults to PDF, A4 and the document name, with separated sections', (tester) async {
    await open(tester, const ExportOptions());
    expect(find.widgetWithText(TextField, 'Scan_2026-09-26_1005'), findsOneWidget);
    expect(find.text('.pdf'), findsOneWidget);
    for (final title in ['1 · Page size', '2 · Resolution', '3 · Compression']) { expect(find.text(title), findsOneWidget); }
    expect(find.text('200 DPI'), findsOneWidget);
    expect(find.textContaining('Estimated size (approximate)'), findsOneWidget);
    expect(find.textContaining('cannot add detail'), findsOneWidget);
  });

  testWidgets('PNG has no quality slider and explains how to shrink it', (tester) async {
    await open(tester, const ExportOptions(format: ExportFormat.png));
    expect(find.byType(Slider), findsNothing);
    expect(find.textContaining('PNG is lossless'), findsOneWidget);
    expect(find.text('.zip'), findsOneWidget); // Two pages → every page in one ZIP.
    expect(find.text('1 · Page size'), findsNothing);
  });

  testWidgets('deselecting pages updates the output and blocks empty exports', (tester) async {
    await open(tester, const ExportOptions(format: ExportFormat.jpg));
    expect(find.byType(Slider), findsOneWidget);
    await tester.tap(find.text('All 2')); await tester.pump();
    expect(find.text('Select at least one page.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.ancestor(of: find.text('Save As…'), matching: find.byType(FilledButton))).onPressed, isNull);
    await tester.tap(find.text('1')); await tester.pump();
    expect(find.text('.jpg'), findsOneWidget); // One page → a single image, no ZIP.
  });
}
