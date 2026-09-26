import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_and_open/screens/qr_result.dart';

Widget app(List<String> values, {Locale locale = const Locale('en')}) => MaterialApp(locale: locale, supportedLocales: const [Locale('en'), Locale('th')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates, home: QrResultScreen(values: values));

void main() {
  testWidgets('plain text is shown and never offers Open', (tester) async {
    await tester.pumpWidget(app(['Table 12 — Wi-Fi password: hunter2']));
    expect(find.text('Table 12 — Wi-Fi password: hunter2'), findsOneWidget);
    expect(find.text('Open'), findsNothing);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('executable schemes are displayed as text only', (tester) async {
    await tester.pumpWidget(app(['javascript:alert(1)']));
    expect(find.text('Open'), findsNothing);
    expect(find.textContaining('shown as text only'), findsOneWidget);
  });

  testWidgets('web links show the hostname prominently with a caution', (tester) async {
    await tester.pumpWidget(app(['https://pay.example.com/invoice?id=1']));
    expect(find.text('pay.example.com'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.textContaining('does not mean the site is trustworthy'), findsOneWidget);
  });

  testWidgets('multiple codes can be chosen from a visible list', (tester) async {
    await tester.pumpWidget(app(['https://a.example.com', 'hello']));
    expect(find.text('2 codes found. Choose one:'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    await tester.tap(find.text('hello').first); await tester.pumpAndSettle();
    expect(find.text('Open'), findsNothing);
  });

  testWidgets('Thai strings follow the locale', (tester) async {
    await tester.pumpWidget(app(['hello'], locale: const Locale('th')));
    expect(find.text('คัดลอก'), findsOneWidget);
  });
}
