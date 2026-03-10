import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const String themeDefault = 'default'; // Vintage (时光旧物)
  static const String themeAmberLens = 'amber_lens';
  static const String themeAfterRain = 'after_rain';
  static const String themeTwilight = 'twilight'; // Twilight (黄昏之时)
  static const String themeGardenOfWords = 'garden_of_words'; // Garden of Words (言叶之庭)

  // --- 1. Colors (CSS Variable Mapping) ---
  
  // Vintage Theme Colors
  static const Color _vintageBgCenter = Color(0xFF4a3b32);
  static const Color _vintageBgEdge = Color(0xFF2d241f);
  static const Color _vintageSidebarStart = Color(0xFF5d4037);
  static const Color _vintageSidebarMid = Color(0xFF4e342e);
  static const Color _vintageSidebarEnd = Color(0xFF3e2723);
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
  static const Color _afterRainPrimaryMain = Color(0xFF4FC3F7); // Fresh Sky Blue (Clear sky)
  static const Color _afterRainPrimaryLight = Color(0xFFB3E5FC); // Pale Blue (Water reflection)
  static const Color _afterRainSurface = Color(0xFFF0F8FF); // Alice Blue (Damp paper)
  static const Color _afterRainTextSecondary = Color(0xFF455A64); // Blue Grey (Wet stone)
  static const Color _afterRainAccentBlue = Color(0xFF0288D1); // Deep Lake Blue (Accent)



  // Twilight Theme Colors
  static const Color _twilightBgTop = Color(0xFF2E1C55); // Indigo
  static const Color _twilightBgMid = Color(0xFF913862); // Magenta
  static const Color _twilightBgBottom = Color(0xFFFF9A6C); // Sunset Orange
  static const Color _twilightAccentCyan = Color(0xFF4DD0E1); // Comet Blue
  static const Color _twilightAccentRed = Color(0xFFFF5252); // Musubi RedRed
  static const Color _twilightTextPrimary = Color(0xFFE4E0EC); // Stardust White
  static const Color _twilightTextSecondary = Color(0xFFBCAAA4); // Twilight Grey
  static const Color _twilightSurface = Color(0xFF352044); // Deep Purple GlassBase


  // Garden of Words Theme Colors (Redesigned: Rainy Garden - Dark Glass)
  static const Color _gardenBgCenter = Color(0xFF37474F); // Blue Grey 800
  static const Color _gardenBgEdge = Color(0xFF263238);   // Blue Grey 900
  static const Color _gardenSurface = Color(0xFF455A64);  // Blue Grey 700 (Base for glass)
  static const Color _gardenTextPrimary = Color(0xFFECEFF1); // Blue Grey 50 (Light Text)
  static const Color _gardenTextSecondary = Color(0xFFB0BEC5); // Blue Grey 200 (Sub Text)
  static const Color _gardenAccent = Color(0xFF81C784);   // Lighter Green for Dark Mode
  static const Color _gardenAccentDark = Color(0xFF4CAF50); // Mid Green


  // 1. FAB Theme
  static Map<String, dynamic> getFabTheme(String theme) {
    if (theme == themeGardenOfWords) {
      return {
        'bg': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFA5D6A7), _gardenAccentDark], // Light Green to Deep Green
          stops: [0.0, 1.0],
        ),
        'shadow': BoxShadow(
          color: _gardenAccentDark.withOpacity(0.5),
          blurRadius: 16,
          offset: const Offset(0, 8),
          spreadRadius: -2,
        ),
        'iconColor': Colors.white,
        'border': Border.all(color: Colors.white.withOpacity(0.6), width: 1.5), // Dew drop rim
      };
    } else if (theme == themeTwilight) {
      return {
        'bg': const RadialGradient(
          center: Alignment.topLeft,
          radius: 1.0,
          colors: [_twilightAccentRed, Color(0xFFFF8A80)], // Musubi Red (Main Accent)
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
          colors: [Color(0xFFE0F7FA), _afterRainAccentBlue], // Light cyan to deep blue
          stops: [0.1, 0.9],
        ),
        'shadow': BoxShadow(
          color: _afterRainAccentBlue.withOpacity(0.4),
          blurRadius: 16,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
        'iconColor': Colors.white,
        'border': Border.all(color: Colors.white.withOpacity(0.6), width: 1.5), // Shiny rim
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
               offset: const Offset(5, 0)
             )
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
              spreadRadius: 0),
        ],
        'pillBorder': Border.all(color: Colors.white.withOpacity(0.05)),
        'buttonGradient': LinearGradient(colors: [_gardenAccentDark, _gardenAccent]), // Inverted for depth
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
            right: BorderSide(color: _twilightBgBottom.withOpacity(0.3), width: 1), // Sunset edge reflection
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(5, 0),
            )
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
        'buttonGradient': const LinearGradient(colors: [_twilightAccentRed, _twilightBgBottom]), // 黄昏红 -> 落日橙
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
            right: BorderSide(color: Colors.white.withOpacity(0.4), width: 1), // Highlight edge
          ), 
          boxShadow: [
             BoxShadow(
               color: _afterRainAccentBlue.withOpacity(0.05), 
               blurRadius: 20, 
               offset: const Offset(2, 0)
             ) // Subtle glow
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
              blurRadius: 2), // Inner light
          BoxShadow(
              color: _afterRainAccentBlue.withOpacity(0.2), 
              offset: Offset(1, 1), 
              blurRadius: 3), // Drop shadow
        ],
        'pillBorder': Border.all(color: Colors.white.withOpacity(0.3)),
        'buttonGradient': const LinearGradient(colors: [_afterRainPrimaryLight, _afterRainPrimaryMain]),
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
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(5, 0))],
        ),
        'textColor': const Color(0xFF880E4F),
        'activeTextColor': const Color(0xFFD81B60),
        'subTextColor': const Color(0xFFBC477B),
        'pillColor': Colors.white,
        'pillShadows': [
          BoxShadow(color: const Color(0xFFF48FB1).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
        'pillBorder': null,
        'buttonGradient': const LinearGradient(colors: [Color(0xFFF06292), Color(0xFFD81B60)]),
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
          boxShadow: [BoxShadow(color: Colors.black87, blurRadius: 10, offset: Offset(5, 0))],
        ),
        'textColor': const Color(0xFFc9d1d9),
        'activeTextColor': const Color(0xFF7986cb),
        'subTextColor': const Color(0xFF8b949e),
        'pillColor': const Color(0xFF161b22),
        'pillShadows': [
          BoxShadow(color: Color.fromRGBO(121, 134, 203, 0.2), blurRadius: 8, spreadRadius: 1),
        ],
        'pillBorder': Border.all(color: Colors.white10),
        'buttonGradient': const LinearGradient(colors: [Color(0xFF7986cb), Color(0xFF3F51B5)]),
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
          image: DecorationImage(image: AssetImage('assets/textures/leather_dark.png'), fit: BoxFit.cover, opacity: 0.5),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(5, 0))],
        ),
        'textColor': const Color(0xFFBDBDBD),
        'activeTextColor': const Color(0xFFFF9800),
        'subTextColor': const Color(0xFF757575),
        'pillColor': const Color(0xFF222222),
        'pillShadows': [
          BoxShadow(color: Colors.white10, offset: Offset(0, 1), blurRadius: 0),
          BoxShadow(color: Colors.black87, offset: Offset(0, -2), blurRadius: 1),
        ],
        'pillBorder': null,
        'buttonGradient': const LinearGradient(colors: [Color(0xFFFFB74D), Color(0xFFF57C00)]),
      };
    } else {
      return {
        'bgDecoration': const BoxDecoration(
          color: Color(0xFF3E2723),
          image: DecorationImage(image: AssetImage('assets/textures/leather_dark.png'), fit: BoxFit.cover, opacity: 0.6),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(5, 0))],
        ),
        'textColor': const Color(0xFFD7CCC8),
        'activeTextColor': const Color(0xFFFF5252),
        'subTextColor': const Color(0xFFA1887F),
        'pillColor': const Color(0xFF2D1E1B),
        'pillShadows': [
          BoxShadow(color: Colors.white10, offset: Offset(0, 1), blurRadius: 0),
          BoxShadow(color: Colors.black87, offset: Offset(0, -2), blurRadius: 1),
        ],
        'pillBorder': null,
        'buttonGradient': const LinearGradient(colors: [Color(0xFFE57373), Color(0xFFD32F2F)]),
      };
    }
  }

  // 3. Settings Theme
  static Map<String, dynamic> getSettingsTheme(String theme) {
    if (theme == themeGardenOfWords) {
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
        'iconColor': _gardenAccent,
      };
    } else if (theme == themeTwilight) {
      return {
        'groupDecoration': BoxDecoration(
          color: _twilightSurface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _twilightBgBottom.withOpacity(0.1), width: 1), // Subtle orange rim
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
        'iconColor': _twilightAccentRed,
      };
    } else if (theme == themeAfterRain) {
      return {
        'groupDecoration': BoxDecoration(
          color: Colors.white.withOpacity(0.5), // Frosted glass
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
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
        'iconColor': _afterRainAccentBlue,
      };
    }
    // Default fallback logic will be handled in page if this returns null or map
    if (theme == themeDefault) {
      // Default (Vintage) Theme
      return {
        'groupDecoration': BoxDecoration(
          color: const Color(0xFF3E2723).withOpacity(0.3), // Darker brown background for group
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _vintagePaper.withOpacity(0.1)), // Light border
        ),
        'dividerColor': _vintagePaper.withOpacity(0.1),
        'textColor': _vintagePaper, // Use Light Paper color for text
        'activeSwitchColor': _vintageAccent,
        'activeTrackColor': _vintageAccent.withOpacity(0.3),
        'titleColor': _vintagePaper,
        'iconColor': _vintagePaper.withOpacity(0.8),
      };
    }
    return {};
  }

  // 4. Editor Theme
  static Map<String, dynamic> getEditorTheme(String theme) {
    if (theme == themeGardenOfWords) {
      return {
        'appBarBg': const Color(0xFF263238).withOpacity(0.9),
        'iconColor': _gardenTextSecondary,
        'cursorColor': _gardenAccent,
        'lineColor': Colors.white.withOpacity(0.05),
        'dividerColor': Colors.white.withOpacity(0.05),
      };
    } else if (theme == themeTwilight) {
      return {
        'appBarBg': _twilightSurface.withOpacity(0.8),
        'iconColor': _twilightAccentRed,
        'cursorColor': _twilightAccentRed,
        'lineColor': Colors.white.withOpacity(0.05), // Very subtle lines
        'dividerColor': Colors.white.withOpacity(0.1),
      };
    } else if (theme == themeAfterRain) {
      return {
        'appBarBg': _afterRainSurface.withOpacity(0.8),
        'iconColor': _afterRainTextSecondary,
        'cursorColor': _afterRainAccentBlue,
        'lineColor': _afterRainAccentBlue.withOpacity(0.1),
        'dividerColor': _afterRainAccentBlue.withOpacity(0.2),
      };
    }
    return {};
  }

  // 5. Diary Card Theme
  static Map<String, dynamic> getDiaryCardTheme(String theme) {
    if (theme == themeGardenOfWords) {
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
          )
        ],
        'hoverShadows': [
          BoxShadow(
            color: _gardenAccent.withOpacity(0.1),
            offset: const Offset(0, 8),
            blurRadius: 20,
          )
        ],
        'border': Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      };
    } else if (theme == themeTwilight) {
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
          )
        ],
        'hoverShadows': [
          BoxShadow(
            color: _twilightAccentRed.withOpacity(0.2), // Red glow
            offset: const Offset(0, 8),
            blurRadius: 20,
          )
        ],
        'border': Border.all(color: _twilightBgBottom.withOpacity(0.2), width: 1), // Subtle sunset border
      };
    } else if (theme == themeAfterRain) {
      return {
        'bgColor': Colors.white.withOpacity(0.7), // See-through card
        'titleColor': _afterRainTextSecondary,
        'contentColor': _afterRainTextSecondary.withOpacity(0.9),
        'dateColor': _afterRainAccentBlue,
        'iconColor': _afterRainAccentBlue,
        'dashedLineColor': _afterRainAccentBlue.withOpacity(0.2),
        'shadows': [
          BoxShadow(
            color: _afterRainAccentBlue.withOpacity(0.08), // Cyan diffused shadow
            offset: const Offset(0, 6),
            blurRadius: 15,
            spreadRadius: -2,
          )
        ],
        'hoverShadows': [
          BoxShadow(
            color: _afterRainAccentBlue.withOpacity(0.15),
            offset: const Offset(0, 10),
            blurRadius: 25,
            spreadRadius: -2,
          )
        ],
        'border': Border.all(color: Colors.white, width: 1.5),
      };
    }
    return {};
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
            offset: const Offset(0, 5)
          )
        ],
      };
    } else if (theme == themeTwilight) {
      return {
        'inkColor': _twilightTextPrimary,
        'paperColor': _twilightSurface.withOpacity(0.8),
        'paperBorderColor': Colors.white.withOpacity(0.1),
        'paperShadow': [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15)],
      };
    } else if (theme == themeAfterRain) {
      return {
        'inkColor': _afterRainTextSecondary,
        'paperColor': _afterRainSurface.withOpacity(0.95), // Slightly opaque paper
        'paperBorderColor': Colors.white.withOpacity(0.8),
        'paperShadow': [
          BoxShadow(
            color: _afterRainAccentBlue.withOpacity(0.1), 
            blurRadius: 12, 
            offset: const Offset(0, 5)
          )
        ],
      };
    }
    return {};
  }

  // 7. Moments Theme
  static Map<String, dynamic> getMomentsTheme(String theme) {
    if (theme == themeGardenOfWords) {
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
      };
    } else if (theme == themeTwilight) {
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
      };
    } else if (theme == themeAfterRain) {
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
      };
    }
    return {};
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
        'textColor': _twilightTextPrimary, // Softer white instead of stinging red
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
          )
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
        'tape': Colors.white.withOpacity(0.5), // Whitish translucent tape (like scotch tape)
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
        'success': {'bg': _gardenSurface, 'border': _gardenAccent, 'icon': _gardenAccent, 'text': _gardenTextSecondary},
        'error': {'bg': const Color(0xFFFFF0F0), 'border': const Color(0xFFE57373), 'icon': const Color(0xFFE57373), 'text': _gardenTextSecondary},
        'warning': {'bg': const Color(0xFFFFF8E1), 'border': const Color(0xFFFFB74D), 'icon': const Color(0xFFFFB74D), 'text': _gardenTextSecondary},
        'info': {'bg': _gardenSurface, 'border': _gardenAccentDark, 'icon': _gardenAccentDark, 'text': _gardenTextSecondary},
      };
    } else if (theme == themeTwilight) {
      return {
        'success': {'bg': _twilightSurface, 'border': _twilightAccentRed, 'icon': _twilightAccentRed, 'text': _twilightTextPrimary},
        'error': {'bg': _twilightSurface, 'border': _twilightAccentRed, 'icon': _twilightAccentRed, 'text': _twilightTextPrimary},
        'warning': {'bg': _twilightSurface, 'border': Color(0xFFFFB74D), 'icon': Color(0xFFFFB74D), 'text': _twilightTextPrimary},
        'info': {'bg': _twilightSurface, 'border': _twilightAccentRed, 'icon': _twilightAccentRed, 'text': _twilightTextPrimary},
      };
    } else if (theme == themeAfterRain) {
      return {
        'success': {'bg': _afterRainSurface, 'border': _afterRainPrimaryMain, 'icon': _afterRainPrimaryMain, 'text': _afterRainTextSecondary},
        'error': {'bg': Color(0xFFFFF0F0), 'border': Color(0xFFE57373), 'icon': Color(0xFFE57373), 'text': _afterRainTextSecondary},
        'warning': {'bg': Color(0xFFFFF8E1), 'border': Color(0xFFFFB74D), 'icon': Color(0xFFFFB74D), 'text': _afterRainTextSecondary},
        'info': {'bg': _afterRainSurface, 'border': _afterRainAccentBlue, 'icon': _afterRainAccentBlue, 'text': _afterRainTextSecondary},
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
        return SystemUiOverlayStyle.light.copyWith( // White icons for dark bg
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: _twilightBgTop,
          systemNavigationBarIconBrightness: Brightness.light,
        );
      case themeSeaFlower:
        return SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: const Color(0xFFF6D9E6), // Match gradient near bottom
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
              colors: [Color(0xFF37474F), Color(0xFF263238)], // Rainy Sky -> Wet Stone
              stops: [0.0, 1.0],
          ),
          image: DecorationImage(
             image: AssetImage('assets/textures/rainy_paper.png'), // Use existing rainy paper texture
             fit: BoxFit.cover,
             opacity: 0.1, // Subtle texture on top of dark gradient
          )
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
            colors: [Color(0xFFFEFDFF), Color(0xFFF6D9E6), Color(0xFFDBBAD0), Color(0xFFCDA8C7)],
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
            stops: [0.0, 1.0]
          ),
        );
      case themeAfterRain:
        return const BoxDecoration(
          color: _afterRainSurface,
          image: DecorationImage(
            image: AssetImage('assets/textures/rainy_paper.png'), 
            fit: BoxFit.cover, 
            opacity: 0.8 // Blend with surface color
          ),
        );
      case themeDefault:
      default:
        return const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.25, 
            colors: [_vintageBgCenter, _vintageBgEdge],
            stops: [0.0, 1.0]
          ),
        );
    }
  }

  static BoxDecoration getSidebarBackground(String theme) {
    switch (theme) {
      case themeGardenOfWords:
        return BoxDecoration(
          color: _gardenSurface.withOpacity(0.65),
          border: Border(right: BorderSide(color: Colors.white.withOpacity(0.4), width: 1)),
        );
      case themeTwilight:
         return BoxDecoration(
           color: _twilightSurface.withOpacity(0.5), // Semi-transparent sidebar
           border: Border(right: BorderSide(color: _twilightBgBottom.withOpacity(0.2), width: 1)),
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
           border: const Border(right: BorderSide(color: Color(0x4DFFFFFF), width: 1)),
         );
      case themeAmberLens:
        return BoxDecoration(
          color: const Color(0xFF1E1E1E).withOpacity(0.85),
          border: const Border(right: BorderSide(color: Color(0xFFFF9800), width: 1)), // Amber Border line
          boxShadow: const [
             BoxShadow(color: Colors.black, offset: Offset(2,0), blurRadius: 10)
          ]
        );
      case themeAfterRain:
        // Rain theme sidebar glass background
        return BoxDecoration(
          color: _afterRainSurface.withOpacity(0.65), // More transparent
          border: Border(right: BorderSide(color: Colors.white.withOpacity(0.4), width: 1)),
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
      case themeGardenOfWords: return _gardenSurface;
      case themeTwilight: return _twilightSurface;
      case themeMidnight: return _midnightPaper;
      case themeSeaFlower: return const Color(0xD9FFFFFF); // rgba(255, 255, 255, 0.85)
      case themeAmberLens: return _amberPaper;
      case themeAfterRain: return _afterRainSurface;
      default: return _vintagePaper;
    }
  }

  static Color getTextColor(String theme) {
    switch (theme) {
      case themeGardenOfWords: return _gardenTextSecondary;
      case themeTwilight: return _twilightTextPrimary;
      case themeMidnight: return _midnightTextPrimary;
      case themeSeaFlower: return const Color(0xFF880E4F);
      case themeAmberLens: return _amberTextPrimary;
      case themeAfterRain: return _afterRainTextSecondary; // User: "Main body text"
      default: return _vintageTextPrimary; // 恢复原来的深色文字
    }
  }
  
  static Color getTextSecondaryColor(String theme) {
    switch (theme) {
      case themeGardenOfWords: return _gardenAccentDark;
      case themeTwilight: return _twilightTextSecondary;
      case themeMidnight: return _midnightTextSecondary;
      case themeSeaFlower: return const Color(0xFFC2185B);
      case themeAmberLens: return _amberTextSecondary;
      case themeAfterRain: return _afterRainAccentBlue; // User: "Hint elements"
      default: return _vintageTextSecondary;
    }
  }

  static Color getAccentColor(String theme) {
    switch (theme) {
      case themeGardenOfWords: return _gardenAccent;
      case themeTwilight: return _twilightAccentRed;
      case themeMidnight: return _midnightAccent;
      case themeSeaFlower: return const Color(0xFFF50057);
      case themeAmberLens: return _amberAccent;
      case themeAfterRain: return _afterRainPrimaryMain; // User: "High frequency interaction"
      default: return _vintageAccent;
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
          'background': const Color(0xFFFFFFFF).withOpacity(0.15), // Light glass matches sidebar
          'border': const Color(0x4DFFFFFF), // White semi-transparent border (Matches sidebar)
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
    final bool isMidnight = theme == themeMidnight;
    final bool isTwilight = theme == themeTwilight;
    final bool isGarden = theme == themeGardenOfWords;
    final bool isDark = isMidnight || isTwilight || isGarden || theme == themeAmberLens;

    if (isTwilight) {
      return {
        'textColor': _twilightTextPrimary,
        'hintColor': _twilightTextSecondary.withOpacity(0.5),
        'borderColor': _twilightAccentRed.withOpacity(0.3),
        'focusedBorderColor': _twilightAccentRed,
        'iconColor': _twilightAccentRed.withOpacity(0.6),
        'backgroundColor': const Color(0xFF352044).withOpacity(0.6),
        'descriptionColor': _twilightTextSecondary,
      };
    } else if (isGarden) {
      return {
        'textColor': _gardenTextPrimary,
        'hintColor': _gardenTextSecondary.withOpacity(0.5),
        'borderColor': _gardenAccent.withOpacity(0.3),
        'focusedBorderColor': _gardenAccent,
        'iconColor': _gardenAccent.withOpacity(0.6),
        'backgroundColor': Colors.black.withOpacity(0.2),
        'descriptionColor': _gardenTextPrimary.withOpacity(0.7),
      };
    } else if (isMidnight) {
      return {
        'textColor': Colors.white70,
        'hintColor': Colors.white30,
        'borderColor': Colors.white24,
        'focusedBorderColor': Colors.white54,
        'iconColor': Colors.white38,
        'backgroundColor': Colors.black.withOpacity(0.3),
        'descriptionColor': Colors.white54,
      };
    } else if (theme == themeAmberLens) {
        return {
          'textColor': _amberTextPrimary,
          'hintColor': _amberTextSecondary.withOpacity(0.5),
          'borderColor': _amberAccent.withOpacity(0.4),
          'focusedBorderColor': _amberAccent,
          'iconColor': _amberAccent.withOpacity(0.6),
          'backgroundColor': Colors.black.withOpacity(0.3),
          'descriptionColor': _amberTextSecondary,
        };
    } else {
      // Default / Light Themes
      final Color ink = (theme == themeSeaFlower) ? const Color(0xFF880E4F) : const Color(0xFF5D4037);
      return {
        'textColor': ink,
        'hintColor': ink.withOpacity(0.4),
        'borderColor': ink.withOpacity(0.2),
        'focusedBorderColor': ink.withOpacity(0.6),
        'iconColor': ink.withOpacity(0.4),
        'backgroundColor': (theme == themeSeaFlower) ? const Color(0xFFFCE4EC).withOpacity(0.5) : Colors.white.withOpacity(0.5),
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
      scaffoldBg = _twilightBgTop; // Base for scaffold, usually covered by container gradient
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
      brightness = Brightness.dark; // Vintage is Dark mode by default for contrast
    }

    // 2. Build ThemeData
    return ThemeData(
      useMaterial3: true,
      brightness: brightness, 
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness, // Ensures correct onSurface colors (White text on Dark bg)
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
         brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme
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
        'cardBorder': Border.all(color: Colors.white.withOpacity(0.1), width: 1),
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
          border: Border.all(color: _twilightBgBottom.withOpacity(0.2), width: 1),
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
        'cardBorder': Border.all(color: Colors.white.withOpacity(0.1), width: 1),
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
        'cardBorder': Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
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
        'cardBorder': Border.all(color: Colors.white.withOpacity(0.6), width: 1),
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
        'cardBorder': Border.all(color: Colors.white.withOpacity(0.1), width: 1),
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
          border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.3), width: 1),
        ),
        'cardShadow': BoxShadow(
          color: const Color(0xFFFF9800).withOpacity(0.2),
          blurRadius: 15,
          offset: const Offset(0, 6),
          spreadRadius: -2,
        ),
        'cardBorder': Border.all(color: const Color(0xFFFF9800).withOpacity(0.3), width: 1),
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
          border: Border.all(color: const Color(0xFF5D4037).withOpacity(0.2), width: 1),
        ),
        'cardShadow': BoxShadow(
          color: const Color(0xFF3E2723).withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, 4),
          spreadRadius: -2,
        ),
        'cardBorder': Border.all(color: const Color(0xFF5D4037).withOpacity(0.2), width: 1),
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
              BoxShadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 2)),
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
              BoxShadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2)),
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
            border: Border.all(color: _twilightAccentRed.withOpacity(0.3), width: 1),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
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
            border: Border.all(color: const Color(0xFF8BC34A).withOpacity(0.3), width: 1),
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
          'primaryGradient': const LinearGradient(colors: [Color(0xFFF06292), Color(0xFFAD1457)]),
          'primaryShadowColor': const Color(0xFFAD1457).withOpacity(0.3),
          'secondaryBtnColor': Colors.white.withOpacity(0.5),
          'secondaryBtnTextColor': const Color(0xFF880E4F),
          'secondaryBorderColor': const Color(0xFFAD1457).withOpacity(0.2),
          'tipsBgColor': Colors.white.withOpacity(0.2),
          'switchBgColor': Colors.white.withOpacity(0.4),
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
          'primaryGradient': const LinearGradient(colors: [Color(0xFF7986cb), Color(0xFF283593)]),
          'primaryShadowColor': const Color(0xFF283593).withOpacity(0.4),
          'secondaryBtnColor': const Color(0xFF21262d),
          'secondaryBtnTextColor': const Color(0xFFc9d1d9),
          'secondaryBorderColor': Colors.white.withOpacity(0.1),
          'tipsBgColor': const Color(0xFF161b22).withOpacity(0.8),
          'switchBgColor': const Color(0xFF0D1117).withOpacity(0.5),
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
          'primaryGradient': const LinearGradient(colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)]),
          'primaryShadowColor': _afterRainAccentBlue.withOpacity(0.3),
          'secondaryBtnColor': Colors.white.withOpacity(0.6),
          'secondaryBtnTextColor': const Color(0xFF0277BD),
          'secondaryBorderColor': _afterRainAccentBlue.withOpacity(0.2),
          'tipsBgColor': Colors.white.withOpacity(0.2),
          'switchBgColor': Colors.black.withOpacity(0.05),
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
          'primaryGradient': const LinearGradient(colors: [Color(0xFFEF5350), Color(0xFFC62828)]),
          'primaryShadowColor': _twilightAccentRed.withOpacity(0.3),
          'secondaryBtnColor': _twilightSurface.withOpacity(0.6),
          'secondaryBtnTextColor': _twilightAccentRed,
          'secondaryBorderColor': _twilightAccentRed.withOpacity(0.2),
          'tipsBgColor': _twilightSurface.withOpacity(0.8),
          'switchBgColor': _twilightSurface.withOpacity(0.6),
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
          'primaryGradient': const LinearGradient(colors: [Color(0xFF8BC34A), Color(0xFF558B2F)]),
          'primaryShadowColor': const Color(0xFF8BC34A).withOpacity(0.3),
          'secondaryBtnColor': Colors.white.withOpacity(0.6),
          'secondaryBtnTextColor': const Color(0xFF2E4A35),
          'secondaryBorderColor': const Color(0xFF8BC34A).withOpacity(0.2),
          'tipsBgColor': Colors.white.withOpacity(0.2),
          'switchBgColor': Colors.black.withOpacity(0.05),
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
        };
    }
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
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart, // Heavy, physical feel
      )),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut, // Linear fade is usually best, but easeOut is softer
        ),
        child: child,
      ),
    );
  }
}
