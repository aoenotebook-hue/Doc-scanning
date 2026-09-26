import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/settings.dart';
import 'screens/home_screen.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); final settings = AppSettings(); runApp(ScanOpenApp(settings)); settings.load(); }

class ScanOpenApp extends StatelessWidget {
  const ScanOpenApp(this.settings, {super.key}); final AppSettings settings;
  @override Widget build(BuildContext context) => ListenableBuilder(listenable: settings, builder: (_, __) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'Scan & Open', locale: settings.locale,
    supportedLocales: const [Locale('en'), Locale('th')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    themeMode: settings.themeMode,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff006c67)), useMaterial3: true, inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder())),
    darkTheme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff64d8d1), brightness: Brightness.dark), useMaterial3: true),
    home: HomeScreen(settings: settings),
  ));
}
