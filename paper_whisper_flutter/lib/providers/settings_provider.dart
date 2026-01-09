import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  static const String _themeKey = 'theme';
  String _currentTheme = 'default';

  String get currentTheme => _currentTheme;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _currentTheme = prefs.getString(_themeKey) ?? 'default';
    notifyListeners();
  }

  Future<void> setTheme(String theme) async {
    _currentTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme);
    notifyListeners();
  }
}
