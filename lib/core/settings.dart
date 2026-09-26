import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  Locale? locale; ThemeMode themeMode = ThemeMode.system;
  Future<void> load() async { final p = await SharedPreferences.getInstance(); final language = p.getString('language'); locale = language == null ? null : Locale(language); themeMode = ThemeMode.values.byName(p.getString('theme') ?? 'system'); notifyListeners(); }
  Future<void> setLocale(Locale? value) async { locale = value; final p = await SharedPreferences.getInstance(); value == null ? await p.remove('language') : await p.setString('language', value.languageCode); notifyListeners(); }
  Future<void> setTheme(ThemeMode value) async { themeMode = value; await (await SharedPreferences.getInstance()).setString('theme', value.name); notifyListeners(); }
}
