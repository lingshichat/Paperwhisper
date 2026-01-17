import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_theme.dart';

class SettingsProvider with ChangeNotifier {
  static const String _themeKey = 'theme';
  static const String _startupPageKey = 'startup_page';
  
  String _currentTheme = 'default';
  String _startupPage = 'last';

  String get currentTheme => _currentTheme;
  String get startupPage => _startupPage;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _currentTheme = prefs.getString(_themeKey) ?? 'default';
    _startupPage = prefs.getString(_startupPageKey) ?? 'last'; 
    _compatibilityMode = prefs.getBool('compatibility_mode') ?? false;
    _applySystemUiStyle(_currentTheme);
    notifyListeners();
  }

  Future<void> setTheme(String theme) async {
    _currentTheme = theme;
    _applySystemUiStyle(theme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme);
    notifyListeners();
  }

  Future<void> setStartupPage(String page) async {
    _startupPage = page;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_startupPageKey, page);
    notifyListeners();
  }

  // Compatibility Mode (No Lines)
  bool _compatibilityMode = false;
  bool get compatibilityMode => _compatibilityMode;

  Future<void> setCompatibilityMode(bool value) async {
    _compatibilityMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('compatibility_mode', value);
    notifyListeners();
  }

  void _applySystemUiStyle(String theme) {
    final style = AppTheme.getSystemUiOverlayStyle(theme);
    // 延迟一点设置，确保UI构建完成后生效? 通常不需要，但如果是导航切换可能需要。
    // 直接设置应该可以。
    SystemChrome.setSystemUIOverlayStyle(style);
  }
}
