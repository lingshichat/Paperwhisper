import 'paper_whisper_theme.dart';
import 'themes/vintage_theme.dart';
import 'themes/midnight_theme.dart';
import 'themes/amber_lens_theme.dart';
import 'themes/after_rain_theme.dart';
import 'themes/twilight_theme.dart';
import 'themes/garden_of_words_theme.dart';
import 'themes/sea_flower_theme.dart';

/// 主题注册中心 — 管理所有主题的注册、查找和列举
class ThemeRegistry {
  static final Map<String, PaperWhisperTheme> _themes = {};

  static void register(PaperWhisperTheme theme) {
    _themes[theme.id] = theme;
  }

  static PaperWhisperTheme get(String id) => _themes[id] ?? _themes['default']!;

  static List<PaperWhisperTheme> get allThemes => _themes.values.toList();

  static void init() {
    register(vintageTheme);
    register(midnightTheme);
    register(amberLensTheme);
    register(afterRainTheme);
    register(twilightTheme);
    register(gardenOfWordsTheme);
    register(seaFlowerTheme);
  }
}
