import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/visual_effects.dart';

class AppTheme {
  static const String themeDefault = 'default'; // Vintage (时光旧物)
  static const String themeAmberLens = 'amber_lens';
  static const String themeAfterRain = 'after_rain';
  static const String themeTwilight = 'twilight'; // Twilight (黄昏之时)
  static const String themeGardenOfWords =
      'garden_of_words'; // Garden of Words (言叶之庭)

  // --- 1. Colors (CSS Variable Mapping) ---

  // Vintage Theme Colors
  static const Color _vintageBgCenter = Color(0xFF4a3b32);
  static const Color _vintageBgEdge = Color(0xFF2d241f);
  static const Color _vintagePaper = Color(0xFFF4ECD8); // #F4ECD8
  static const Color _vintageTextPrimary = Color(0xFF2C3E50); // #2C3E50
  static const Color _vintageTextSecondary = Color(0xFF5D4037); // #5D4037
  static const Color _vintageAccent = Color(0xFFFF3D00); // Red

  // Midnight Theme Colors
  static const Color _midnightBgCenter = Color(0xFF1a237e); // Radial stop 0%
  static const Color _midnightBgMid = Color(0xFF050510); // Radial stop 50%
  static const Color _midnightBgEdge = Colors.black; // Radial stop 100%
  static const Color _midnightPaper = Color(0xFF161b22);
  static const Color _midnightTextPrimary = Color(0xFFe6edf3);
  static const Color _midnightTextSecondary = Color(0xFF8b949e);
  static const Color _midnightAccent = Color(0xFF7986cb);

  // Amber Lens Theme Colors
  static const Color _amberBgCenter = Color(0xFF2C2C2C);
  static const Color _amberBgEdge = Color(0xFF000000);
  static const Color _amberPaper = Color(0xFF1E1E1E); // Editor Paper
  static const Color _amberTextPrimary = Color(0xFFE0E0E0);
  static const Color _amberTextSecondary = Color(0xFF9E9E9E);
  static const Color _amberAccent = Color(0xFFFF9800);

  // After Rain Theme Colors (Redesigned)
  // After the Rain Theme Colors (Redesigned - Skeuomorphic)
  static const Color _afterRainPrimaryMain = Color(
    0xFF4FC3F7,
  ); // Fresh Sky Blue (Clear sky)
  static const Color _afterRainPrimaryLight = Color(
    0xFFB3E5FC,
  ); // Pale Blue (Water reflection)
  static const Color _afterRainSurface = Color(
    0xFFF0F8FF,
  ); // Alice Blue (Damp paper)
  static const Color _afterRainTextSecondary = Color(
    0xFF455A64,
  ); // Blue Grey (Wet stone)
  static const Color _afterRainAccentBlue = Color(
    0xFF0288D1,
  ); // Deep Lake Blue (Accent)

  // Twilight Theme Colors
  static const Color _twilightBgTop = Color(0xFF2E1C55); // Indigo
  static const Color _twilightBgMid = Color(0xFF913862); // Magenta
  static const Color _twilightBgBottom = Color(0xFFFF9A6C); // Sunset Orange
  static const Color _twilightAccentRed = Color(0xFFFF5252); // Musubi RedRed
  static const Color _twilightTextPrimary = Color(0xFFE4E0EC); // Stardust White
  static const Color _twilightTextSecondary = Color(
    0xFFBCAAA4,
  ); // Twilight Grey
  static const Color _twilightSurface = Color(
    0xFF352044,
  ); // Deep Purple GlassBase

  // Garden of Words Theme Colors (Redesigned: Rainy Garden - Dark Glass)
  static const Color _gardenBgCenter = Color(0xFF37474F); // Blue Grey 800
  static const Color _gardenSurface = Color(
    0xFF455A64,
  ); // Blue Grey 700 (Base for glass)
  static const Color _gardenTextPrimary = Color(
    0xFFECEFF1,
  ); // Blue Grey 50 (Light Text)
  static const Color _gardenTextSecondary = Color(
    0xFFB0BEC5,
  ); // Blue Grey 200 (Sub Text)
  static const Color _gardenAccent = Color(
    0xFF81C784,
  ); // Lighter Green for Dark Mode
  static const Color _gardenAccentDark = Color(0xFF4CAF50); // Mid Green

  // 1. FAB Theme
  static Map<String, dynamic> getFabTheme(String theme) {
    if (theme == themeGardenOfWords) {
      return {
        'bg': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFA5D6A7),
            _gardenAccentDark,
          ], // Light Green to Deep Green
          stops: [0.0, 1.0],
        ),
        'shadow': BoxShadow(
          color: _gardenAccentDark.withOpacity(0.5),
          blurRadius: 16,
          offset: const Offset(0, 8),
          spreadRadius: -2,
        ),
        'iconColor': Colors.white,
        'border': Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 1.5,
        ), // Dew drop rim
      };
    } else if (theme == themeTwilight) {
      return {
        'bg': const RadialGradient(
          center: Alignment.topLeft,
          radius: 1.0,
          colors: [
            _twilightAccentRed,
            Color(0xFFFF8A80),
          ], // Musubi Red (Main Accent)
        ),
        'shadow': BoxShadow(
          color: _twilightAccentRed.withOpacity(0.5),
          blurRadius: 20,
          spreadRadius: -2,
          offset: const Offset(0, 0), // Glowing effect
        ),
        'iconColor': Colors.white,
        'border': Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
      };
    } else if (theme == themeAfterRain) {
      return {
        'bg': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE0F7FA),
            _afterRainAccentBlue,
          ], // Light cyan to deep blue
          stops: [0.1, 0.9],
        ),
        'shadow': BoxShadow(
          color: _afterRainAccentBlue.withOpacity(0.4),
          blurRadius: 16,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
        'iconColor': Colors.white,
        'border': Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 1.5,
        ), // Shiny rim
      };
    } else if (theme == themeSeaFlower) {
      return {
        'bg': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8BBD0), Color(0xFFF06292)],
        ),
        'shadow': const BoxShadow(
          color: Color.fromRGBO(240, 98, 146, 0.5),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
        'iconColor': Colors.white,
      };
    } else if (theme == themeMidnight) {
      return {
        'bg': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7986cb), Color(0xFF303f9f)],
        ),
        'shadow': const BoxShadow(
          color: Color.fromRGBO(121, 134, 203, 0.5),
          blurRadius: 15,
          offset: Offset(0, 0),
          spreadRadius: 2,
        ),
        'iconColor': Colors.white,
      };
    } else if (theme == themeAmberLens) {
      return {
        'bg': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFB74D), Color(0xFFF57C00)],
        ),
        'shadow': const BoxShadow(
          color: Color.fromRGBO(255, 152, 0, 0.5),
          blurRadius: 15,
          offset: Offset(0, 0),
          spreadRadius: 2,
        ),
        'iconColor': Colors.white,
      };
    } else {
      return {
        'bg': const Color(0xFFC0392B),
        'shadow': const BoxShadow(color: Colors.transparent),
        'iconColor': Colors.white,
      };
    }
  }

  // 2. Sidebar Theme
  static Map<String, dynamic> getSidebarTheme(String theme) {
    if (theme == themeGardenOfWords) {
      return {
        'bgDecoration': BoxDecoration(
          color: const Color(0xFF263238).withOpacity(0.6), // Darker glass
          border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(5, 0),
            ),
          ],
        ),
        'textColor': const Color(0xFFB0BEC5),
        'activeTextColor': _gardenAccent,
        'subTextColor': const Color(0xFF78909C),
        'pillColor': Colors.white.withOpacity(0.05),
        'pillShadows': [
          BoxShadow(
            color: _gardenAccent.withOpacity(0.1),
            offset: const Offset(0, 0),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
        'pillBorder': Border.all(color: Colors.white.withOpacity(0.05)),
        'buttonGradient': LinearGradient(
          colors: [_gardenAccentDark, _gardenAccent],
        ), // Inverted for depth
        'buttonShadow': BoxShadow(
          color: _gardenAccentDark.withOpacity(0.4),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      };
    } else if (theme == themeTwilight) {
      return {
        'bgDecoration': BoxDecoration(
          color: _twilightSurface.withOpacity(0.4), // Glassmorphism
          border: Border(
            right: BorderSide(
              color: _twilightBgBottom.withOpacity(0.3),
              width: 1,
            ), // Sunset edge reflection
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(5, 0),
            ),
          ],
        ),
        'textColor': _twilightTextSecondary,
        'activeTextColor': _twilightAccentRed,
        'subTextColor': Color(0xFF8D6E63),
        'pillColor': _twilightSurface.withOpacity(0.6),
        'pillShadows': [
          BoxShadow(
            color: _twilightAccentRed.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 0), // Glow
          ),
        ],
        'pillBorder': Border.all(color: Colors.white.withOpacity(0.1)),
        'buttonGradient': const LinearGradient(
          colors: [_twilightAccentRed, _twilightBgBottom],
        ), // 黄昏红 -> 落日橙
        'buttonShadow': BoxShadow(
          color: _twilightAccentRed.withOpacity(0.4),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      };
    } else if (theme == themeAfterRain) {
      // Glassmorphism with water droplet edges
      return {
        'bgDecoration': BoxDecoration(
          color: _afterRainSurface.withOpacity(0.65), // More transparent
          border: Border(
            right: BorderSide(
              color: Colors.white.withOpacity(0.4),
              width: 1,
            ), // Highlight edge
          ),
          boxShadow: [
            BoxShadow(
              color: _afterRainAccentBlue.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(2, 0),
            ), // Subtle glow
          ],
        ),
        'textColor': _afterRainTextSecondary,
        'activeTextColor': _afterRainAccentBlue, // Deep Blue active
        'subTextColor': Color(0xFF78909C),
        'pillColor': _afterRainSurface.withOpacity(0.5),
        'pillShadows': [
          BoxShadow(
            color: Colors.white,
            offset: Offset(-1, -1),
            blurRadius: 2,
          ), // Inner light
          BoxShadow(
            color: _afterRainAccentBlue.withOpacity(0.2),
            offset: Offset(1, 1),
            blurRadius: 3,
          ), // Drop shadow
        ],
        'pillBorder': Border.all(color: Colors.white.withOpacity(0.3)),
        'buttonGradient': const LinearGradient(
          colors: [_afterRainPrimaryLight, _afterRainPrimaryMain],
        ),
        'buttonShadow': BoxShadow(
          color: _afterRainPrimaryMain.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      };
    } else if (theme == themeSeaFlower) {
      return {
        'bgDecoration': BoxDecoration(
          color: const Color(0xFFFCE4EC).withOpacity(0.6),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(5, 0),
            ),
          ],
        ),
        'textColor': const Color(0xFF880E4F),
        'activeTextColor': const Color(0xFFD81B60),
        'subTextColor': const Color(0xFFBC477B),
        'pillColor': Colors.white,
        'pillShadows': [
          BoxShadow(
            color: const Color(0xFFF48FB1).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        'pillBorder': null,
        'buttonGradient': const LinearGradient(
          colors: [Color(0xFFF06292), Color(0xFFD81B60)],
        ),
        'buttonShadow': BoxShadow(
          color: const Color(0xFFD81B60).withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      };
    } else if (theme == themeMidnight) {
      return {
        'bgDecoration': const BoxDecoration(
          color: Color(0xFF0D1117),
          border: Border(right: BorderSide(color: Colors.white12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black87,
              blurRadius: 10,
              offset: Offset(5, 0),
            ),
          ],
        ),
        'textColor': const Color(0xFFc9d1d9),
        'activeTextColor': const Color(0xFF7986cb),
        'subTextColor': const Color(0xFF8b949e),
        'pillColor': const Color(0xFF161b22),
        'pillShadows': [
          BoxShadow(
            color: Color.fromRGBO(121, 134, 203, 0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
        'pillBorder': Border.all(color: Colors.white10),
        'buttonGradient': const LinearGradient(
          colors: [Color(0xFF7986cb), Color(0xFF3F51B5)],
        ),
        'buttonShadow': BoxShadow(
          color: const Color(0xFF3F51B5).withOpacity(0.4),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      };
    } else if (theme == themeAmberLens) {
      return {
        'bgDecoration': const BoxDecoration(
          color: Color(0xFF2C2C2C),
          image: DecorationImage(
            image: AssetImage('assets/textures/leather_dark.png'),
            fit: BoxFit.cover,
            opacity: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: Offset(5, 0),
            ),
          ],
        ),
        'textColor': const Color(0xFFBDBDBD),
        'activeTextColor': const Color(0xFFFF9800),
        'subTextColor': const Color(0xFF757575),
        'pillColor': const Color(0xFF222222),
        'pillShadows': [
          BoxShadow(color: Colors.white10, offset: Offset(0, 1), blurRadius: 0),
          BoxShadow(
            color: Colors.black87,
            offset: Offset(0, -2),
            blurRadius: 1,
          ),
        ],
        'pillBorder': null,
        'buttonGradient': const LinearGradient(
          colors: [Color(0xFFFFB74D), Color(0xFFF57C00)],
        ),
      };
    } else {
      return {
        'bgDecoration': const BoxDecoration(
          color: Color(0xFF3E2723),
          image: DecorationImage(
            image: AssetImage('assets/textures/leather_dark.png'),
            fit: BoxFit.cover,
            opacity: 0.6,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: Offset(5, 0),
            ),
          ],
        ),
        'textColor': const Color(0xFFD7CCC8),
        'activeTextColor': const Color(0xFFFF5252),
        'subTextColor': const Color(0xFFA1887F),
        'pillColor': const Color(0xFF2D1E1B),
        'pillShadows': [
          BoxShadow(color: Colors.white10, offset: Offset(0, 1), blurRadius: 0),
          BoxShadow(
            color: Colors.black87,
            offset: Offset(0, -2),
            blurRadius: 1,
          ),
        ],
        'pillBorder': null,
        'buttonGradient': const LinearGradient(
          colors: [Color(0xFFE57373), Color(0xFFD32F2F)],
        ),
      };
    }
  }

  // 3. Settings Theme
  static Map<String, dynamic> getSettingsTheme(String theme) {
    switch (theme) {
      case themeSeaFlower:
        return {
          'groupDecoration': BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF48FB1).withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          'dividerColor': Colors.white.withOpacity(0.3),
          'textColor': const Color(0xFFAD1457),
          'activeSwitchColor': const Color(0xFFEC407A),
          'activeTrackColor': const Color(0xFFF48FB1).withOpacity(0.3),
          'titleColor': const Color(0xFF880E4F),
          'titleShadow': const Shadow(
            color: Color.fromRGBO(255, 255, 255, 0.5),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
          'iconColor': const Color(0xFFEC407A),
          'showPetalRain': true,
          'showStarrySky': false,
          'sheetTextColor': const Color(0xFF880E4F),
          'sheetBackgroundColor': const Color(0xFFFCE4EC),
          'sheetTitleColor': const Color(0xFF880E4F),
          'sheetTapeColor': const Color(0xFFF8BBD0),
          'sheetShadows': const [
            BoxShadow(
              color: Color.fromRGBO(173, 20, 87, 0.25),
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
          'sheetBorder': Border.all(color: const Color(0xFFF48FB1), width: 1),
          'sheetShowTape': false,
          'sheetInfoBackgroundColor': Colors.white.withOpacity(0.45),
          'sheetInfoBorderColor': const Color(0xFFF8BBD0).withOpacity(0.6),
          'sheetInfoDividerColor': const Color(0xFFF8BBD0).withOpacity(0.5),
          'optionSelectedBgColor': const Color(0xFFEC407A),
          'optionSelectedTextColor': Colors.white,
          'optionSelectedShadow': const BoxShadow(
            color: Color.fromRGBO(236, 64, 122, 0.4),
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
          'optionUnselectedBgColor': Colors.white.withOpacity(0.5),
          'optionUnselectedTextColor': const Color(0xFFAD1457),
          'optionUnselectedBorder': Border.all(
            color: const Color(0xFFF48FB1).withOpacity(0.5),
          ),
          'optionUnselectedShadow': null,
        };
      case themeMidnight:
        return {
          'groupDecoration': BoxDecoration(
            color: const Color(0xFF161b22).withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF30363d)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          'dividerColor': const Color(0xFF30363d),
          'textColor': const Color(0xFFc9d1d9),
          'activeSwitchColor': _midnightAccent,
          'activeTrackColor': _midnightAccent.withOpacity(0.3),
          'titleColor': _midnightTextPrimary,
          'titleShadow': const Shadow(
            color: Color.fromRGBO(0, 0, 0, 0.3),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
          'iconColor': _midnightAccent,
          'showPetalRain': false,
          'showStarrySky': true,
          'sheetTextColor': const Color(0xFFc9d1d9),
          'sheetBackgroundColor': const Color(0xFF161b22),
          'sheetTitleColor': _midnightTextPrimary,
          'sheetTapeColor': const Color(0xFF30363d),
          'sheetShadows': const [
            BoxShadow(
              color: Colors.black,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
          'sheetBorder': Border.all(color: const Color(0xFF30363d), width: 1),
          'sheetShowTape': false,
          'sheetInfoBackgroundColor': const Color(0xFF0D1117).withOpacity(0.6),
          'sheetInfoBorderColor': const Color(0xFF30363d),
          'sheetInfoDividerColor': Colors.white.withOpacity(0.08),
          'optionSelectedBgColor': const Color(0xFF5C6BC0),
          'optionSelectedTextColor': _midnightTextPrimary,
          'optionSelectedShadow': const BoxShadow(
            color: Color.fromRGBO(92, 107, 192, 0.4),
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
          'optionUnselectedBgColor': const Color(0xFF21262d),
          'optionUnselectedTextColor': const Color(0xFF8b949e),
          'optionUnselectedBorder': Border.all(color: const Color(0xFF30363d)),
          'optionUnselectedShadow': null,
        };
      case themeAmberLens:
        return {
          'groupDecoration': BoxDecoration(
            color: const Color(0xFF1E1E1E).withOpacity(0.78),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _amberAccent.withOpacity(0.18)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          'dividerColor': _amberAccent.withOpacity(0.12),
          'textColor': const Color(0xFFD7CCC8),
          'activeSwitchColor': _amberAccent,
          'activeTrackColor': _amberAccent.withOpacity(0.25),
          'titleColor': _amberTextPrimary,
          'titleShadow': const Shadow(
            color: Color.fromRGBO(0, 0, 0, 0.3),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
          'iconColor': _amberAccent,
          'showPetalRain': false,
          'showStarrySky': false,
          'sheetTextColor': _amberTextPrimary,
          'sheetBackgroundColor': const Color(0xFF1E1E1E),
          'sheetTitleColor': _amberTextPrimary,
          'sheetTapeColor': const Color(0xFFFF9800),
          'sheetShadows': const [
            BoxShadow(
              color: Colors.black,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
          'sheetBorder': Border.all(
            color: _amberAccent.withOpacity(0.3),
            width: 1,
          ),
          'sheetShowTape': false,
          'sheetInfoBackgroundColor': Colors.white.withOpacity(0.08),
          'sheetInfoBorderColor': _amberAccent.withOpacity(0.2),
          'sheetInfoDividerColor': _amberAccent.withOpacity(0.15),
          'optionSelectedBgColor': _amberAccent,
          'optionSelectedTextColor': _amberTextPrimary,
          'optionSelectedShadow': const BoxShadow(
            color: Colors.black26,
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
          'optionUnselectedBgColor': const Color(0xFF2C2C2C),
          'optionUnselectedTextColor': const Color(0xFF9E9E9E),
          'optionUnselectedBorder': Border.all(
            color: _amberAccent.withOpacity(0.3),
          ),
          'optionUnselectedShadow': null,
        };
      case themeAfterRain:
        return {
          'groupDecoration': BoxDecoration(
            color: Colors.white.withOpacity(0.5), // Frosted glass
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _afterRainAccentBlue.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          'dividerColor': _afterRainAccentBlue.withOpacity(0.1),
          'textColor': _afterRainTextSecondary,
          'activeSwitchColor': _afterRainPrimaryMain,
          'activeTrackColor': _afterRainPrimaryLight.withOpacity(0.3),
          'titleColor': _afterRainTextSecondary,
          'titleShadow': Shadow(
            color: Colors.white.withOpacity(0.8),
            offset: const Offset(0, 1),
            blurRadius: 0,
          ),
          'iconColor': _afterRainAccentBlue,
          'showPetalRain': false,
          'showStarrySky': false,
          'sheetTextColor': _afterRainTextSecondary,
          'sheetBackgroundColor': const Color(0xFFF0F8FF).withOpacity(0.95),
          'sheetTitleColor': _afterRainTextSecondary,
          'sheetTapeColor': const Color(0xFFB3E5FC).withOpacity(0.5),
          'sheetShadows': [
            BoxShadow(
              color: _afterRainAccentBlue.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
          'sheetBorder': Border.all(color: Colors.white, width: 1),
          'sheetShowTape': false,
          'sheetInfoBackgroundColor': Colors.white.withOpacity(0.85),
          'sheetInfoBorderColor': Colors.white,
          'sheetInfoDividerColor': _afterRainAccentBlue.withOpacity(0.15),
          'optionSelectedBgColor': _afterRainAccentBlue,
          'optionSelectedTextColor': Colors.white,
          'optionSelectedShadow': const BoxShadow(
            color: Color.fromRGBO(2, 136, 209, 0.3),
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
          'optionUnselectedBgColor': Colors.white.withOpacity(0.6),
          'optionUnselectedTextColor': _afterRainTextSecondary,
          'optionUnselectedBorder': Border.all(color: Colors.white),
          'optionUnselectedShadow': null,
        };
      case themeTwilight:
        return {
          'groupDecoration': BoxDecoration(
            color: _twilightSurface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _twilightBgBottom.withOpacity(0.1),
              width: 1,
            ), // Subtle orange rim
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          'dividerColor': Colors.white.withOpacity(0.05),
          'textColor': _twilightTextPrimary,
          'activeSwitchColor': _twilightAccentRed, // Red knot
          'activeTrackColor': _twilightAccentRed.withOpacity(0.3),
          'titleColor': _twilightTextPrimary,
          'titleShadow': const Shadow(
            color: Color.fromRGBO(0, 0, 0, 0.3),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
          'iconColor': _twilightAccentRed,
          'showPetalRain': false,
          'showStarrySky': false,
          'sheetTextColor': _twilightTextPrimary,
          'sheetBackgroundColor': const Color(0xFF352044).withOpacity(0.95),
          'sheetTitleColor': _twilightTextPrimary,
          'sheetTapeColor': const Color(0xFFFF5252).withOpacity(0.3),
          'sheetShadows': [
            BoxShadow(
              color: const Color(0xFFEF5350).withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
          'sheetBorder': Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
          'sheetShowTape': false,
          'sheetInfoBackgroundColor': _twilightSurface.withOpacity(0.55),
          'sheetInfoBorderColor': Colors.white.withOpacity(0.1),
          'sheetInfoDividerColor': _twilightAccentRed.withOpacity(0.18),
          'optionSelectedBgColor': _twilightAccentRed,
          'optionSelectedTextColor': _twilightSurface,
          'optionSelectedShadow': const BoxShadow(
            color: Color.fromRGBO(255, 82, 82, 0.4),
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
          'optionUnselectedBgColor': const Color(0xFF352044).withOpacity(0.6),
          'optionUnselectedTextColor': const Color(0xFFBCAAA4),
          'optionUnselectedBorder': Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
          'optionUnselectedShadow': null,
        };
      case themeGardenOfWords:
        return {
          'groupDecoration': BoxDecoration(
            color: const Color(0xFF263238).withOpacity(0.5), // Dark Glass
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gardenAccent.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          'dividerColor': Colors.white.withOpacity(0.1),
          'textColor': const Color(0xFFCFD8DC),
          'activeSwitchColor': _gardenAccent,
          'activeTrackColor': _gardenAccent.withOpacity(0.3),
          'titleColor': const Color(0xFFECEFF1),
          'titleShadow': const Shadow(
            color: Color.fromRGBO(129, 199, 132, 0.3),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
          'iconColor': _gardenAccent,
          'showPetalRain': false,
          'showStarrySky': false,
          'sheetTextColor': const Color(0xFFECEFF1),
          'sheetBackgroundColor': const Color(0xFF263238).withOpacity(0.95),
          'sheetTitleColor': const Color(0xFFECEFF1),
          'sheetTapeColor': Colors.white.withOpacity(0.5),
          'sheetShadows': [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
          'sheetBorder': Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
          'sheetShowTape': false,
          'sheetInfoBackgroundColor': _gardenSurface.withOpacity(0.45),
          'sheetInfoBorderColor': _gardenAccent.withOpacity(0.2),
          'sheetInfoDividerColor': _gardenAccent.withOpacity(0.15),
          'optionSelectedBgColor': const Color(0xFF8BC34A).withOpacity(0.8),
          'optionSelectedTextColor': Colors.white,
          'optionSelectedShadow': const BoxShadow(
            color: Color.fromRGBO(139, 195, 74, 0.4),
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
          'optionUnselectedBgColor': const Color(0xFF37474F).withOpacity(0.4),
          'optionUnselectedTextColor': const Color(0xFFCFD8DC),
          'optionUnselectedBorder': Border.all(
            color: const Color(0xFF8BC34A).withOpacity(0.3),
          ),
          'optionUnselectedShadow': null,
        };
      case themeDefault:
      default:
        return {
          'groupDecoration': BoxDecoration(
            color: const Color(
              0xFF3E2723,
            ).withOpacity(0.3), // Darker brown background for group
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _vintagePaper.withOpacity(0.1),
            ), // Light border
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          'dividerColor': _vintagePaper.withOpacity(0.1),
          'textColor': _vintagePaper,
          'activeSwitchColor': _vintageAccent,
          'activeTrackColor': _vintageAccent.withOpacity(0.3),
          'titleColor': _vintagePaper,
          'titleShadow': const Shadow(
            color: Color.fromRGBO(0, 0, 0, 0.3),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
          'iconColor': _vintagePaper.withOpacity(0.8),
          'showPetalRain': false,
          'showStarrySky': false,
          'sheetTextColor': const Color(0xFF5D4037),
          'sheetBackgroundColor': const Color(0xFFF4ECD8),
          'sheetTitleColor': const Color(0xFF5D4037),
          'sheetTapeColor': const Color(0xD9E0E0E0),
          'sheetShadows': const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.2),
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
          'sheetBorder': null,
          'sheetShowTape': true,
          'sheetInfoBackgroundColor': const Color(0xFFF7F1E3),
          'sheetInfoBorderColor': const Color(0xFFE0D6C2),
          'sheetInfoDividerColor': const Color(0xFF5D4037),
          'optionSelectedBgColor': const Color(0xFF5D4037),
          'optionSelectedTextColor': _vintagePaper,
          'optionSelectedShadow': const BoxShadow(
            color: Color.fromRGBO(93, 64, 55, 0.4),
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
          'optionUnselectedBgColor': const Color(0xFFEFEBE9),
          'optionUnselectedTextColor': const Color(0xFF8D6E63),
          'optionUnselectedBorder': null,
          'optionUnselectedShadow': const BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        };
    }
  }

  /// 返回指定主题的背景动画叠加层 Widget 列表。
  /// 每个 Widget 应在 Stack 中使用 Positioned.fill 包裹。
  static List<Widget> getBackgroundOverlays(String theme) {
    switch (theme) {
      case themeSeaFlower:
        return [const Positioned.fill(child: PetalRainWidget())];
      case themeMidnight:
        return [const Positioned.fill(child: StarrySkyWidget())];
      case themeAfterRain:
        return [const Positioned.fill(child: AfterRainVisuals())];
      default:
        return [];
    }
  }

  // 4. Editor Theme
  static Map<String, dynamic> getEditorTheme(String theme) {
    switch (theme) {
      case themeGardenOfWords:
        return {
          'appBarBg': const Color(0xFF263238).withOpacity(0.9),
          'iconColor': _gardenTextSecondary,
          'cursorColor': _gardenAccent,
          'lineColor': Colors.white.withOpacity(0.05),
          'dividerColor': Colors.white.withOpacity(0.05),
          'appBarBorder': null,
          'applyBlur': false,
          'saveButtonBg': const Color(0xFFF7F1E3),
          'saveButtonTextColor': const Color(0xFF5D4037),
          'saveButtonCheckColor': const Color(0xFFC0392B),
          'dropdownBg': const Color(0xFFF0F4F2),
          'dropdownText': const Color(0xFF5A6B72),
          'exportPaperColor': const Color(0xFF455A64),
          'exportBorderColor': const Color(0xFF8BC34A),
          'ribbonAccentColor': const Color(0xFF8BC34A),
          'hintColor': Colors.white24,
        };
      case themeTwilight:
        return {
          'appBarBg': _twilightSurface.withOpacity(0.8),
          'iconColor': _twilightAccentRed,
          'cursorColor': _twilightAccentRed,
          'lineColor': Colors.white.withOpacity(0.05),
          'dividerColor': Colors.white.withOpacity(0.1),
          'appBarBorder': null,
          'applyBlur': false,
          'saveButtonBg': const Color(0xFFF7F1E3),
          'saveButtonTextColor': const Color(0xFF5D4037),
          'saveButtonCheckColor': const Color(0xFFC0392B),
          'dropdownBg': const Color(0xFF352044),
          'dropdownText': const Color(0xFFE4E0EC),
          'exportPaperColor': const Color(0xFF352044),
          'exportBorderColor': const Color(0xFFFF5252),
          'ribbonAccentColor': const Color(0xFFFF5252),
          'hintColor': Colors.white24,
        };
      case themeAfterRain:
        return {
          'appBarBg': _afterRainSurface.withOpacity(0.8),
          'iconColor': _afterRainTextSecondary,
          'cursorColor': _afterRainAccentBlue,
          'lineColor': _afterRainAccentBlue.withOpacity(0.1),
          'dividerColor': _afterRainAccentBlue.withOpacity(0.2),
          'appBarBorder': null,
          'applyBlur': false,
          'saveButtonBg': const Color(0xFFF7F1E3),
          'saveButtonTextColor': const Color(0xFF5D4037),
          'saveButtonCheckColor': const Color(0xFFC0392B),
          'dropdownBg': const Color(0xFFF0F8FF),
          'dropdownText': const Color(0xFF455A64),
          'exportPaperColor': const Color(0xFFF0F8FF),
          'exportBorderColor': const Color(0x339999BF),
          'ribbonAccentColor': const Color(0xFF29B6F6),
          'hintColor': Colors.black26,
        };
      case themeSeaFlower:
        return {
          'appBarBg': Colors.white.withOpacity(0.2),
          'iconColor': const Color(0xFF880E4F),
          'cursorColor': const Color(0xFFEC407A),
          'lineColor': const Color(0xFFEC407A).withOpacity(0.08),
          'dividerColor': const Color(0xFFEC407A).withOpacity(0.15),
          'appBarBorder': Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
          'applyBlur': true,
          'saveButtonBg': Colors.white.withValues(alpha: 0.9),
          'saveButtonTextColor': const Color(0xFF880E4F),
          'saveButtonCheckColor': const Color(0xFFC2185B),
          'dropdownBg': const Color(0xFFFFF0F5),
          'dropdownText': const Color(0xFF880E4F),
          'exportPaperColor': Colors.white.withValues(alpha: 0.95),
          'exportBorderColor': Colors.pink.withValues(alpha: 0.1),
          'ribbonAccentColor': const Color(0xFFEC407A),
          'hintColor': Colors.black26,
        };
      case themeMidnight:
        return {
          'appBarBg': const Color(0xFF0D1117).withValues(alpha: 0.9),
          'iconColor': const Color(0xFFc9d1d9),
          'cursorColor': const Color(0xFF7986cb),
          'lineColor': Colors.white.withValues(alpha: 0.08),
          'dividerColor': Colors.white.withValues(alpha: 0.1),
          'appBarBorder': null,
          'applyBlur': false,
          'saveButtonBg': const Color(0xFFF7F1E3),
          'saveButtonTextColor': const Color(0xFF5D4037),
          'saveButtonCheckColor': const Color(0xFFC0392B),
          'dropdownBg': const Color(0xFF2D333B),
          'dropdownText': const Color(0xFFc9d1d9),
          'exportPaperColor': const Color(0xFF161b22),
          'exportBorderColor': const Color(0xFF30363d),
          'ribbonAccentColor': const Color(0xFF7986cb),
          'hintColor': Colors.white24,
        };
      case themeAmberLens:
        return {
          'appBarBg': const Color(0xFF1E1E1E).withValues(alpha: 0.9),
          'iconColor': const Color(0xFFFF9800),
          'cursorColor': const Color(0xFFFF9800),
          'lineColor': const Color(0x1FFFFFFF),
          'dividerColor': const Color(0xFFFF9800).withOpacity(0.15),
          'appBarBorder': Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          'applyBlur': false,
          'saveButtonBg': const Color(0xFFFF9800),
          'saveButtonTextColor': Colors.black,
          'saveButtonCheckColor': Colors.black,
          'dropdownBg': const Color(0xFFFAF9F6),
          'dropdownText': const Color(0xFF5D4037),
          'exportPaperColor': const Color(0xFF1E1E1E),
          'exportBorderColor': const Color(0xFFFF9800),
          'ribbonAccentColor': const Color(0xFFFF9800),
          'hintColor': Colors.grey,
        };
      case themeDefault:
      default:
        return {
          'appBarBg': const Color(0xFF281815).withValues(alpha: 0.75),
          'iconColor': const Color(0xFFD7CCC8),
          'cursorColor': const Color(0xFFC0392B),
          'lineColor': const Color(0xFF5D4037).withValues(alpha: 0.12),
          'dividerColor': const Color(0xFF5D4037).withValues(alpha: 0.15),
          'appBarBorder': null,
          'applyBlur': false,
          'saveButtonBg': const Color(0xFFF7F1E3),
          'saveButtonTextColor': const Color(0xFF5D4037),
          'saveButtonCheckColor': const Color(0xFFC0392B),
          'dropdownBg': const Color(0xFFFAF9F6),
          'dropdownText': const Color(0xFF5D4037),
          'exportPaperColor': const Color(0xFFF4ECD8),
          'exportBorderColor': const Color(0xFFC0392B),
          'ribbonAccentColor': const Color(0xFFC0392B),
          'hintColor': Colors.black26,
        };
    }
  }

  // 5. Diary Card Theme
  static Map<String, dynamic> getDiaryCardTheme(String theme) {
    switch (theme) {
      case themeSeaFlower:
        return {
          'bgColor': Colors.white.withOpacity(0.35),
          'titleColor': const Color(0xFF880E4F),
          'contentColor': const Color(0xFFC2185B),
          'dateColor': const Color(0xFFAD1457),
          'iconColor': const Color(0xFFEC407A),
          'dashedLineColor': const Color(0x4DC2185B),
          'shadows': [
            const BoxShadow(
              color: Color.fromRGBO(200, 150, 200, 0.2),
              offset: Offset(0, 8),
              blurRadius: 32,
            ),
          ],
          'hoverShadows': [
            const BoxShadow(
              color: Color.fromRGBO(255, 255, 255, 0.6),
              offset: Offset(0, 0),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
          'border': Border.all(color: Colors.white.withOpacity(0.5)),
          'hoverBorderColor': null,
          'dateWeight': FontWeight.w600,
          'glassEffect': true,
          'glassColor': Colors.white.withValues(alpha: 0.65),
          'blurSigma': 8.0,
          'borderRadius': 16.0,
          'hoverTranslateY': -8.0,
          'hoverScale': 1.02,
          'showStarWatermark': false,
          'showFlowerWatermark': true,
          'usePaperContainer': false,
        };
      case themeMidnight:
        return {
          'bgColor': const Color(0xFF161b22).withOpacity(0.9),
          'titleColor': const Color(0xFFe6edf3),
          'contentColor': const Color(0xFF8b949e),
          'dateColor': const Color(0xFF8b949e),
          'iconColor': const Color(0xFF7986cb),
          'dashedLineColor': const Color(0xFF30363d),
          'shadows': [
            const BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.5),
              offset: Offset(0, 4),
              blurRadius: 10,
            ),
          ],
          'hoverShadows': [
            const BoxShadow(
              color: Color(0xFF7986cb),
              offset: Offset(0, 0),
              blurRadius: 15,
              spreadRadius: 1,
            ),
            const BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.8),
              offset: Offset(0, 10),
              blurRadius: 25,
            ),
          ],
          'border': Border.all(color: const Color(0xFF30363d)),
          'hoverBorderColor': const Color(0xFF7986cb),
          'dateWeight': FontWeight.normal,
          'glassEffect': false,
          'glassColor': Colors.transparent,
          'blurSigma': 0.0,
          'borderRadius': 6.0,
          'hoverTranslateY': -4.0,
          'hoverScale': 1.0,
          'showStarWatermark': true,
          'showFlowerWatermark': false,
          'usePaperContainer': false,
        };
      case themeAmberLens:
        return {
          'bgColor': const Color(0xFF1E1E1E).withOpacity(0.95),
          'titleColor': const Color(0xFFE0E0E0),
          'contentColor': const Color(0xFFBDBDBD),
          'dateColor': _amberAccent,
          'iconColor': _amberAccent,
          'dashedLineColor': const Color(0x40FF9800),
          'shadows': [
            const BoxShadow(
              color: Colors.black,
              offset: Offset(0, 4),
              blurRadius: 8,
            ),
          ],
          'hoverShadows': [
            const BoxShadow(
              color: Color(0x66FF9800),
              offset: Offset(0, 0),
              blurRadius: 15,
              spreadRadius: 1,
            ),
            const BoxShadow(
              color: Colors.black,
              offset: Offset(0, 10),
              blurRadius: 20,
            ),
          ],
          'border': Border.all(color: const Color(0xFF424242)),
          'hoverBorderColor': _amberAccent,
          'dateWeight': FontWeight.w600,
          'glassEffect': false,
          'glassColor': Colors.transparent,
          'blurSigma': 0.0,
          'borderRadius': 6.0,
          'hoverTranslateY': -4.0,
          'hoverScale': 1.0,
          'showStarWatermark': false,
          'showFlowerWatermark': false,
          'usePaperContainer': false,
        };
      case themeAfterRain:
        return {
          'bgColor': Colors.white.withOpacity(0.7), // See-through card
          'titleColor': _afterRainTextSecondary,
          'contentColor': _afterRainTextSecondary.withOpacity(0.9),
          'dateColor': _afterRainAccentBlue,
          'iconColor': _afterRainAccentBlue,
          'dashedLineColor': _afterRainAccentBlue.withOpacity(0.2),
          'shadows': [
            BoxShadow(
              color: _afterRainAccentBlue.withOpacity(
                0.08,
              ), // Cyan diffused shadow
              offset: const Offset(0, 6),
              blurRadius: 15,
              spreadRadius: -2,
            ),
          ],
          'hoverShadows': [
            BoxShadow(
              color: _afterRainAccentBlue.withOpacity(0.15),
              offset: const Offset(0, 10),
              blurRadius: 25,
              spreadRadius: -2,
            ),
          ],
          'border': Border.all(color: Colors.white, width: 1.5),
          'hoverBorderColor': null,
          'dateWeight': FontWeight.normal,
          'glassEffect': false,
          'glassColor': Colors.transparent,
          'blurSigma': 0.0,
          'borderRadius': 6.0,
          'hoverTranslateY': -4.0,
          'hoverScale': 1.0,
          'showStarWatermark': false,
          'showFlowerWatermark': false,
          'usePaperContainer': false,
        };
      case themeTwilight:
        return {
          'bgColor': _twilightSurface.withOpacity(0.6), // Dark glass
          'titleColor': _twilightTextPrimary,
          'contentColor': _twilightTextSecondary,
          'dateColor': _twilightAccentRed,
          'iconColor': _twilightAccentRed,
          'dashedLineColor': Colors.white.withOpacity(0.1),
          'shadows': [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
          'hoverShadows': [
            BoxShadow(
              color: _twilightAccentRed.withOpacity(0.2), // Red glow
              offset: const Offset(0, 8),
              blurRadius: 20,
            ),
          ],
          'border': Border.all(
            color: _twilightBgBottom.withOpacity(0.2),
            width: 1,
          ), // Subtle sunset border
          'hoverBorderColor': null,
          'dateWeight': FontWeight.normal,
          'glassEffect': true,
          'glassColor': _twilightSurface.withOpacity(0.6),
          'blurSigma': 10.0,
          'borderRadius': 12.0,
          'hoverTranslateY': -4.0,
          'hoverScale': 1.0,
          'showStarWatermark': false,
          'showFlowerWatermark': false,
          'usePaperContainer': false,
        };
      case themeGardenOfWords:
        return {
          'bgColor': const Color(0xFF455A64).withOpacity(0.3), // Dark Glass Card
          'titleColor': _gardenTextPrimary,
          'contentColor': _gardenTextSecondary,
          'dateColor': _gardenAccent,
          'iconColor': _gardenAccent,
          'dashedLineColor': Colors.white.withOpacity(0.1),
          'shadows': [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
          'hoverShadows': [
            BoxShadow(
              color: _gardenAccent.withOpacity(0.1),
              offset: const Offset(0, 8),
              blurRadius: 20,
            ),
          ],
          'border': Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          'hoverBorderColor': null,
          'dateWeight': FontWeight.normal,
          'glassEffect': false,
          'glassColor': Colors.transparent,
          'blurSigma': 0.0,
          'borderRadius': 6.0,
          'hoverTranslateY': -4.0,
          'hoverScale': 1.0,
          'showStarWatermark': false,
          'showFlowerWatermark': false,
          'usePaperContainer': false,
        };
      case themeDefault:
      default:
        return {
          'bgColor': _vintagePaper,
          'titleColor': const Color(0xFF5D4037),
          'contentColor': const Color(0xFF5D4037).withValues(alpha: 0.9),
          'dateColor': const Color(0xFF8D6E63),
          'iconColor': const Color(0xFF8D6E63),
          'dashedLineColor': const Color.fromRGBO(93, 64, 55, 0.15),
          'shadows': [
            const BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.1),
              offset: Offset(0, 5),
              blurRadius: 10,
            ),
          ],
          'hoverShadows': [
            const BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.15),
              offset: Offset(0, 10),
              blurRadius: 20,
            ),
          ],
          'border': null,
          'hoverBorderColor': null,
          'dateWeight': FontWeight.normal,
          'glassEffect': false,
          'glassColor': Colors.transparent,
          'blurSigma': 0.0,
          'borderRadius': 4.0,
          'hoverTranslateY': -4.0,
          'hoverScale': 1.0,
          'showStarWatermark': false,
          'showFlowerWatermark': false,
          'usePaperContainer': true,
        };
    }
  }

  static Map<String, dynamic> getMomentCardTheme(String theme) {
    switch (theme) {
      case themeSeaFlower:
        return _buildMomentCardTheme(
          cardColor: Colors.white.withValues(alpha: 0.82),
          textColor: const Color(0xFF880E4F),
          metaColor: const Color(0xFFAD1457).withValues(alpha: 0.65),
          iconColor: const Color(0xFFEC407A),
          cardShadows: [
            BoxShadow(
              color: const Color(0xFFF48FB1).withValues(alpha: 0.15),
              offset: const Offset(0, 6),
              blurRadius: 18,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              offset: const Offset(1, 2),
              blurRadius: 3,
            ),
          ],
          cardBorder: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          useGlassEffect: true,
          cardBlurSigma: 10,
          imageStackColor: Colors.white,
          imageStackBorderColor: const Color(0xFFF8BBD0).withValues(alpha: 0.6),
          imageStackShadow: BoxShadow(
            color: const Color(0xFFEC407A).withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(2, 4),
          ),
          imageSurfaceColor: const Color(0xFFFFF7FA),
          imageSurfaceShadow: BoxShadow(
            color: const Color(0xFFEC407A).withValues(alpha: 0.18),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
          indicatorActiveColor: const Color(0xFFEC407A),
          indicatorInactiveColor: const Color(
            0xFFF8BBD0,
          ).withValues(alpha: 0.7),
          watermarkDividerColor: const Color(0xFFF8BBD0).withValues(alpha: 0.4),
          audioSurfaceColor: Colors.white.withValues(alpha: 0.45),
          audioSurfaceBorderColor: const Color(
            0xFFF8BBD0,
          ).withValues(alpha: 0.6),
          audioButtonColor: const Color(0xFFEC407A),
          audioButtonIconColor: Colors.white,
          audioButtonShadow: BoxShadow(
            color: const Color(0xFFEC407A).withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
          audioProgressBgColor: const Color(0xFFF8BBD0).withValues(alpha: 0.45),
          audioProgressColor: const Color(0xFFEC407A).withValues(alpha: 0.75),
          audioDurationColor: const Color(0xFF880E4F).withValues(alpha: 0.65),
        );
      case themeMidnight:
        return _buildMomentCardTheme(
          cardColor: const Color(0xFF161B22).withValues(alpha: 0.95),
          textColor: _midnightTextPrimary,
          metaColor: _midnightTextSecondary,
          iconColor: _midnightAccent,
          cardShadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.54),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
            BoxShadow(
              color: _midnightAccent.withValues(alpha: 0.16),
              offset: const Offset(0, 0),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
          cardBorder: Border.all(color: const Color(0xFF30363D)),
          imageStackColor: const Color(0xFF1F242B),
          imageStackBorderColor: const Color(0xFF30363D),
          imageStackShadow: BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(2, 4),
          ),
          imageSurfaceColor: const Color(0xFF0D1117),
          imageSurfaceShadow: BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
          indicatorActiveColor: _midnightAccent,
          indicatorInactiveColor: Colors.white.withValues(alpha: 0.18),
          watermarkDividerColor: Colors.white.withValues(alpha: 0.1),
          audioSurfaceColor: const Color(0xFF0D1117).withValues(alpha: 0.72),
          audioSurfaceBorderColor: const Color(0xFF30363D),
          audioButtonColor: _midnightAccent,
          audioButtonIconColor: _midnightTextPrimary,
          audioButtonShadow: BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
          audioProgressBgColor: const Color(0xFF30363D),
          audioProgressColor: _midnightAccent.withValues(alpha: 0.7),
          audioDurationColor: _midnightTextSecondary.withValues(alpha: 0.9),
        );
      case themeAmberLens:
        return _buildMomentCardTheme(
          cardColor: const Color(0xFF1E1E1E).withValues(alpha: 0.96),
          textColor: _amberTextPrimary,
          metaColor: _amberTextSecondary,
          iconColor: _amberAccent,
          cardShadows: [
            const BoxShadow(
              color: Colors.black54,
              offset: Offset(0, 4),
              blurRadius: 8,
            ),
            BoxShadow(
              color: _amberAccent.withValues(alpha: 0.13),
              offset: const Offset(0, 0),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
          cardBorder: Border.all(color: _amberAccent.withValues(alpha: 0.18)),
          imageStackColor: const Color(0xFF2C2C2C),
          imageStackBorderColor: _amberAccent.withValues(alpha: 0.18),
          imageStackShadow: BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(2, 4),
          ),
          imageSurfaceColor: Colors.black12,
          imageSurfaceShadow: BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
          indicatorActiveColor: _amberAccent,
          indicatorInactiveColor: _amberTextSecondary.withValues(alpha: 0.45),
          watermarkDividerColor: Colors.white10,
          audioSurfaceColor: Colors.white.withValues(alpha: 0.06),
          audioSurfaceBorderColor: _amberAccent.withValues(alpha: 0.2),
          audioButtonColor: _amberAccent,
          audioButtonIconColor: _amberTextPrimary,
          audioButtonShadow: BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
          audioProgressBgColor: _amberTextSecondary.withValues(alpha: 0.25),
          audioProgressColor: _amberAccent.withValues(alpha: 0.75),
          audioDurationColor: _amberTextSecondary.withValues(alpha: 0.9),
        );
      case themeAfterRain:
        return _buildMomentCardTheme(
          cardColor: Colors.white.withValues(alpha: 0.78),
          textColor: _afterRainTextSecondary,
          metaColor: _afterRainTextSecondary.withValues(alpha: 0.65),
          iconColor: _afterRainAccentBlue,
          cardShadows: [
            BoxShadow(
              color: _afterRainAccentBlue.withValues(alpha: 0.08),
              offset: const Offset(0, 6),
              blurRadius: 15,
              spreadRadius: -2,
            ),
          ],
          cardBorder: Border.all(color: Colors.white, width: 1.2),
          useGlassEffect: true,
          cardBlurSigma: 8,
          imageStackColor: Colors.white.withValues(alpha: 0.92),
          imageStackBorderColor: _afterRainPrimaryLight.withValues(alpha: 0.8),
          imageStackShadow: BoxShadow(
            color: _afterRainAccentBlue.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(2, 4),
          ),
          imageSurfaceColor: const Color(0xFFF7FBFF),
          imageSurfaceShadow: BoxShadow(
            color: _afterRainAccentBlue.withValues(alpha: 0.15),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
          indicatorActiveColor: _afterRainAccentBlue,
          indicatorInactiveColor: _afterRainPrimaryLight.withValues(alpha: 0.6),
          watermarkDividerColor: _afterRainAccentBlue.withValues(alpha: 0.15),
          audioSurfaceColor: Colors.white.withValues(alpha: 0.58),
          audioSurfaceBorderColor: Colors.white,
          audioButtonColor: _afterRainAccentBlue,
          audioButtonIconColor: Colors.white,
          audioButtonShadow: BoxShadow(
            color: _afterRainAccentBlue.withValues(alpha: 0.2),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
          audioProgressBgColor: _afterRainPrimaryLight.withValues(alpha: 0.6),
          audioProgressColor: _afterRainAccentBlue.withValues(alpha: 0.75),
          audioDurationColor: _afterRainTextSecondary.withValues(alpha: 0.75),
        );
      case themeTwilight:
        return _buildMomentCardTheme(
          cardColor: _twilightSurface.withValues(alpha: 0.55),
          textColor: _twilightTextPrimary,
          metaColor: _twilightTextSecondary,
          iconColor: _twilightAccentRed,
          cardShadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
            BoxShadow(
              color: _twilightAccentRed.withValues(alpha: 0.16),
              offset: const Offset(0, 0),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
          cardBorder: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          useGlassEffect: true,
          cardBlurSigma: 10,
          imageStackColor: _twilightSurface.withValues(alpha: 0.82),
          imageStackBorderColor: _twilightAccentRed.withValues(alpha: 0.18),
          imageStackShadow: BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(2, 4),
          ),
          imageSurfaceColor: const Color(0xFF2C193A),
          imageSurfaceShadow: BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
          indicatorActiveColor: _twilightAccentRed,
          indicatorInactiveColor: Colors.white.withValues(alpha: 0.25),
          watermarkDividerColor: _twilightAccentRed.withValues(alpha: 0.18),
          audioSurfaceColor: _twilightSurface.withValues(alpha: 0.7),
          audioSurfaceBorderColor: Colors.white.withValues(alpha: 0.1),
          audioButtonColor: _twilightAccentRed,
          audioButtonIconColor: _twilightSurface,
          audioButtonShadow: BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
          audioProgressBgColor: Colors.white.withValues(alpha: 0.12),
          audioProgressColor: _twilightAccentRed.withValues(alpha: 0.75),
          audioDurationColor: _twilightTextSecondary.withValues(alpha: 0.85),
        );
      case themeGardenOfWords:
        return _buildMomentCardTheme(
          cardColor: _gardenSurface.withValues(alpha: 0.55),
          textColor: _gardenTextPrimary,
          metaColor: _gardenTextSecondary,
          iconColor: _gardenAccent,
          cardShadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
            BoxShadow(
              color: _gardenAccent.withValues(alpha: 0.12),
              offset: const Offset(0, 0),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
          cardBorder: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          useGlassEffect: true,
          cardBlurSigma: 9,
          imageStackColor: const Color(0xFF37474F).withValues(alpha: 0.9),
          imageStackBorderColor: _gardenAccent.withValues(alpha: 0.2),
          imageStackShadow: BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 4,
            offset: const Offset(2, 4),
          ),
          imageSurfaceColor: const Color(0xFF263238),
          imageSurfaceShadow: BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
          indicatorActiveColor: _gardenAccent,
          indicatorInactiveColor: Colors.white.withValues(alpha: 0.2),
          watermarkDividerColor: _gardenAccent.withValues(alpha: 0.15),
          audioSurfaceColor: _gardenSurface.withValues(alpha: 0.62),
          audioSurfaceBorderColor: _gardenAccent.withValues(alpha: 0.18),
          audioButtonColor: _gardenAccent,
          audioButtonIconColor: _gardenSurface,
          audioButtonShadow: BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
          audioProgressBgColor: Colors.white.withValues(alpha: 0.12),
          audioProgressColor: _gardenAccent.withValues(alpha: 0.7),
          audioDurationColor: _gardenTextSecondary.withValues(alpha: 0.9),
        );
      case themeDefault:
      default:
        return _buildMomentCardTheme(
          cardColor: _vintagePaper.withValues(alpha: 0.96),
          textColor: const Color(0xFF3E2723),
          metaColor: const Color(0xFF8D6E63),
          iconColor: const Color(0xFF8D6E63),
          cardShadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              offset: const Offset(1, 2),
              blurRadius: 3,
            ),
          ],
          cardBorder: Border.all(color: const Color(0xFFE7DCC8)),
          imageStackColor: Colors.white,
          imageStackBorderColor: const Color(0xFFE0D6C2),
          imageStackShadow: BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(2, 4),
          ),
          imageSurfaceColor: const Color(0xFFF5F1E8),
          imageSurfaceShadow: BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
          indicatorActiveColor: const Color(0xFF8D6E63),
          indicatorInactiveColor: const Color(
            0xFFBCAAA4,
          ).withValues(alpha: 0.7),
          watermarkDividerColor: Colors.black.withValues(alpha: 0.05),
          audioSurfaceColor: const Color(0xFF5D4037).withValues(alpha: 0.08),
          audioSurfaceBorderColor: const Color(
            0xFF5D4037,
          ).withValues(alpha: 0.15),
          audioButtonColor: const Color(0xFF8D6E63),
          audioButtonIconColor: Colors.white,
          audioButtonShadow: BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
          audioProgressBgColor: const Color(0xFF8D6E63).withValues(alpha: 0.2),
          audioProgressColor: const Color(0xFF8D6E63).withValues(alpha: 0.75),
          audioDurationColor: const Color(0xFF8D6E63).withValues(alpha: 0.8),
        );
    }
  }

  static Map<String, dynamic> _buildMomentCardTheme({
    required Color cardColor,
    required Color textColor,
    required Color metaColor,
    required Color iconColor,
    required List<BoxShadow> cardShadows,
    required Color imageStackColor,
    required Color imageStackBorderColor,
    required BoxShadow imageStackShadow,
    required Color imageSurfaceColor,
    required BoxShadow imageSurfaceShadow,
    required Color indicatorActiveColor,
    required Color indicatorInactiveColor,
    required Color watermarkDividerColor,
    required Color audioSurfaceColor,
    required Color audioSurfaceBorderColor,
    required Color audioButtonColor,
    required Color audioButtonIconColor,
    required BoxShadow audioButtonShadow,
    required Color audioProgressBgColor,
    required Color audioProgressColor,
    required Color audioDurationColor,
    Border? cardBorder,
    bool useGlassEffect = false,
    double cardBlurSigma = 0.001,
    Color? deleteIconColor,
  }) {
    return {
      'cardColor': cardColor,
      'textColor': textColor,
      'metaColor': metaColor,
      'iconColor': iconColor,
      'cardShadows': cardShadows,
      'cardBorder': cardBorder,
      'useGlassEffect': useGlassEffect,
      'cardBlurSigma': cardBlurSigma,
      'imageStackColor': imageStackColor,
      'imageStackBorderColor': imageStackBorderColor,
      'imageStackShadow': imageStackShadow,
      'imageSurfaceColor': imageSurfaceColor,
      'imageSurfaceShadow': imageSurfaceShadow,
      'indicatorActiveColor': indicatorActiveColor,
      'indicatorInactiveColor': indicatorInactiveColor,
      'watermarkDividerColor': watermarkDividerColor,
      'audioSurfaceColor': audioSurfaceColor,
      'audioSurfaceBorderColor': audioSurfaceBorderColor,
      'audioButtonColor': audioButtonColor,
      'audioButtonIconColor': audioButtonIconColor,
      'audioButtonShadow': audioButtonShadow,
      'audioProgressBgColor': audioProgressBgColor,
      'audioProgressColor': audioProgressColor,
      'audioDurationColor': audioDurationColor,
      'deleteIconColor': deleteIconColor ?? iconColor.withValues(alpha: 0.75),
    };
  }

  // 6. Directory Theme
  static Map<String, dynamic> getBookDirectoryTheme(String theme) {
    if (theme == themeGardenOfWords) {
      return {
        'inkColor': _gardenTextSecondary,
        'paperColor': _gardenSurface.withOpacity(0.95),
        'paperBorderColor': _gardenAccent.withOpacity(0.3),
        'paperShadow': [
          BoxShadow(
            color: _gardenAccent.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      };
    } else if (theme == themeTwilight) {
      return {
        'inkColor': _twilightTextPrimary,
        'paperColor': _twilightSurface.withOpacity(0.8),
        'paperBorderColor': Colors.white.withOpacity(0.1),
        'paperShadow': [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15),
        ],
      };
    } else if (theme == themeAfterRain) {
      return {
        'inkColor': _afterRainTextSecondary,
        'paperColor': _afterRainSurface.withOpacity(
          0.95,
        ), // Slightly opaque paper
        'paperBorderColor': Colors.white.withOpacity(0.8),
        'paperShadow': [
          BoxShadow(
            color: _afterRainAccentBlue.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      };
    }
    return {};
  }

  // 7. Moments Theme
  static Map<String, dynamic> getMomentsTheme(String theme) {
    switch (theme) {
      case themeSeaFlower:
        return {
          'rulerBg': Colors.white.withOpacity(0.9),
          'rulerTextColor': const Color(0xFF880E4F),
          'rulerInactiveTextColor': const Color(0xFF880E4F).withOpacity(0.4),
          'rulerSubTextColor': const Color(0xFF880E4F),
          'rulerInactiveSubTextColor': const Color(0xFF880E4F).withOpacity(0.4),
          'rulerIndicatorColor': const Color(0xFFF50057),
          'rulerShadowColor': const Color(0x1F880E4F),
          'rulerBorderColor': Colors.transparent,
          'appBarIconColor': const Color(0xFFD81B60),
          'appBarTextColor': const Color(0xFF880E4F),
          'drawerScrimColor': Colors.transparent,
          'appBarBg': const Color(0xFFFCE4EC).withOpacity(0.8),
        };
      case themeMidnight:
        return {
          'rulerBg': const Color(0xFF0D1117).withOpacity(0.95),
          'rulerTextColor': _midnightTextSecondary,
          'rulerInactiveTextColor': _midnightTextSecondary.withOpacity(0.3),
          'rulerSubTextColor': _midnightAccent,
          'rulerInactiveSubTextColor': _midnightAccent.withOpacity(0.3),
          'rulerIndicatorColor': _midnightAccent,
          'rulerShadowColor': Colors.black.withOpacity(0.4),
          'rulerBorderColor': Colors.white.withOpacity(0.1),
          'appBarIconColor': Colors.white70,
          'appBarTextColor': Colors.white,
          'drawerScrimColor': Colors.black54,
          'appBarBg': const Color(0xFF1E1E1E).withOpacity(0.5),
        };
      case themeAmberLens:
        return {
          'rulerBg': const Color(0xFF1E1E1E).withOpacity(0.95),
          'rulerTextColor': _amberTextSecondary,
          'rulerInactiveTextColor': _amberTextSecondary.withOpacity(0.3),
          'rulerSubTextColor': _amberAccent,
          'rulerInactiveSubTextColor': _amberAccent.withOpacity(0.3),
          'rulerIndicatorColor': _amberAccent,
          'rulerShadowColor': Colors.black.withOpacity(0.3),
          'rulerBorderColor': _amberAccent.withOpacity(0.15),
          'appBarIconColor': Colors.white70,
          'appBarTextColor': Colors.white,
          'drawerScrimColor': Colors.black54,
          'appBarBg': const Color(0xFF1E1E1E).withOpacity(0.5),
        };
      case themeAfterRain:
        return {
          'rulerBg': _afterRainSurface.withOpacity(0.8),
          'rulerTextColor': _afterRainTextSecondary,
          'rulerInactiveTextColor': _afterRainTextSecondary.withOpacity(0.3),
          'rulerSubTextColor': _afterRainAccentBlue,
          'rulerInactiveSubTextColor': _afterRainAccentBlue.withOpacity(0.3),
          'rulerIndicatorColor': _afterRainAccentBlue,
          'rulerShadowColor': _afterRainAccentBlue.withOpacity(0.1),
          'rulerBorderColor': Colors.white.withOpacity(0.5),
          'appBarIconColor': _afterRainTextSecondary,
          'appBarTextColor': _afterRainTextSecondary,
          'drawerScrimColor': Colors.transparent,
          'appBarBg': const Color(0xFFF0F8FF).withOpacity(0.6),
        };
      case themeTwilight:
        return {
          'rulerBg': _twilightSurface.withOpacity(0.9),
          'rulerTextColor': _twilightTextSecondary,
          'rulerInactiveTextColor': _twilightTextSecondary.withOpacity(0.3),
          'rulerSubTextColor': _twilightAccentRed,
          'rulerInactiveSubTextColor': _twilightAccentRed.withOpacity(0.3),
          'rulerIndicatorColor': _twilightAccentRed,
          'rulerShadowColor': Colors.black.withOpacity(0.2),
          'rulerBorderColor': Colors.white.withOpacity(0.1),
          'appBarIconColor': _twilightAccentRed,
          'appBarTextColor': _twilightTextPrimary,
          'drawerScrimColor': Colors.black54,
          'appBarBg': const Color(0xFF352044).withValues(alpha: 0.8),
        };
      case themeGardenOfWords:
        return {
          'rulerBg': const Color(0xFF263238).withOpacity(0.95),
          'rulerTextColor': _gardenTextSecondary,
          'rulerInactiveTextColor': _gardenTextSecondary.withOpacity(0.3),
          'rulerSubTextColor': _gardenAccent,
          'rulerInactiveSubTextColor': _gardenAccent.withOpacity(0.4),
          'rulerIndicatorColor': _gardenAccent,
          'rulerShadowColor': Colors.black.withOpacity(0.3),
          'rulerBorderColor': Colors.white.withOpacity(0.05),
          'appBarIconColor': _gardenTextPrimary,
          'appBarTextColor': _gardenTextPrimary,
          'drawerScrimColor': Colors.black54,
          'appBarBg': const Color(0xFF263238).withOpacity(0.8),
        };
      case themeDefault:
      default:
        return {
          'rulerBg': const Color(0xFF3E2723).withOpacity(0.9),
          'rulerTextColor': const Color(0xFFD7CCC8),
          'rulerInactiveTextColor': const Color(0xFFD7CCC8).withOpacity(0.3),
          'rulerSubTextColor': _vintageAccent,
          'rulerInactiveSubTextColor': _vintageAccent.withOpacity(0.3),
          'rulerIndicatorColor': _vintageAccent,
          'rulerShadowColor': Colors.black.withOpacity(0.3),
          'rulerBorderColor': Colors.white.withOpacity(0.08),
          'appBarIconColor': const Color(0xFFD7CCC8),
          'appBarTextColor': const Color(0xFFD7CCC8),
          'drawerScrimColor': Colors.black54,
          'appBarBg': const Color(0xFF1E1E1E).withOpacity(0.5),
        };
    }
  }

  // 8. Search Theme
  static Map<String, dynamic> getSearchTheme(String theme) {
    if (theme == themeGardenOfWords) {
      return {
        'bgColor': const Color(0xFF263238).withOpacity(0.5), // Dark glass
        'textColor': _gardenTextSecondary,
        'hintColor': _gardenTextSecondary.withOpacity(0.5),
        'iconColor': _gardenAccent,
        'border': Border.all(color: _gardenAccent.withOpacity(0.3), width: 1),
      };
    } else if (theme == themeTwilight) {
      return {
        'bgColor': Colors.black.withOpacity(0.2), // Darker inner shadow effect
        'textColor': _twilightTextPrimary,
        'hintColor': _twilightTextSecondary.withOpacity(0.5),
        'iconColor': _twilightAccentRed,
        'border': Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      };
    } else if (theme == themeAfterRain) {
      return {
        'bgColor': Colors.white.withOpacity(0.6),
        'textColor': _afterRainTextSecondary,
        'hintColor': _afterRainTextSecondary.withOpacity(0.4),
        'iconColor': _afterRainAccentBlue,
        'border': Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
      };
    }
    return {};
  }

  // 9. Month Divider Theme
  static Map<String, dynamic> getMonthDividerTheme(String theme) {
    if (theme == themeGardenOfWords) {
      return {
        'textColor': _gardenTextPrimary, // Soft white/grey instead of green
        'lineColor': _gardenAccent.withOpacity(0.4),
        'paperColor': _gardenSurface.withOpacity(0.8),
        'shadows': [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      };
    } else if (theme == themeTwilight) {
      return {
        'textColor':
            _twilightTextPrimary, // Softer white instead of stinging red
        'lineColor': _twilightAccentRed.withOpacity(0.4),
        'paperColor': _twilightSurface.withOpacity(0.7),
        'shadows': [
          BoxShadow(
            color: _twilightAccentRed.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      };
    } else if (theme == themeAfterRain) {
      return {
        'textColor': _afterRainTextSecondary,
        'lineColor': _afterRainAccentBlue.withOpacity(0.2),
        'paperColor': Colors.white.withOpacity(0.8),
        'shadows': [
          BoxShadow(
            color: _afterRainAccentBlue.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      };
    } else if (theme == themeMidnight) {
      return {
        'textColor': const Color(0xFFE8EAF6),
        'lineColor': const Color(0xFF5C6BC0).withOpacity(0.5),
        'paperColor': const Color(0xFF283593).withOpacity(0.9),
        'shadows': [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      };
    }
    return {};
  }

  // 10. Dialog Theme
  static Map<String, dynamic> getDialogTheme(String theme) {
    if (theme == themeGardenOfWords) {
      return {
        'paper': _gardenSurface.withOpacity(0.95), // Damp paper
        'title': _gardenTextPrimary,
        'text': _gardenTextSecondary,
        'icon': _gardenAccentDark,
        'tape': Colors.white.withOpacity(
          0.5,
        ), // Whitish translucent tape (like scotch tape)
        'shadow': Colors.black.withOpacity(0.15),
        'border': Colors.white.withOpacity(0.2),
        'primaryBtn': _gardenAccent,
        'primaryBtnText': Colors.white,
        'secondaryBtn': _gardenTextSecondary,
      };
    } else if (theme == themeTwilight) {
      return {
        'paper': _twilightSurface.withOpacity(0.95),
        'title': _twilightTextPrimary,
        'text': _twilightTextSecondary,
        'icon': _twilightAccentRed,
        'tape': _twilightAccentRed.withOpacity(0.3), // Red tape
        'shadow': _twilightAccentRed.withOpacity(0.2),
        'border': Colors.white.withOpacity(0.1),
        'primaryBtn': _twilightAccentRed,
        'primaryBtnText': _twilightSurface,
        'secondaryBtn': _twilightTextSecondary,
      };
    } else if (theme == themeAfterRain) {
      return {
        'paper': _afterRainSurface.withOpacity(0.95), // Frosted
        'title': _afterRainTextSecondary,
        'text': _afterRainTextSecondary,
        'icon': _afterRainAccentBlue,
        'tape': _afterRainPrimaryLight.withOpacity(0.4),
        'shadow': _afterRainAccentBlue.withOpacity(0.15),
        'border': Colors.white,
        'primaryBtn': _afterRainAccentBlue,
        'primaryBtnText': Colors.white,
        'secondaryBtn': _afterRainTextSecondary,
      };
    }
    return {};
  }

  // 11. Toast Theme
  static Map<String, dynamic> getToastTheme(String theme) {
    if (theme == themeGardenOfWords) {
      return {
        'success': {
          'bg': _gardenSurface,
          'border': _gardenAccent,
          'icon': _gardenAccent,
          'text': _gardenTextSecondary,
        },
        'error': {
          'bg': const Color(0xFFFFF0F0),
          'border': const Color(0xFFE57373),
          'icon': const Color(0xFFE57373),
          'text': _gardenTextSecondary,
        },
        'warning': {
          'bg': const Color(0xFFFFF8E1),
          'border': const Color(0xFFFFB74D),
          'icon': const Color(0xFFFFB74D),
          'text': _gardenTextSecondary,
        },
        'info': {
          'bg': _gardenSurface,
          'border': _gardenAccentDark,
          'icon': _gardenAccentDark,
          'text': _gardenTextSecondary,
        },
      };
    } else if (theme == themeTwilight) {
      return {
        'success': {
          'bg': _twilightSurface,
          'border': _twilightAccentRed,
          'icon': _twilightAccentRed,
          'text': _twilightTextPrimary,
        },
        'error': {
          'bg': _twilightSurface,
          'border': _twilightAccentRed,
          'icon': _twilightAccentRed,
          'text': _twilightTextPrimary,
        },
        'warning': {
          'bg': _twilightSurface,
          'border': Color(0xFFFFB74D),
          'icon': Color(0xFFFFB74D),
          'text': _twilightTextPrimary,
        },
        'info': {
          'bg': _twilightSurface,
          'border': _twilightAccentRed,
          'icon': _twilightAccentRed,
          'text': _twilightTextPrimary,
        },
      };
    } else if (theme == themeAfterRain) {
      return {
        'success': {
          'bg': _afterRainSurface,
          'border': _afterRainPrimaryMain,
          'icon': _afterRainPrimaryMain,
          'text': _afterRainTextSecondary,
        },
        'error': {
          'bg': Color(0xFFFFF0F0),
          'border': Color(0xFFE57373),
          'icon': Color(0xFFE57373),
          'text': _afterRainTextSecondary,
        },
        'warning': {
          'bg': Color(0xFFFFF8E1),
          'border': Color(0xFFFFB74D),
          'icon': Color(0xFFFFB74D),
          'text': _afterRainTextSecondary,
        },
        'info': {
          'bg': _afterRainSurface,
          'border': _afterRainAccentBlue,
          'icon': _afterRainAccentBlue,
          'text': _afterRainTextSecondary,
        },
      };
    }
    return {};
  }

  // 12. Lock Screen Theme
  // 12. Lock Screen Theme
  static Map<String, dynamic> getLockScreenTheme(String theme) {
    if (theme == themeGardenOfWords) {
      return {
        'displayBg': _gardenSurface.withOpacity(0.3), // Darker glass
        'displayBorder': _gardenAccent.withOpacity(0.3),
        'accentColor': _gardenAccent, // Grass Green
        'keyBg': _gardenSurface.withOpacity(0.4), // Frosted key
        'keyBorder': _gardenAccent.withOpacity(0.2),
        'keyText': _gardenTextSecondary,
      };
    } else if (theme == themeTwilight) {
      return {
        'displayBg': _twilightBgTop.withOpacity(0.3),
        'displayBorder': _twilightAccentRed.withOpacity(0.3),
        'accentColor': _twilightAccentRed,
        'keyBg': _twilightSurface.withOpacity(0.4),
        'keyBorder': _twilightAccentRed.withOpacity(0.2),
        'keyText': _twilightTextPrimary,
      };
    } else if (theme == themeAfterRain) {
      return {
        'displayBg': Colors.white.withOpacity(0.4),
        'displayBorder': Colors.white.withOpacity(0.6),
        'accentColor': _afterRainAccentBlue,
        'keyBg': Colors.white.withOpacity(0.5),
        'keyBorder': Colors.white.withOpacity(0.8),
        'keyText': _afterRainTextSecondary,
      };
    }
    return {};
  }

  static SystemUiOverlayStyle getSystemUiOverlayStyle(String theme) {
    switch (theme) {
      case themeGardenOfWords:
        return SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: _gardenSurface,
          systemNavigationBarIconBrightness: Brightness.dark,
        );
      case themeTwilight:
        return SystemUiOverlayStyle.light.copyWith(
          // White icons for dark bg
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: _twilightBgTop,
          systemNavigationBarIconBrightness: Brightness.light,
        );
      case themeSeaFlower:
        return SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: const Color(
            0xFFF6D9E6,
          ), // Match gradient near bottom
          systemNavigationBarIconBrightness: Brightness.dark,
        );
      case themeAfterRain:
        return SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: _afterRainSurface,
          systemNavigationBarIconBrightness: Brightness.dark,
        );
      case themeMidnight:
        return SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: const Color(0xFF000000), // _midnightBgEdge
          systemNavigationBarIconBrightness: Brightness.light,
        );
      case themeAmberLens:
        return SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: const Color(0xFF000000),
          systemNavigationBarIconBrightness: Brightness.light,
        );
      case themeDefault:
      default:
        return SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: const Color(0xFF2d241f), // _vintageBgEdge
          systemNavigationBarIconBrightness: Brightness.light,
        );
    }
  }

  static const String themeMidnight = 'midnight';
  static const String themeSeaFlower = 'sea_flower';

  // CSS Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.3),
      offset: Offset(0, 5), // Reduced offset
      blurRadius: 5, // Drastically reduced for performance testing
      spreadRadius: -2,
    ),
  ];

  static const List<BoxShadow> paperShadow = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.5),
      offset: Offset(0, 5), // Reduced offset
      blurRadius: 10, // Drastically reduced for performance testing (was 60)
      spreadRadius: 0,
    ),
  ];

  static BoxDecoration getBackground(String theme) {
    switch (theme) {
      case themeGardenOfWords:
        return const BoxDecoration(
          // Rainy Garden: Deep Blue Grey gradient top-down
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF37474F),
              Color(0xFF263238),
            ], // Rainy Sky -> Wet Stone
            stops: [0.0, 1.0],
          ),
          image: DecorationImage(
            image: AssetImage(
              'assets/textures/rainy_paper.png',
            ), // Use existing rainy paper texture
            fit: BoxFit.cover,
            opacity: 0.1, // Subtle texture on top of dark gradient
          ),
        );
      case themeTwilight:
        // 纯色渐变：深靛蓝 → 品红 → 落日橙，模拟黄昏天空
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_twilightBgTop, _twilightBgMid, _twilightBgBottom],
            stops: [0.0, 0.5, 1.0],
          ),
        );
      case themeMidnight:
        return BoxDecoration(
          color: _midnightBgEdge,
          gradient: const RadialGradient(
            center: Alignment(0, 0.5),
            radius: 1.2,
            colors: [_midnightBgCenter, _midnightBgMid, _midnightBgEdge],
            stops: [0.0, 0.4, 1.0],
          ),
        );
      case themeSeaFlower:
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFEFDFF),
              Color(0xFFF6D9E6),
              Color(0xFFDBBAD0),
              Color(0xFFCDA8C7),
            ],
            stops: [0.0, 0.3, 0.6, 1.0],
          ),
        );
      case themeAmberLens:
        return const BoxDecoration(
          color: _amberBgEdge,
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [_amberBgCenter, _amberBgEdge],
            stops: [0.0, 1.0],
          ),
        );
      case themeAfterRain:
        return const BoxDecoration(
          color: _afterRainSurface,
          image: DecorationImage(
            image: AssetImage('assets/textures/rainy_paper.png'),
            fit: BoxFit.cover,
            opacity: 0.8, // Blend with surface color
          ),
        );
      case themeDefault:
      default:
        return const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.25,
            colors: [_vintageBgCenter, _vintageBgEdge],
            stops: [0.0, 1.0],
          ),
        );
    }
  }

  static BoxDecoration getSidebarBackground(String theme) {
    switch (theme) {
      case themeGardenOfWords:
        return BoxDecoration(
          color: _gardenSurface.withOpacity(0.65),
          border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.4), width: 1),
          ),
        );
      case themeTwilight:
        return BoxDecoration(
          color: _twilightSurface.withOpacity(0.5), // Semi-transparent sidebar
          border: Border(
            right: BorderSide(
              color: _twilightBgBottom.withOpacity(0.2),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(2, 0),
              blurRadius: 10,
            ),
          ],
        );
      case themeMidnight:
        return BoxDecoration(
          color: const Color(0xFF0D1117).withValues(alpha: 0.7),
          border: const Border(right: BorderSide(color: Color(0x0DFFFFFF))),
          // Midnight特殊阴影效果
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.5),
              offset: Offset(1, 0),
              blurRadius: 15,
            ),
          ],
        );
      case themeSeaFlower:
        // 海底花海主题 - 毛玻璃效果（白色半透明）
        // 参考web端: background: rgba(255, 255, 255, 0.15)
        return BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          border: const Border(
            right: BorderSide(color: Color(0x4DFFFFFF), width: 1),
          ),
        );
      case themeAmberLens:
        return BoxDecoration(
          color: const Color(0xFF1E1E1E).withOpacity(0.85),
          border: const Border(
            right: BorderSide(color: Color(0xFFFF9800), width: 1),
          ), // Amber Border line
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(2, 0),
              blurRadius: 10,
            ),
          ],
        );
      case themeAfterRain:
        // Rain theme sidebar glass background
        return BoxDecoration(
          color: _afterRainSurface.withOpacity(0.65), // More transparent
          border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.4), width: 1),
          ),
        );
      case themeDefault:
      default:
        // 修复: 使用web端原设计 - 垂直渐变 (to bottom)
        // CSS: linear-gradient(to bottom, #3e2723, #281815)
        // 加上右边框和内阴影
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3e2723), Color(0xFF281815)],
          ),
          border: Border(right: BorderSide(color: Color(0xFF1a100d), width: 1)),
          boxShadow: [
            // 模拟 inset shadow 效果 - 右侧内阴影
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.3),
              offset: Offset(2, 0),
              blurRadius: 10,
              spreadRadius: -2,
            ),
          ],
        );
    }
  }

  static Color getPaperColor(String theme) {
    switch (theme) {
      case themeGardenOfWords:
        return _gardenSurface;
      case themeTwilight:
        return _twilightSurface;
      case themeMidnight:
        return _midnightPaper;
      case themeSeaFlower:
        return const Color(0xD9FFFFFF); // rgba(255, 255, 255, 0.85)
      case themeAmberLens:
        return _amberPaper;
      case themeAfterRain:
        return _afterRainSurface;
      default:
        return _vintagePaper;
    }
  }

  static Color getTextColor(String theme) {
    switch (theme) {
      case themeGardenOfWords:
        return _gardenTextSecondary;
      case themeTwilight:
        return _twilightTextPrimary;
      case themeMidnight:
        return _midnightTextPrimary;
      case themeSeaFlower:
        return const Color(0xFF880E4F);
      case themeAmberLens:
        return _amberTextPrimary;
      case themeAfterRain:
        return _afterRainTextSecondary; // User: "Main body text"
      default:
        return _vintageTextPrimary; // 恢复原来的深色文字
    }
  }

  static Color getTextSecondaryColor(String theme) {
    switch (theme) {
      case themeGardenOfWords:
        return _gardenAccentDark;
      case themeTwilight:
        return _twilightTextSecondary;
      case themeMidnight:
        return _midnightTextSecondary;
      case themeSeaFlower:
        return const Color(0xFFC2185B);
      case themeAmberLens:
        return _amberTextSecondary;
      case themeAfterRain:
        return _afterRainAccentBlue; // User: "Hint elements"
      default:
        return _vintageTextSecondary;
    }
  }

  static Color getAccentColor(String theme) {
    switch (theme) {
      case themeGardenOfWords:
        return _gardenAccent;
      case themeTwilight:
        return _twilightAccentRed;
      case themeMidnight:
        return _midnightAccent;
      case themeSeaFlower:
        return const Color(0xFFF50057);
      case themeAmberLens:
        return _amberAccent;
      case themeAfterRain:
        return _afterRainPrimaryMain; // User: "High frequency interaction"
      default:
        return _vintageAccent;
    }
  }

  // 移动端顶栏颜色配置
  static Map<String, Color> getMobileHeaderColors(String theme) {
    switch (theme) {
      case themeGardenOfWords:
        return {
          'background': _gardenSurface.withOpacity(0.9),
          'border': _gardenAccent.withOpacity(0.3), // Grass Green Divider
          'iconColor': _gardenAccentDark,
          'titleColor': _gardenTextSecondary,
          'subtitleColor': _gardenTextSecondary.withOpacity(0.7),
        };
      case themeTwilight:
        return {
          'background': _twilightBgTop.withOpacity(0.85),
          'border': Colors.white.withOpacity(0.1),
          'iconColor': _twilightAccentRed,
          'titleColor': _twilightTextPrimary,
          'subtitleColor': _twilightTextSecondary,
        };
      case themeMidnight:
        return {
          'background': const Color(0xFF0D1117).withOpacity(0.9),
          'border': const Color(0xFF21262d),
          'iconColor': const Color(0xFFc9d1d9),
          'titleColor': const Color(0xFFe6edf3),
          'subtitleColor': const Color(0xFF8b949e),
        };
      case themeSeaFlower:
        // 海底花海 - 毛玻璃效果，深色文字
        return {
          'background': const Color(
            0xFFFFFFFF,
          ).withOpacity(0.15), // Light glass matches sidebar
          'border': const Color(
            0x4DFFFFFF,
          ), // White semi-transparent border (Matches sidebar)
          'iconColor': const Color(0xFF880E4F), // Deep Pink
          'titleColor': const Color(0xFF880E4F), // Deep Pink
          'subtitleColor': const Color(0xCC880E4F), // Deep Pink opacity
        };
      case themeAmberLens:
        return {
          'background': const Color(0xFF1E1E1E).withOpacity(0.9),
          'border': const Color(0xFFFF9800).withOpacity(0.5),
          'iconColor': const Color(0xFFFF9800),
          'titleColor': const Color(0xFFE0E0E0),
          'subtitleColor': const Color(0xFF9E9E9E),
        };
      case themeAfterRain:
        return {
          'background': _afterRainSurface.withOpacity(0.85),
          'border': Colors.white.withOpacity(0.4),
          'iconColor': _afterRainAccentBlue,
          'titleColor': _afterRainTextSecondary,
          'subtitleColor': _afterRainTextSecondary.withOpacity(0.7),
        };
      default: // vintage/default
        return {
          'background': const Color(0xFF3e2723).withOpacity(0.85),
          'border': const Color(0xFF1a100d),
          'iconColor': const Color(0xFFD7CCC8),
          'titleColor': const Color(0xFFEEFFEB),
          'subtitleColor': const Color(0xFFD7CCC8).withOpacity(0.8),
        };
    }
  }

  // 12. Dialog Input Theme
  static Map<String, Color> getDialogInputTheme(String theme) {
    switch (theme) {
      case themeTwilight:
        return {
          'textColor': _twilightTextPrimary,
          'hintColor': _twilightTextSecondary.withOpacity(0.5),
          'borderColor': _twilightAccentRed.withOpacity(0.3),
          'focusedBorderColor': _twilightAccentRed,
          'iconColor': _twilightAccentRed.withOpacity(0.6),
          'backgroundColor': const Color(0xFF352044).withOpacity(0.6),
          'descriptionColor': _twilightTextSecondary,
        };
      case themeGardenOfWords:
        return {
          'textColor': _gardenTextPrimary,
          'hintColor': _gardenTextSecondary.withOpacity(0.5),
          'borderColor': _gardenAccent.withOpacity(0.3),
          'focusedBorderColor': _gardenAccent,
          'iconColor': _gardenAccent.withOpacity(0.6),
          'backgroundColor': Colors.black.withOpacity(0.2),
          'descriptionColor': _gardenTextPrimary.withOpacity(0.7),
        };
      case themeMidnight:
        return {
          'textColor': Colors.white70,
          'hintColor': Colors.white30,
          'borderColor': Colors.white24,
          'focusedBorderColor': Colors.white54,
          'iconColor': Colors.white38,
          'backgroundColor': Colors.black.withOpacity(0.3),
          'descriptionColor': Colors.white54,
        };
      case themeAmberLens:
        return {
          'textColor': _amberTextPrimary,
          'hintColor': _amberTextSecondary.withOpacity(0.5),
          'borderColor': _amberAccent.withOpacity(0.4),
          'focusedBorderColor': _amberAccent,
          'iconColor': _amberAccent.withOpacity(0.6),
          'backgroundColor': Colors.black.withOpacity(0.3),
          'descriptionColor': _amberTextSecondary,
        };
      default:
        // Default / Light Themes
        final Color ink =
            (theme == themeSeaFlower)
                ? const Color(0xFF880E4F)
                : const Color(0xFF5D4037);
        return {
          'textColor': ink,
          'hintColor': ink.withOpacity(0.4),
          'borderColor': ink.withOpacity(0.2),
          'focusedBorderColor': ink.withOpacity(0.6),
          'iconColor': ink.withOpacity(0.4),
          'backgroundColor':
              (theme == themeSeaFlower)
                  ? const Color(0xFFFCE4EC).withOpacity(0.5)
                  : Colors.white.withOpacity(0.5),
          'descriptionColor': ink.withOpacity(0.7),
        };
    }
  }

  static ThemeData getThemeData(String theme) {
    // 1. Determine Background Color & Brightness
    Color scaffoldBg;
    Color seedColor;
    Brightness brightness;
    Color accentColor = getAccentColor(theme);

    if (theme == themeGardenOfWords) {
      seedColor = _gardenAccent;
      scaffoldBg = _gardenBgCenter; // Use the dark background color
      brightness = Brightness.dark; // Switch to Dark Mode
    } else if (theme == themeTwilight) {
      seedColor = _twilightBgMid;
      scaffoldBg =
          _twilightBgTop; // Base for scaffold, usually covered by container gradient
      brightness = Brightness.dark;
    } else if (theme == themeSeaFlower) {
      seedColor = const Color(0xFFF06292);
      scaffoldBg = const Color(0xFFF6D9E6); // Light Pink base
      brightness = Brightness.light;
    } else if (theme == themeMidnight) {
      seedColor = const Color(0xFF3949AB);
      scaffoldBg = const Color(0xFF050510); // Deep Black/Blue base
      brightness = Brightness.dark;
    } else if (theme == themeAmberLens) {
      seedColor = const Color(0xFFFF9800);
      scaffoldBg = const Color(0xFF1E1E1E); // Matte Black base
      brightness = Brightness.dark;
    } else if (theme == themeAfterRain) {
      seedColor = _afterRainPrimaryMain;
      scaffoldBg = _afterRainSurface;
      brightness = Brightness.light;
    } else {
      seedColor = Colors.brown;
      scaffoldBg = const Color(0xFF2d241f); // Dark Brown base
      brightness =
          Brightness.dark; // Vintage is Dark mode by default for contrast
    }

    // 2. Build ThemeData
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness:
            brightness, // Ensures correct onSurface colors (White text on Dark bg)
        surface: scaffoldBg,
      ),

      // 3. Text Selection Theme (High Contrast)
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accentColor,
        selectionColor: accentColor.withOpacity(0.4),
        selectionHandleColor: accentColor,
      ),

      // 1:1 Noto Serif SC restoration
      textTheme: GoogleFonts.notoSerifScTextTheme(
        brightness == Brightness.dark
            ? ThemeData.dark().textTheme
            : ThemeData.light().textTheme,
      ),

      // 4. Custom Page Transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SkeuomorphicPageTransitionsBuilder(),
          TargetPlatform.iOS: _SkeuomorphicPageTransitionsBuilder(),
          TargetPlatform.windows: _SkeuomorphicPageTransitionsBuilder(),
        },
      ),
    );
  }

  // 13. Statistics Theme
  static Map<String, dynamic> getStatisticsTheme(String theme) {
    if (theme == themeGardenOfWords) {
      return {
        'cardBackground': BoxDecoration(
          color: const Color(0xFF263238).withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        'cardShadow': BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 15,
          offset: const Offset(0, 6),
          spreadRadius: -2,
        ),
        'cardBorder': Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        'accentColor': _gardenAccent,
        'textColor': _gardenTextPrimary,
        'secondaryTextColor': _gardenTextSecondary,
        'chartColor': _gardenAccent,
        'badgeStyle': {
          'backgroundColor': _gardenAccent.withOpacity(0.2),
          'textColor': _gardenAccent,
          'borderColor': _gardenAccent.withOpacity(0.3),
        },
      };
    } else if (theme == themeTwilight) {
      return {
        'cardBackground': BoxDecoration(
          color: _twilightSurface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _twilightBgBottom.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _twilightAccentRed.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 0),
              spreadRadius: -2,
            ),
          ],
        ),
        'cardShadow': BoxShadow(
          color: _twilightAccentRed.withOpacity(0.2),
          blurRadius: 20,
          offset: const Offset(0, 0),
          spreadRadius: -2,
        ),
        'cardBorder': Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        'accentColor': _twilightAccentRed,
        'textColor': _twilightTextPrimary,
        'secondaryTextColor': _twilightTextSecondary,
        'chartColor': _twilightAccentRed,
        'badgeStyle': {
          'backgroundColor': _twilightAccentRed.withOpacity(0.2),
          'textColor': _twilightAccentRed,
          'borderColor': _twilightAccentRed.withOpacity(0.3),
        },
      };
    } else if (theme == themeAfterRain) {
      return {
        'cardBackground': BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
        ),
        'cardShadow': BoxShadow(
          color: _afterRainAccentBlue.withOpacity(0.15),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
        'cardBorder': Border.all(
          color: Colors.white.withOpacity(0.8),
          width: 1.5,
        ),
        'accentColor': _afterRainAccentBlue,
        'textColor': _afterRainTextSecondary,
        'secondaryTextColor': _afterRainTextSecondary.withOpacity(0.7),
        'chartColor': _afterRainPrimaryMain,
        'badgeStyle': {
          'backgroundColor': _afterRainPrimaryLight.withOpacity(0.4),
          'textColor': _afterRainAccentBlue,
          'borderColor': _afterRainAccentBlue.withOpacity(0.3),
        },
      };
    } else if (theme == themeSeaFlower) {
      return {
        'cardBackground': BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFCE4EC), Color(0xFFF8BBD0)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
        ),
        'cardShadow': const BoxShadow(
          color: Color.fromRGBO(240, 98, 146, 0.2),
          blurRadius: 15,
          offset: Offset(0, 6),
          spreadRadius: -2,
        ),
        'cardBorder': Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 1,
        ),
        'accentColor': const Color(0xFFF06292),
        'textColor': const Color(0xFF880E4F),
        'secondaryTextColor': const Color(0xFFC2185B),
        'chartColor': const Color(0xFFF06292),
        'badgeStyle': {
          'backgroundColor': const Color(0xFFFCE4EC),
          'textColor': const Color(0xFFD81B60),
          'borderColor': const Color(0xFFF48FB1),
        },
      };
    } else if (theme == themeMidnight) {
      return {
        'cardBackground': BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a237e), Color(0xFF283593)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        'cardShadow': BoxShadow(
          color: const Color(0xFF7986cb).withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 0),
          spreadRadius: 2,
        ),
        'cardBorder': Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        'accentColor': const Color(0xFF7986cb),
        'textColor': const Color(0xFFe6edf3),
        'secondaryTextColor': const Color(0xFF8b949e),
        'chartColor': const Color(0xFF7986cb),
        'badgeStyle': {
          'backgroundColor': const Color(0xFF1a237e).withOpacity(0.6),
          'textColor': const Color(0xFF7986cb),
          'borderColor': const Color(0xFF7986cb).withOpacity(0.3),
        },
      };
    } else if (theme == themeAmberLens) {
      return {
        'cardBackground': BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFF9800).withOpacity(0.3),
            width: 1,
          ),
        ),
        'cardShadow': BoxShadow(
          color: const Color(0xFFFF9800).withOpacity(0.2),
          blurRadius: 15,
          offset: const Offset(0, 6),
          spreadRadius: -2,
        ),
        'cardBorder': Border.all(
          color: const Color(0xFFFF9800).withOpacity(0.3),
          width: 1,
        ),
        'accentColor': const Color(0xFFFF9800),
        'textColor': const Color(0xFFE0E0E0),
        'secondaryTextColor': const Color(0xFF9E9E9E),
        'chartColor': const Color(0xFFFFB74D),
        'badgeStyle': {
          'backgroundColor': const Color(0xFFFF9800).withOpacity(0.2),
          'textColor': const Color(0xFFFF9800),
          'borderColor': const Color(0xFFFF9800).withOpacity(0.4),
        },
      };
    } else {
      // themeDefault (Vintage - 时光旧物)
      return {
        'cardBackground': BoxDecoration(
          color: _vintagePaper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF5D4037).withOpacity(0.2),
            width: 1,
          ),
        ),
        'cardShadow': BoxShadow(
          color: const Color(0xFF3E2723).withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, 4),
          spreadRadius: -2,
        ),
        'cardBorder': Border.all(
          color: const Color(0xFF5D4037).withOpacity(0.2),
          width: 1,
        ),
        'accentColor': const Color(0xFFFF3D00),
        'textColor': const Color(0xFF2C3E50),
        'secondaryTextColor': const Color(0xFF5D4037),
        'chartColor': const Color(0xFFFF3D00),
        'badgeStyle': {
          'backgroundColor': const Color(0xFFFF3D00).withOpacity(0.15),
          'textColor': const Color(0xFFFF3D00),
          'borderColor': const Color(0xFFFF3D00).withOpacity(0.3),
        },
      };
    }
  }

  // ==================== 回收站页面主题 ====================
  /// 回收站页面主题配置
  static Map<String, dynamic> getTrashPageTheme(String theme) {
    switch (theme) {
      case themeSeaFlower:
        return {
          'titleColor': const Color(0xFF880E4F),
          'iconColor': const Color(0xFFAD1457),
          'restoreColor': const Color(0xFFE91E63),
          'dangerColor': const Color(0xFFC2185B),
          'cardTitleColor': const Color(0xFF880E4F),
          'cardDateColor': const Color(0xFF880E4F).withOpacity(0.6),
          'cardDecoration': BoxDecoration(
            color: Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF48FB1).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        };
      case themeMidnight:
        return {
          'titleColor': _midnightTextPrimary,
          'iconColor': const Color(0xFFc9d1d9),
          'restoreColor': const Color(0xFF69f0ae),
          'dangerColor': const Color(0xFFff5252),
          'cardTitleColor': _midnightTextPrimary,
          'cardDateColor': _midnightTextPrimary.withOpacity(0.6),
          'cardDecoration': BoxDecoration(
            color: const Color(0xFF161b22).withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF30363d), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        };
      case themeAmberLens:
        return {
          'titleColor': const Color(0xFFE0E0E0),
          'iconColor': _amberAccent,
          'restoreColor': Colors.green,
          'dangerColor': Colors.redAccent,
          'cardTitleColor': const Color(0xFFE0E0E0),
          'cardDateColor': const Color(0xFFE0E0E0).withOpacity(0.6),
          'cardDecoration': BoxDecoration(
            color: const Color(0xFF2C2C2C).withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _amberAccent.withOpacity(0.3), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
        };
      case themeTwilight:
        return {
          'titleColor': _twilightTextPrimary,
          'iconColor': _twilightAccentRed,
          'restoreColor': _twilightAccentRed,
          'dangerColor': const Color(0xFFE91E63),
          'cardTitleColor': _twilightTextPrimary,
          'cardDateColor': _twilightTextPrimary.withOpacity(0.6),
          'cardDecoration': BoxDecoration(
            color: _twilightSurface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _twilightAccentRed.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
        };
      case themeGardenOfWords:
        return {
          'titleColor': _gardenTextPrimary,
          'iconColor': const Color(0xFF558B2F),
          'restoreColor': const Color(0xFF8BC34A),
          'dangerColor': const Color(0xFFE57373),
          'cardTitleColor': _gardenTextPrimary,
          'cardDateColor': _gardenTextPrimary.withOpacity(0.6),
          'cardDecoration': BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF8BC34A).withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8BC34A).withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        };
      case themeAfterRain:
        return {
          'titleColor': _afterRainTextSecondary,
          'iconColor': _afterRainAccentBlue,
          'restoreColor': _afterRainAccentBlue,
          'dangerColor': const Color(0xFFE57373),
          'cardTitleColor': _afterRainTextSecondary,
          'cardDateColor': _afterRainTextSecondary.withOpacity(0.6),
          'cardDecoration': BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
            boxShadow: [
              BoxShadow(
                color: _afterRainAccentBlue.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        };
      default: // Vintage
        return {
          'titleColor': _vintagePaper,
          'iconColor': const Color(0xFFD7CCC8),
          'restoreColor': Colors.green,
          'dangerColor': Colors.redAccent,
          'cardTitleColor': const Color(0xFF2d241f),
          'cardDateColor': const Color(0xFF5D4037).withOpacity(0.6),
          'cardDecoration': BoxDecoration(
            color: const Color(0xFFF4F0E6),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: const Color(0xFF5D4037).withOpacity(0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        };
    }
  }

  // ==================== 同步设置页面主题 ====================
  /// 同步设置页面主题配置
  static Map<String, dynamic> getSyncSettingsTheme(String theme) {
    switch (theme) {
      case themeSeaFlower:
        return {
          'titleColor': const Color(0xFF880E4F),
          'textColor': const Color(0xFFAD1457),
          'accentColor': const Color(0xFFD81B60),
          'lockBtnColor': const Color(0xFFAD1457),
          'switchTrackColor': Colors.pink[50]!,
          'switchThumbColor': Colors.white,
          'switchActiveText': const Color(0xFFAD1457),
          'switchInactiveText': const Color(0xFFAD1457).withOpacity(0.5),
          'primaryGradient': const LinearGradient(
            colors: [Color(0xFFF06292), Color(0xFFAD1457)],
          ),
          'primaryShadowColor': const Color(0xFFAD1457).withOpacity(0.3),
          'secondaryBtnColor': Colors.white.withOpacity(0.5),
          'secondaryBtnTextColor': const Color(0xFF880E4F),
          'secondaryBorderColor': const Color(0xFFAD1457).withOpacity(0.2),
          'tipsBgColor': Colors.white.withOpacity(0.2),
          'switchBgColor': Colors.white.withOpacity(0.4),
          'slidingSwitchShadowOpacity': 0.05,
          'thumbShadowOpacity': 0.1,
        };
      case themeMidnight:
        return {
          'titleColor': _midnightTextPrimary,
          'textColor': const Color(0xFFc9d1d9),
          'accentColor': _midnightAccent,
          'lockBtnColor': _midnightAccent,
          'switchTrackColor': const Color(0xFF0D1117),
          'switchThumbColor': const Color(0xFF37474F),
          'switchActiveText': _midnightAccent,
          'switchInactiveText': Colors.white54,
          'primaryGradient': const LinearGradient(
            colors: [Color(0xFF7986cb), Color(0xFF283593)],
          ),
          'primaryShadowColor': const Color(0xFF283593).withOpacity(0.4),
          'secondaryBtnColor': const Color(0xFF21262d),
          'secondaryBtnTextColor': const Color(0xFFc9d1d9),
          'secondaryBorderColor': Colors.white.withOpacity(0.1),
          'tipsBgColor': const Color(0xFF161b22).withOpacity(0.8),
          'switchBgColor': const Color(0xFF0D1117).withOpacity(0.5),
          'slidingSwitchShadowOpacity': 0.3,
          'thumbShadowOpacity': 0.3,
        };
      case themeAmberLens:
        return {
          'titleColor': const Color(0xFFE0E0E0),
          'textColor': const Color(0xFFD7CCC8),
          'accentColor': _amberAccent,
          'lockBtnColor': const Color(0xFF5D4037),
          'switchTrackColor': const Color(0xFFD7CCC8),
          'switchThumbColor': const Color(0xFFEFEBE9),
          'switchActiveText': const Color(0xFF5D4037),
          'switchInactiveText': const Color(0xFF5D4037).withOpacity(0.5),
          'primaryGradient': null,
          'primaryBtnColor': const Color(0xFF5D4037),
          'primaryShadowColor': Colors.black26,
          'secondaryBtnColor': Colors.white.withOpacity(0.2),
          'secondaryBtnTextColor': const Color(0xFF3E2723),
          'secondaryBorderColor': Colors.white.withOpacity(0.1),
          'tipsBgColor': Colors.white.withOpacity(0.2),
          'switchBgColor': Colors.black.withOpacity(0.05),
          'slidingSwitchShadowOpacity': 0.05,
          'thumbShadowOpacity': 0.1,
        };
      case themeAfterRain:
        return {
          'titleColor': _afterRainTextSecondary,
          'textColor': _afterRainTextSecondary,
          'accentColor': _afterRainAccentBlue,
          'lockBtnColor': _afterRainAccentBlue,
          'switchTrackColor': Colors.lightBlue[50]!,
          'switchThumbColor': Colors.white,
          'switchActiveText': _afterRainAccentBlue,
          'switchInactiveText': _afterRainAccentBlue.withOpacity(0.5),
          'primaryGradient': const LinearGradient(
            colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
          ),
          'primaryShadowColor': _afterRainAccentBlue.withOpacity(0.3),
          'secondaryBtnColor': Colors.white.withOpacity(0.6),
          'secondaryBtnTextColor': const Color(0xFF0277BD),
          'secondaryBorderColor': _afterRainAccentBlue.withOpacity(0.2),
          'tipsBgColor': Colors.white.withOpacity(0.2),
          'switchBgColor': Colors.black.withOpacity(0.05),
          'slidingSwitchShadowOpacity': 0.05,
          'thumbShadowOpacity': 0.1,
        };
      case themeTwilight:
        return {
          'titleColor': _twilightTextPrimary,
          'textColor': _twilightTextPrimary,
          'accentColor': _twilightAccentRed,
          'lockBtnColor': _twilightAccentRed,
          'switchTrackColor': _twilightSurface,
          'switchThumbColor': _twilightAccentRed,
          'switchActiveText': _twilightSurface,
          'switchInactiveText': _twilightAccentRed.withOpacity(0.6),
          'primaryGradient': const LinearGradient(
            colors: [Color(0xFFEF5350), Color(0xFFC62828)],
          ),
          'primaryShadowColor': _twilightAccentRed.withOpacity(0.3),
          'secondaryBtnColor': _twilightSurface.withOpacity(0.6),
          'secondaryBtnTextColor': _twilightAccentRed,
          'secondaryBorderColor': _twilightAccentRed.withOpacity(0.2),
          'tipsBgColor': _twilightSurface.withOpacity(0.8),
          'switchBgColor': _twilightSurface.withOpacity(0.6),
          'slidingSwitchShadowOpacity': 0.05,
          'thumbShadowOpacity': 0.1,
        };
      case themeGardenOfWords:
        return {
          'titleColor': _gardenTextPrimary,
          'textColor': _gardenTextSecondary,
          'accentColor': _gardenAccent,
          'lockBtnColor': _gardenAccentDark,
          'switchTrackColor': const Color(0xFFF0F4F2),
          'switchThumbColor': const Color(0xFF8BC34A),
          'switchActiveText': const Color(0xFFF0F4F2),
          'switchInactiveText': const Color(0xFF5A6B72),
          'primaryGradient': const LinearGradient(
            colors: [Color(0xFF8BC34A), Color(0xFF558B2F)],
          ),
          'primaryShadowColor': const Color(0xFF8BC34A).withOpacity(0.3),
          'secondaryBtnColor': Colors.white.withOpacity(0.6),
          'secondaryBtnTextColor': const Color(0xFF2E4A35),
          'secondaryBorderColor': const Color(0xFF8BC34A).withOpacity(0.2),
          'tipsBgColor': Colors.white.withOpacity(0.2),
          'switchBgColor': Colors.black.withOpacity(0.05),
          'slidingSwitchShadowOpacity': 0.05,
          'thumbShadowOpacity': 0.1,
        };
      default: // Vintage
        return {
          'titleColor': _vintagePaper,
          'textColor': const Color(0xFFD7CCC8),
          'accentColor': const Color(0xFF795548),
          'lockBtnColor': const Color(0xFF5D4037),
          'switchTrackColor': const Color(0xFFD7CCC8),
          'switchThumbColor': const Color(0xFFEFEBE9),
          'switchActiveText': const Color(0xFF5D4037),
          'switchInactiveText': const Color(0xFF5D4037).withOpacity(0.5),
          'primaryGradient': null,
          'primaryBtnColor': const Color(0xFF5D4037),
          'primaryShadowColor': Colors.black26,
          'secondaryBtnColor': Colors.white.withOpacity(0.2),
          'secondaryBtnTextColor': const Color(0xFF3E2723),
          'secondaryBorderColor': Colors.white.withOpacity(0.1),
          'tipsBgColor': Colors.white.withOpacity(0.2),
          'switchBgColor': Colors.black.withOpacity(0.05),
          'slidingSwitchShadowOpacity': 0.05,
          'thumbShadowOpacity': 0.1,
        };
    }
  }

  static Map<String, dynamic> getMomentInputTheme(String theme) {
    switch (theme) {
      case themeSeaFlower:
        return _buildMomentInputTheme(
          containerColor: const Color(0xFFFCE4EC),
          containerShadows: const [
            BoxShadow(
              color: Colors.black12,
              offset: Offset(0, -2),
              blurRadius: 4,
            ),
          ],
          inputBgColor: Colors.white,
          inputBorderColor: const Color(0xFFF8BBD0),
          textColor: const Color(0xFF880E4F),
          hintColor: const Color(0xFF880E4F).withValues(alpha: 0.35),
          iconColor: const Color(0xFFD81B60),
          sendColor: const Color(0xFFEC407A),
          imageIconColor: const Color(0xFFD81B60),
          cursorColor: const Color(0xFFD81B60),
          cassetteDeckColor: const Color(0xFF5A2D45),
          cassetteDeckBorderColor: const Color(
            0xFFF48FB1,
          ).withValues(alpha: 0.45),
          cassetteLabelColor: const Color(0xFFFCE4EC),
          cassetteWindowBorderColor: const Color(0xFFF8BBD0),
          cassetteCounterColor: const Color(0xFFD81B60),
          miniCassetteBgColor: const Color(0xFF6A334F),
          miniCassettePlayColor: const Color(0xFFEC407A),
          miniCassetteTextColor: const Color(0xFFFCE4EC),
          miniCassetteHintColor: const Color(0xFFF8BBD0).withValues(alpha: 0.7),
          miniCassetteDeleteColor: const Color(
            0xFFF8BBD0,
          ).withValues(alpha: 0.8),
        );
      case themeMidnight:
        return _buildMomentInputTheme(
          containerColor: const Color(0xFF0D1117),
          containerShadows: const [
            BoxShadow(
              color: Colors.black45,
              offset: Offset(0, -1),
              blurRadius: 4,
            ),
          ],
          inputBgColor: const Color(0xFF161B22),
          inputBorderColor: const Color(0xFF30363D),
          textColor: const Color(0xFFc9d1d9),
          hintColor: const Color(0xFF8B949E).withValues(alpha: 0.7),
          iconColor: const Color(0xFF7986CB),
          sendColor: const Color(0xFF7986CB),
          imageIconColor: const Color(0xFF8B949E),
          cursorColor: const Color(0xFF7986CB),
          cassetteDeckColor: const Color(0xFF161B22),
          cassetteDeckBorderColor: const Color(0xFF30363D),
          cassetteLabelColor: const Color(0xFFE6EDF3),
          cassetteWindowBorderColor: const Color(
            0xFF7986CB,
          ).withValues(alpha: 0.45),
          cassetteCounterColor: const Color(0xFF7986CB),
          miniCassetteBgColor: const Color(0xFF161B22),
          miniCassettePlayColor: const Color(0xFF7986CB),
          miniCassetteTextColor: const Color(0xFFE6EDF3),
          miniCassetteHintColor: const Color(0xFF8B949E),
          miniCassetteDeleteColor: const Color(
            0xFF8B949E,
          ).withValues(alpha: 0.8),
        );
      case themeAmberLens:
        return _buildMomentInputTheme(
          containerColor: const Color(0xFF1E1E1E).withValues(alpha: 0.96),
          containerShadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              offset: const Offset(0, -2),
              blurRadius: 6,
            ),
            BoxShadow(
              color: _amberAccent.withValues(alpha: 0.12),
              offset: const Offset(0, -4),
              blurRadius: 12,
            ),
          ],
          inputBgColor: const Color(0xFF2C2C2C),
          inputBorderColor: _amberAccent.withValues(alpha: 0.3),
          textColor: _amberTextPrimary,
          hintColor: _amberTextSecondary,
          iconColor: _amberAccent,
          sendColor: _amberAccent,
          imageIconColor: const Color(0xFFFFB74D),
          cursorColor: _amberAccent,
          cassetteDeckColor: const Color(0xFF1E1E1E),
          cassetteDeckBorderColor: _amberAccent.withValues(alpha: 0.35),
          cassetteLabelColor: const Color(0xFFE0E0E0),
          cassetteWindowBorderColor: _amberAccent.withValues(alpha: 0.35),
          cassetteCounterColor: _amberAccent,
          miniCassetteBgColor: const Color(0xFF1E1E1E),
          miniCassettePlayColor: _amberAccent,
          miniCassetteTextColor: _amberTextPrimary,
          miniCassetteHintColor: _amberTextSecondary,
          miniCassetteDeleteColor: _amberTextSecondary.withValues(alpha: 0.8),
        );
      case themeAfterRain:
        return _buildMomentInputTheme(
          containerColor: const Color(0xFFF0F8FF).withValues(alpha: 0.9),
          containerShadows: [
            BoxShadow(
              color: const Color(0xFF0288D1).withValues(alpha: 0.1),
              offset: const Offset(0, -4),
              blurRadius: 10,
            ),
          ],
          inputBgColor: Colors.white,
          inputBorderColor: Colors.white,
          textColor: const Color(0xFF455A64),
          hintColor: const Color(0xFF90A4AE),
          iconColor: const Color(0xFF0288D1),
          sendColor: const Color(0xFF0288D1),
          imageIconColor: const Color(0xFF29B6F6),
          cursorColor: const Color(0xFF0288D1),
          cassetteDeckColor: const Color(0xFF37474F),
          cassetteDeckBorderColor: const Color(0xFFB3E5FC),
          cassetteLabelColor: const Color(0xFFEAF7FF),
          cassetteWindowBorderColor: const Color(0xFF90A4AE),
          cassetteCounterColor: const Color(0xFF0288D1),
          miniCassetteBgColor: const Color(0xFF37474F),
          miniCassettePlayColor: const Color(0xFF4FC3F7),
          miniCassetteTextColor: const Color(0xFFEAF7FF),
          miniCassetteHintColor: const Color(0xFFB0BEC5),
          miniCassetteDeleteColor: const Color(
            0xFFB0BEC5,
          ).withValues(alpha: 0.8),
        );
      case themeTwilight:
        return _buildMomentInputTheme(
          containerColor: const Color(0xFF352044).withValues(alpha: 0.9),
          containerShadows: [
            BoxShadow(
              color: const Color(0xFFFF5252).withValues(alpha: 0.1),
              offset: const Offset(0, -4),
              blurRadius: 10,
            ),
          ],
          inputBgColor: const Color(0xFF2D1E1B).withValues(alpha: 0.5),
          inputBorderColor: const Color(0xFFFF5252).withValues(alpha: 0.3),
          textColor: const Color(0xFFE4E0EC),
          hintColor: const Color(0xFFE4E0EC).withValues(alpha: 0.5),
          iconColor: const Color(0xFFFF5252),
          sendColor: const Color(0xFFFF5252),
          imageIconColor: const Color(0xFFFF5252),
          cursorColor: const Color(0xFFFF5252),
          cassetteDeckColor: const Color(0xFF24162D),
          cassetteDeckBorderColor: const Color(
            0xFFFF5252,
          ).withValues(alpha: 0.3),
          cassetteLabelColor: const Color(0xFFF3E5F5),
          cassetteWindowBorderColor: const Color(
            0xFFFF5252,
          ).withValues(alpha: 0.3),
          cassetteCounterColor: const Color(0xFFFF5252),
          miniCassetteBgColor: const Color(0xFF24162D).withValues(alpha: 0.95),
          miniCassettePlayColor: const Color(0xFFFF5252),
          miniCassetteTextColor: const Color(0xFFE4E0EC),
          miniCassetteHintColor: _twilightTextSecondary,
          miniCassetteDeleteColor: _twilightTextSecondary.withValues(
            alpha: 0.8,
          ),
        );
      case themeGardenOfWords:
        return _buildMomentInputTheme(
          containerColor: const Color(0xFF263238).withValues(alpha: 0.95),
          containerShadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              offset: const Offset(0, -4),
              blurRadius: 15,
            ),
          ],
          inputBgColor: const Color(0xFF37474F).withValues(alpha: 0.5),
          inputBorderColor: const Color(0xFF8BC34A).withValues(alpha: 0.3),
          textColor: const Color(0xFFECEFF1),
          hintColor: const Color(0xFFB0BEC5).withValues(alpha: 0.7),
          iconColor: const Color(0xFF8BC34A),
          sendColor: const Color(0xFF8BC34A),
          imageIconColor: const Color(0xFF8BC34A),
          cursorColor: const Color(0xFF8BC34A),
          cassetteDeckColor: const Color(0xFF263238),
          cassetteDeckBorderColor: const Color(
            0xFF8BC34A,
          ).withValues(alpha: 0.35),
          cassetteLabelColor: const Color(0xFFECEFF1),
          cassetteWindowBorderColor: const Color(
            0xFF8BC34A,
          ).withValues(alpha: 0.25),
          cassetteCounterColor: const Color(0xFF8BC34A),
          miniCassetteBgColor: const Color(0xFF263238).withValues(alpha: 0.95),
          miniCassettePlayColor: const Color(0xFF8BC34A),
          miniCassetteTextColor: const Color(0xFFECEFF1),
          miniCassetteHintColor: const Color(0xFFB0BEC5),
          miniCassetteDeleteColor: const Color(
            0xFFB0BEC5,
          ).withValues(alpha: 0.8),
        );
      case themeDefault:
      default:
        return _buildMomentInputTheme(
          containerColor: const Color(0xFF2D1E1B),
          containerShadows: const [
            BoxShadow(
              color: Colors.black38,
              offset: Offset(0, -2),
              blurRadius: 4,
            ),
          ],
          inputBgColor: const Color(0xFF3E2723),
          inputBorderColor: const Color(0xFF5D4037),
          textColor: const Color(0xFFD7CCC8),
          hintColor: const Color(0xFFA1887F),
          iconColor: const Color(0xFFD7CCC8),
          sendColor: Colors.white,
          imageIconColor: const Color(0xFFA1887F),
          cursorColor: _vintageAccent,
          cassetteDeckColor: const Color(0xFF2D1E1B),
          cassetteDeckBorderColor: const Color(0xFF5D4037),
          cassetteLabelColor: _vintagePaper,
          cassetteWindowBorderColor: const Color(0xFF8D6E63),
          cassetteCounterColor: _vintageAccent.withValues(alpha: 0.85),
          miniCassetteBgColor: const Color(0xFF3E2723),
          miniCassettePlayColor: const Color(0xFFD7CCC8),
          miniCassetteTextColor: const Color(0xFFD7CCC8),
          miniCassetteHintColor: const Color(0xFFA1887F),
          miniCassetteDeleteColor: const Color(
            0xFFA1887F,
          ).withValues(alpha: 0.8),
        );
    }
  }

  static Map<String, dynamic> _buildMomentInputTheme({
    required Color containerColor,
    required List<BoxShadow> containerShadows,
    required Color inputBgColor,
    required Color inputBorderColor,
    required Color textColor,
    required Color hintColor,
    required Color iconColor,
    required Color sendColor,
    Color? imageIconColor,
    Color? cursorColor,
    Color? recordingColor,
    Color? cancelColor,
    Color? imageRemoveIconColor,
    Color? imageRemoveBgColor,
    Color? cassetteDeckColor,
    Color? cassetteDeckBorderColor,
    List<BoxShadow>? cassetteDeckShadows,
    Color? cassetteLabelColor,
    Color? cassetteWindowColor,
    Color? cassetteWindowBorderColor,
    Color? cassetteBridgeColor,
    Color? cassetteCounterColor,
    Color? screwColor,
    Color? miniCassetteBgColor,
    Color? miniCassettePlayColor,
    Color? miniCassetteTextColor,
    Color? miniCassetteHintColor,
    Color? miniCassetteDeleteColor,
  }) {
    final deckColor = cassetteDeckColor ?? const Color(0xFF222222);
    return {
      'containerColor': containerColor,
      'containerShadows': containerShadows,
      'inputBgColor': inputBgColor,
      'inputBorderColor': inputBorderColor,
      'textColor': textColor,
      'hintColor': hintColor,
      'iconColor': iconColor,
      'sendColor': sendColor,
      'imageIconColor': imageIconColor ?? iconColor,
      'cursorColor': cursorColor ?? sendColor,
      'recordingColor': recordingColor ?? const Color(0xFFE53935),
      'cancelColor': cancelColor ?? hintColor,
      'imageRemoveBgColor':
          imageRemoveBgColor ?? Colors.black.withValues(alpha: 0.45),
      'imageRemoveIconColor': imageRemoveIconColor ?? Colors.white,
      'cassetteDeckColor': deckColor,
      'cassetteDeckBorderColor':
          cassetteDeckBorderColor ?? iconColor.withValues(alpha: 0.35),
      'cassetteDeckShadows':
          cassetteDeckShadows ??
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.08),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
      'cassetteLabelColor':
          cassetteLabelColor ?? containerColor.withValues(alpha: 0.95),
      'cassetteWindowColor': cassetteWindowColor ?? Colors.black87,
      'cassetteWindowBorderColor':
          cassetteWindowBorderColor ?? inputBorderColor,
      'cassetteBridgeColor': cassetteBridgeColor ?? Colors.black,
      'cassetteCounterColor': cassetteCounterColor ?? sendColor,
      'cassetteScrewColor': screwColor ?? Colors.white.withValues(alpha: 0.24),
      'miniCassetteBgColor': miniCassetteBgColor ?? deckColor,
      'miniCassettePlayColor': miniCassettePlayColor ?? iconColor,
      'miniCassetteTextColor': miniCassetteTextColor ?? textColor,
      'miniCassetteHintColor': miniCassetteHintColor ?? hintColor,
      'miniCassetteDeleteColor':
          miniCassetteDeleteColor ?? hintColor.withValues(alpha: 0.8),
    };
  }

  // ==================== 瞬间编辑器页面主题 ====================
  /// 瞬间编辑器页面主题配置
  static Map<String, dynamic> getMomentEditorTheme(String theme) {
    if (theme == themeGardenOfWords) {
      return {
        'bgColor': _gardenSurface.withOpacity(0.95),
        'appBarTextColor': _gardenTextSecondary,
        'appBarIconColor': _gardenTextSecondary,
        'inputBg': Colors.white.withOpacity(0.7),
        'inputTextColor': _gardenTextSecondary,
        'hintColor': _gardenTextSecondary.withOpacity(0.5),
        'dropdownBg': Colors.white.withOpacity(0.7),
        'dropdownIconColor': _gardenAccentDark,
        'dropdownMenuBg': _gardenSurface,
        'dropdownItemColor': _gardenTextSecondary,
        'photoEmptyColor': _gardenAccent.withOpacity(0.1),
        'photoIconColor': _gardenAccentDark,
      };
    } else if (theme == themeTwilight) {
      return {
        'bgColor': _twilightSurface,
        'appBarTextColor': _twilightTextPrimary,
        'appBarIconColor': _twilightTextPrimary,
        'inputBg': Colors.black.withOpacity(0.2),
        'inputTextColor': _twilightTextPrimary,
        'hintColor': _twilightTextSecondary.withOpacity(0.6),
        'dropdownBg': Colors.black.withOpacity(0.2),
        'dropdownIconColor': _twilightAccentRed,
        'dropdownMenuBg': _twilightBgTop,
        'dropdownItemColor': _twilightTextPrimary,
        'photoEmptyColor': Colors.white.withOpacity(0.05),
        'photoIconColor': _twilightAccentRed,
      };
    } else if (theme == themeAfterRain) {
      return {
        'bgColor': _afterRainSurface,
        'appBarTextColor': _afterRainTextSecondary,
        'appBarIconColor': _afterRainTextSecondary,
        'inputBg': Colors.white.withOpacity(0.6),
        'inputTextColor': _afterRainTextSecondary,
        'hintColor': _afterRainTextSecondary.withOpacity(0.5),
        'dropdownBg': Colors.white.withOpacity(0.6),
        'dropdownIconColor': _afterRainAccentBlue,
        'dropdownMenuBg': _afterRainSurface,
        'dropdownItemColor': _afterRainTextSecondary,
        'photoEmptyColor': _afterRainAccentBlue.withOpacity(0.05),
        'photoIconColor': _afterRainAccentBlue,
      };
    }
    // Default Vintage
    return {
      'bgColor': const Color(0xFFF4ECD8),
      'appBarTextColor': const Color(0xFF5D4037),
      'appBarIconColor': const Color(0xFF5D4037),
      'inputBg': Colors.white.withOpacity(0.5),
      'inputTextColor': const Color(0xFF3E2723),
      'hintColor': const Color(0xFF3E2723).withOpacity(0.5),
      'dropdownBg': Colors.white.withOpacity(0.5),
      'dropdownIconColor': const Color(0xFF8D6E63),
      'dropdownMenuBg': const Color(0xFFF4ECD8),
      'dropdownItemColor': const Color(0xFF5D4037),
      'photoEmptyColor': Colors.white.withOpacity(0.3),
      'photoIconColor': const Color(0xFF8D6E63),
    };
  }

  // ==================== 下拉刷新指示器主题 ====================
  /// 下拉刷新翻书动画主题配置
  static Map<String, dynamic> getRefreshIndicatorTheme(String theme) {
    switch (theme) {
      case themeSeaFlower:
        return {
          'bookColor': const Color(0xFFAD1457),
          'pageColor': const Color(0xFFFCE4EC),
          'textColor': const Color(0xFFAD1457),
        };
      case themeMidnight:
        return {
          'bookColor': const Color(0xFF5C6BC0),
          'pageColor': const Color(0xFFE8EAF6),
          'textColor': const Color(0xFFB0BEC5),
        };
      case themeAmberLens:
        return {
          'bookColor': const Color(0xFFFF6F00),
          'pageColor': const Color(0xFF424242),
          'textColor': const Color(0xFFFFB74D),
        };
      case themeAfterRain:
        return {
          'bookColor': const Color(0xFF0288D1),
          'pageColor': const Color(0xFFF0F8FF),
          'textColor': const Color(0xFF455A64),
        };
      case themeTwilight:
        return {
          'bookColor': const Color(0xFF352044),
          'pageColor': const Color(0xFF2D1E1B),
          'textColor': const Color(0xFFFF5252),
        };
      case themeGardenOfWords:
        return {
          'bookColor': const Color(0xFF2E4A35),
          'pageColor': const Color(0xFFF0F4F2),
          'textColor': const Color(0xFF5A6B72),
        };
      case themeDefault:
      default:
        return {
          'bookColor': const Color(0xFF6D4C41),
          'pageColor': const Color(0xFFFAF8F5),
          'textColor': const Color(0xFF8D6E63),
        };
    }
  }

  // ==================== 隐私协议弹窗主题 ====================
  /// 隐私协议弹窗主题配置
  static Map<String, dynamic> getPrivacyDialogTheme(String theme) {
    switch (theme) {
      case themeSeaFlower:
        return {
          'linkColor': const Color(0xFFAD1457),
          'contentTextColor': const Color(0xFFAD1457),
          'disclaimerTextColor': const Color(0xFFAD1457).withOpacity(0.7),
        };
      case themeMidnight:
        return {
          'linkColor': const Color(0xFF7986cb),
          'contentTextColor': const Color(0xFFc9d1d9),
          'disclaimerTextColor': const Color(0xFF8b949e),
        };
      case themeAmberLens:
        return {
          'linkColor': const Color(0xFFFF9800),
          'contentTextColor': const Color(0xFFBDBDBD),
          'disclaimerTextColor': const Color(0xFF9E9E9E),
        };
      case themeAfterRain:
        return {
          'linkColor': const Color(0xFF0288D1),
          'contentTextColor': const Color(0xFF455A64),
          'disclaimerTextColor': const Color(0xFF78909C),
        };
      case themeTwilight:
        return {
          'linkColor': const Color(0xFFFF5252),
          'contentTextColor': const Color(0xFFE4E0EC),
          'disclaimerTextColor': const Color(0xFFBCAAA4),
        };
      case themeGardenOfWords:
        return {
          'linkColor': const Color(0xFF81C784),
          'contentTextColor': const Color(0xFFB0BEC5),
          'disclaimerTextColor': const Color(0xFF78909C),
        };
      case themeDefault:
      default:
        return {
          'linkColor': const Color(0xFF6D4C41),
          'contentTextColor': const Color(0xFF5D4037),
          'disclaimerTextColor': const Color(0xFF8D6E63),
        };
    }
  }

  // ==================== 纸张容器主题 ====================
  /// 纸张容器（PaperSheet）主题配置
  static Map<String, dynamic> getPaperSheetTheme(String theme) {
    switch (theme) {
      case themeSeaFlower:
        return {
          'paperColor': Colors.white.withValues(alpha: 0.55),
          'accentColor': const Color(0xFFEC407A),
          'border': Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1),
          'shadows': <BoxShadow>[
            const BoxShadow(
              color: Color.fromRGBO(200, 150, 200, 0.2),
              offset: Offset(0, 8),
              blurRadius: 32,
            ),
          ],
          'borderRadius': 16.0,
          'useGlassEffect': true,
        };
      case themeMidnight:
        return {
          'paperColor': _midnightPaper,
          'accentColor': const Color(0xFF7986cb),
          'border': Border.all(color: const Color(0xFF30363d), width: 1),
          'shadows': <BoxShadow>[
            const BoxShadow(
              color: Colors.black,
              offset: Offset(0, 4),
              blurRadius: 20,
            ),
          ],
          'borderRadius': 2.0,
          'useGlassEffect': false,
        };
      case themeAmberLens:
        return {
          'paperColor': _amberPaper,
          'accentColor': const Color(0xFFFF9800),
          'border': Border.all(color: const Color(0xFFFF9800), width: 1),
          'shadows': <BoxShadow>[
            const BoxShadow(
              color: Colors.black,
              offset: Offset(0, 5),
              blurRadius: 20,
            ),
          ],
          'borderRadius': 2.0,
          'useGlassEffect': false,
        };
      case themeAfterRain:
        return {
          'paperColor': _afterRainSurface,
          'accentColor': const Color(0xFF29B6F6),
          'border': Border.all(color: const Color(0x339999BF), width: 1),
          'shadows': <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF8981AA).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          'borderRadius': 2.0,
          'useGlassEffect': false,
        };
      case themeTwilight:
        return {
          'paperColor': _twilightSurface,
          'accentColor': const Color(0xFFFF5252),
          'border': Border.all(color: const Color(0xFFFF5252).withOpacity(0.3), width: 1),
          'shadows': <BoxShadow>[
            BoxShadow(
              color: const Color(0xFFEF5350).withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          'borderRadius': 2.0,
          'useGlassEffect': false,
        };
      case themeGardenOfWords:
        return {
          'paperColor': _gardenSurface,
          'accentColor': const Color(0xFF8BC34A),
          'border': Border.all(color: const Color(0xFF8BC34A).withOpacity(0.3), width: 1),
          'shadows': <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF8BC34A).withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          'borderRadius': 2.0,
          'useGlassEffect': false,
        };
      case themeDefault:
      default:
        return {
          'paperColor': _vintagePaper,
          'accentColor': const Color(0xFFC0392B),
          'border': const Border(top: BorderSide(color: Color(0xFFC0392B), width: 8)),
          'shadows': paperShadow,
          'borderRadius': 2.0,
          'useGlassEffect': false,
        };
    }
  }

  // ==================== 日记列表页面主题 ====================
  /// 日记列表页面主题配置
  static Map<String, dynamic> getDiaryListPageTheme(String theme) {
    switch (theme) {
      case themeSeaFlower:
        return {
          'drawerScrimColor': Colors.transparent,
          'headerBoxShadow': <BoxShadow>[],
          'headerApplyBlur': true,
          'emptyStateIconColor': const Color(0xFF6D5D5D).withValues(alpha: 0.6),
          'emptyStateTextColor': const Color(0xFF6D5D5D).withValues(alpha: 0.8),
          'emptyStateLinkColor': const Color(0xFFC2185B),
          'updateDialogSecondaryColor': const Color(0xFFC2185B),
        };
      case themeMidnight:
        return {
          'drawerScrimColor': Colors.black54,
          'headerBoxShadow': <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          'headerApplyBlur': false,
          'emptyStateIconColor': Colors.grey.shade500.withValues(alpha: 0.7),
          'emptyStateTextColor': Colors.grey.shade400,
          'emptyStateLinkColor': AppTheme.getAccentColor(themeMidnight),
          'updateDialogSecondaryColor': const Color(0xFF8b949e),
        };
      case themeAmberLens:
        return {
          'drawerScrimColor': Colors.black54,
          'headerBoxShadow': <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          'headerApplyBlur': false,
          'emptyStateIconColor': Colors.grey.shade500.withValues(alpha: 0.7),
          'emptyStateTextColor': Colors.grey.shade400,
          'emptyStateLinkColor': AppTheme.getAccentColor(themeAmberLens),
          'updateDialogSecondaryColor': const Color(0xFF8D6E63),
        };
      case themeAfterRain:
        return {
          'drawerScrimColor': Colors.transparent,
          'headerBoxShadow': <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          'headerApplyBlur': false,
          'emptyStateIconColor': _afterRainAccentBlue.withValues(alpha: 0.6),
          'emptyStateTextColor': _afterRainAccentBlue.withValues(alpha: 0.8),
          'emptyStateLinkColor': _afterRainPrimaryMain,
          'updateDialogSecondaryColor': const Color(0xFF8D6E63),
        };
      case themeTwilight:
        return {
          'drawerScrimColor': Colors.black54,
          'headerBoxShadow': <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          'headerApplyBlur': false,
          'emptyStateIconColor': _twilightAccentRed.withValues(alpha: 0.5),
          'emptyStateTextColor': _twilightTextSecondary.withValues(alpha: 0.8),
          'emptyStateLinkColor': _twilightAccentRed,
          'updateDialogSecondaryColor': const Color(0xFF8D6E63),
        };
      case themeGardenOfWords:
        return {
          'drawerScrimColor': Colors.black54,
          'headerBoxShadow': <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          'headerApplyBlur': false,
          'emptyStateIconColor': _gardenAccentDark.withValues(alpha: 0.6),
          'emptyStateTextColor': _gardenAccentDark.withValues(alpha: 0.8),
          'emptyStateLinkColor': _gardenAccent,
          'updateDialogSecondaryColor': const Color(0xFF5A6B72),
        };
      case themeDefault:
      default:
        return {
          'drawerScrimColor': Colors.black54,
          'headerBoxShadow': <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          'headerApplyBlur': false,
          'emptyStateIconColor': const Color(0xFFD7CCC8).withValues(alpha: 0.5),
          'emptyStateTextColor': const Color(0xFFD7CCC8).withValues(alpha: 0.8),
          'emptyStateLinkColor': const Color(0xFFFF5252),
          'updateDialogSecondaryColor': const Color(0xFF8D6E63),
        };
    }
  }

  // ==================== 瞬间标准卡片主题（导出用） ====================
  /// 瞬间标准卡片（导出分享）主题配置
  static Map<String, dynamic> getMomentStandardCardTheme(String theme) {
    switch (theme) {
      case themeSeaFlower:
        return {
          'cardBg': Colors.white,
          'textColor': const Color(0xFF3E2723),
          'metaColor': Colors.grey[400]!,
        };
      case themeMidnight:
        return {
          'cardBg': const Color(0xFF1E1E1E),
          'textColor': const Color(0xFFE0E0E0),
          'metaColor': Colors.grey[400]!,
        };
      case themeAmberLens:
        return {
          'cardBg': const Color(0xFF1E1E1E),
          'textColor': const Color(0xFFE0E0E0),
          'metaColor': const Color(0xFF9E9E9E),
        };
      case themeAfterRain:
        return {
          'cardBg': Colors.white,
          'textColor': const Color(0xFF3E2723),
          'metaColor': Colors.grey[400]!,
        };
      case themeTwilight:
        return {
          'cardBg': Colors.white,
          'textColor': const Color(0xFF3E2723),
          'metaColor': Colors.grey[400]!,
        };
      case themeGardenOfWords:
        return {
          'cardBg': Colors.white,
          'textColor': const Color(0xFF3E2723),
          'metaColor': Colors.grey[400]!,
        };
      case themeDefault:
      default:
        return {
          'cardBg': Colors.white,
          'textColor': const Color(0xFF3E2723),
          'metaColor': Colors.grey[400]!,
        };
    }
  }

  // ==================== 日期选择器主题 ====================
  /// 拟物化日期选择器主题配置
  static Map<String, dynamic> getDatePickerTheme(String theme) {
    switch (theme) {
      case themeSeaFlower:
        return {
          'dialogBg': const Color(0xFFFFF0F5),
          'headerBg': const Color(0xFFF8BBD0),
          'headerText': const Color(0xFF880E4F),
          'bodyText': const Color(0xFF880E4F),
          'accentColor': const Color(0xFFF50057),
          'weekDayColor': const Color(0xFFAD1457),
          'border': Border.all(color: Colors.white, width: 2),
          'shadows': cardShadow,
        };
      case themeMidnight:
        return {
          'dialogBg': const Color(0xFF161b22),
          'headerBg': const Color(0xFF0D1117),
          'headerText': const Color(0xFFe6edf3),
          'bodyText': const Color(0xFFc9d1d9),
          'accentColor': const Color(0xFF7986cb),
          'weekDayColor': const Color(0xFF8b949e),
          'border': Border.all(color: const Color(0xFF30363d)),
          'shadows': <BoxShadow>[
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        };
      case themeAmberLens:
        return {
          'dialogBg': const Color(0xFF1E1E1E),
          'headerBg': Colors.black,
          'headerText': const Color(0xFFE0E0E0),
          'bodyText': const Color(0xFFBDBDBD),
          'accentColor': const Color(0xFFFF9800),
          'weekDayColor': const Color(0xFFFB8C00),
          'border': Border.all(color: const Color(0xFFFF9800), width: 1),
          'shadows': <BoxShadow>[],
        };
      case themeAfterRain:
        return {
          'dialogBg': const Color(0xFFF0F8FF),
          'headerBg': const Color(0xFFB3E5FC),
          'headerText': const Color(0xFF455A64),
          'bodyText': const Color(0xFF455A64),
          'accentColor': const Color(0xFF0288D1),
          'weekDayColor': const Color(0xFF0277BD),
          'border': Border.all(color: Colors.white, width: 2),
          'shadows': <BoxShadow>[
            BoxShadow(color: const Color(0xFF81D4FA).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        };
      case themeTwilight:
        return {
          'dialogBg': const Color(0xFF352044),
          'headerBg': const Color(0xFF2E1A3C),
          'headerText': const Color(0xFFEF5350),
          'bodyText': const Color(0xFFB39DDB),
          'accentColor': const Color(0xFFEF5350),
          'weekDayColor': const Color(0xFF90CAF9),
          'border': Border.all(color: const Color(0xFFEF5350).withOpacity(0.3), width: 1),
          'shadows': <BoxShadow>[
            BoxShadow(color: const Color(0xFFEF5350).withValues(alpha: 0.15), blurRadius: 15, offset: const Offset(0, 5)),
          ],
        };
      case themeGardenOfWords:
        return {
          'dialogBg': const Color(0xFFF0F4F2),
          'headerBg': const Color(0xFF2E4A35),
          'headerText': const Color(0xFFF0F4F2),
          'bodyText': const Color(0xFF5A6B72),
          'accentColor': const Color(0xFF8BC34A),
          'weekDayColor': const Color(0xFF1B3321),
          'border': Border.all(color: const Color(0xFF8BC34A).withValues(alpha: 0.3), width: 1),
          'shadows': <BoxShadow>[
            BoxShadow(color: const Color(0xFF8BC34A).withValues(alpha: 0.15), blurRadius: 15, offset: const Offset(0, 5)),
          ],
        };
      case themeDefault:
      default:
        return {
          'dialogBg': const Color(0xFFF4ECD8),
          'headerBg': const Color(0xFF5D4037),
          'headerText': const Color(0xFFF4ECD8),
          'bodyText': const Color(0xFF5D4037),
          'accentColor': const Color(0xFFD32F2F),
          'weekDayColor': const Color(0xFF795548),
          'border': Border.all(color: const Color(0xFF3E2723), width: 1),
          'shadows': cardShadow,
        };
    }
  }
}

/// 自定义的拟物风转场动画
/// 特征：沉稳、有分量感。
/// 效果：
/// 1. Fade: 0% -> 100%
/// 2. Slide: 从下方 20px (0.05 height) 缓慢上浮至位置，模拟取出纸张的感觉。
/// 3. Curve: easeOutQuart (快速启动，极慢停止，如同有摩擦力的物理运动)
class _SkeuomorphicPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SkeuomorphicPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 进场动画
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.05), // Start slightly below (5% height)
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuart, // Heavy, physical feel
        ),
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve:
              Curves
                  .easeOut, // Linear fade is usually best, but easeOut is softer
        ),
        child: child,
      ),
    );
  }
}
