import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class AppSettings extends ChangeNotifier {
  /// Null follows the device language.
  Locale? locale;
  ThemeMode themeMode = ThemeMode.system;
  ExportOptions exportDefaults = const ExportOptions();

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final language = p.getString('language'); locale = language == null ? null : Locale(language);
    themeMode = ThemeMode.values.asNameMap()[p.getString('theme')] ?? ThemeMode.system;
    final defaults = p.getString('exportDefaults'); exportDefaults = defaults == null ? const ExportOptions() : ExportOptions.fromJson(defaults);
    notifyListeners();
  }
  Future<void> setLocale(Locale? value) async { locale = value; final p = await SharedPreferences.getInstance(); value == null ? await p.remove('language') : await p.setString('language', value.languageCode); notifyListeners(); }
  Future<void> setTheme(ThemeMode value) async { themeMode = value; await (await SharedPreferences.getInstance()).setString('theme', value.name); notifyListeners(); }
  Future<void> setExportDefaults(ExportOptions value) async { exportDefaults = value; await (await SharedPreferences.getInstance()).setString('exportDefaults', value.toJson()); notifyListeners(); }
}
