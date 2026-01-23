import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_theme.dart';

class SettingsProvider with ChangeNotifier {
  static const String _themeKey = 'theme';
  static const String _startupPageKey = 'startup_page';
  
  String _currentTheme = 'default';
  String _preferredTheme = 'default'; // 用户手动选择的主题（用于浅色模式恢复）
  bool _followSystemTheme = false;
  String _startupPage = 'last';

  String get currentTheme => _currentTheme;
  bool get followSystemTheme => _followSystemTheme;
  String get startupPage => _startupPage;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _currentTheme = prefs.getString(_themeKey) ?? 'default';
    _preferredTheme = prefs.getString('preferred_theme') ?? _currentTheme;
    _followSystemTheme = prefs.getBool('follow_system_theme') ?? false;
    
    // 如果开启了跟随系统，立即应用
    if (_followSystemTheme) {
      final brightness = PlatformDispatcher.instance.platformBrightness;
      _updateThemeFromSystem(brightness);
    } else {
      _applySystemUiStyle(_currentTheme);
    }
    
    _startupPage = prefs.getString(_startupPageKey) ?? 'last'; 
    _compatibilityMode = prefs.getBool('compatibility_mode') ?? false;
    notifyListeners();
  }

  /// 供外部调用（main.dart），当系统亮度变化时触发
  void updateThemeFromSystem(Brightness brightness) {
    if (_followSystemTheme) {
      _updateThemeFromSystem(brightness);
      notifyListeners();
    }
  }

  void _updateThemeFromSystem(Brightness brightness) {
    if (brightness == Brightness.dark) {
      _currentTheme = AppTheme.themeMidnight; // 深色模式 -> 午夜星尘
    } else {
      _currentTheme = _preferredTheme; // 浅色模式 -> 恢复用户偏好（复古/花海等）
    }
    _applySystemUiStyle(_currentTheme);
  }

  Future<void> setTheme(String theme) async {
    _currentTheme = theme;
    _preferredTheme = theme; // 记录用户偏好
    _followSystemTheme = false; // 手动切换自动关闭跟随
    
    _applySystemUiStyle(theme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme);
    await prefs.setString('preferred_theme', theme);
    await prefs.setBool('follow_system_theme', false);
    
    notifyListeners();
  }

  Future<void> setFollowSystemTheme(bool enable) async {
    _followSystemTheme = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('follow_system_theme', enable);
    
    if (enable) {
      // 立即根据当前系统状态更新
      final brightness = PlatformDispatcher.instance.platformBrightness;
      _updateThemeFromSystem(brightness);
    }
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
