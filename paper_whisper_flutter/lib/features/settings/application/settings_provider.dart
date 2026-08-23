import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';

const String _themeKey = 'theme';
const String _preferredThemeKey = 'preferred_theme';
const String _followSystemThemeKey = 'follow_system_theme';
const String _startupPageKey = 'startup_page';
const String _compatibilityModeKey = 'compatibility_mode';

/// 启动阶段同步读取的设置快照，避免首帧先用默认值构建再整树重建。
class SettingsBootstrapData {
  final String storedTheme;
  final String preferredTheme;
  final bool followSystemTheme;
  final String startupPage;
  final bool compatibilityMode;

  const SettingsBootstrapData({
    required this.storedTheme,
    required this.preferredTheme,
    required this.followSystemTheme,
    required this.startupPage,
    required this.compatibilityMode,
  });

  factory SettingsBootstrapData.fromPreferences(SharedPreferences prefs) {
    final storedTheme = prefs.getString(_themeKey) ?? 'default';

    return SettingsBootstrapData(
      storedTheme: storedTheme,
      preferredTheme: prefs.getString(_preferredThemeKey) ?? storedTheme,
      followSystemTheme: prefs.getBool(_followSystemThemeKey) ?? false,
      startupPage: prefs.getString(_startupPageKey) ?? 'last',
      compatibilityMode: prefs.getBool(_compatibilityModeKey) ?? false,
    );
  }

  String resolveTheme(Brightness brightness) {
    if (!followSystemTheme) {
      return storedTheme;
    }

    return brightness == Brightness.dark
        ? AppTheme.themeMidnight
        : preferredTheme;
  }
}

class SettingsProvider with ChangeNotifier {
  String _currentTheme = 'default';
  String _preferredTheme = 'default'; // 用户手动选择的主题（用于浅色模式恢复）
  bool _followSystemTheme = false;
  String _startupPage = 'last';
  bool _compatibilityMode = false;

  String get currentTheme => _currentTheme;
  bool get followSystemTheme => _followSystemTheme;
  String get startupPage => _startupPage;
  bool get compatibilityMode => _compatibilityMode;

  SettingsProvider({SettingsBootstrapData? bootstrapData}) {
    if (bootstrapData != null) {
      _applyBootstrapData(bootstrapData);
      return;
    }

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _applyBootstrapData(SettingsBootstrapData.fromPreferences(prefs));
    notifyListeners();
  }

  void _applyBootstrapData(SettingsBootstrapData bootstrapData) {
    _preferredTheme = bootstrapData.preferredTheme;
    _followSystemTheme = bootstrapData.followSystemTheme;
    _startupPage = bootstrapData.startupPage;
    _compatibilityMode = bootstrapData.compatibilityMode;
    _currentTheme = bootstrapData.resolveTheme(
      PlatformDispatcher.instance.platformBrightness,
    );
    _applySystemUiStyle(_currentTheme);
  }

  /// 供外部调用（main.dart），当系统亮度变化时触发
  void updateThemeFromSystem(Brightness brightness) {
    if (_followSystemTheme) {
      final bool themeChanged = _updateThemeFromSystem(brightness);
      if (themeChanged) {
        notifyListeners();
      }
    }
  }

  bool _updateThemeFromSystem(Brightness brightness) {
    final String nextTheme = brightness == Brightness.dark
        ? AppTheme.themeMidnight
        : _preferredTheme;
    final bool themeChanged = nextTheme != _currentTheme;
    _currentTheme = nextTheme;
    _applySystemUiStyle(_currentTheme);
    return themeChanged;
  }

  Future<void> setTheme(String theme) async {
    _currentTheme = theme;
    _preferredTheme = theme; // 记录用户偏好
    _followSystemTheme = false; // 手动切换自动关闭跟随

    _applySystemUiStyle(theme);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme);
    await prefs.setString(_preferredThemeKey, theme);
    await prefs.setBool(_followSystemThemeKey, false);
  }

  Future<void> setFollowSystemTheme(bool enable) async {
    _followSystemTheme = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_followSystemThemeKey, enable);

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
  Future<void> setCompatibilityMode(bool value) async {
    _compatibilityMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_compatibilityModeKey, value);
    notifyListeners();
  }

  void _applySystemUiStyle(String theme) {
    final style = AppTheme.getSystemUiOverlayStyle(theme);
    // 延迟一点设置，确保UI构建完成后生效? 通常不需要，但如果是导航切换可能需要。
    // 直接设置应该可以。
    SystemChrome.setSystemUIOverlayStyle(style);
  }
}
