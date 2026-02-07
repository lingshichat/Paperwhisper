import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const String themeDefault = 'default'; // Vintage (时光旧物)
  static const String themeAmberLens = 'amber_lens';
  static const String themeAfterRain = 'after_rain';
  static const String themeTwilight = 'twilight'; // Twilight (黄昏之时)

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


  // 1. FAB Theme
  static Map<String, dynamic> getFabTheme(String theme) {
    if (theme == themeTwilight) {
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
    if (theme == themeTwilight) {
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
            color: _twilightAccentCyan.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 0), // Glow
          ),
        ],
        'pillBorder': Border.all(color: Colors.white.withOpacity(0.1)),
        'buttonGradient': const LinearGradient(colors: [_twilightAccentCyan, Color(0xFF00ACC1)]),
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
    if (theme == themeTwilight) {
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
    if (theme == themeTwilight) {
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
    if (theme == themeTwilight) {
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
            color: _twilightAccentCyan.withOpacity(0.2), // Blue glow
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
    if (theme == themeTwilight) {
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
    if (theme == themeTwilight) {
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
    if (theme == themeTwilight) {
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
    if (theme == themeTwilight) {
      return {
        'textColor': _twilightTextSecondary,
        'lineColor': Colors.white.withOpacity(0.1),
        'paperColor': _twilightSurface.withOpacity(0.8),
        'shadows': [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5)],
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
    }
    return {};
  }

  // 10. Dialog Theme
  static Map<String, dynamic> getDialogTheme(String theme) {
    if (theme == themeTwilight) {
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
    if (theme == themeTwilight) {
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
  static Map<String, dynamic> getLockScreenTheme(String theme) {
    if (theme == themeTwilight) {
      return {
        'textColor': _twilightTextPrimary,
        'accentColor': _twilightAccentRed,
        'displayBg': Colors.black.withOpacity(0.2),
        'displayBorder': Colors.white.withOpacity(0.1),
        'keyBg': _twilightSurface.withOpacity(0.5),
        'keyBorder': Colors.white.withOpacity(0.1),
        'keyText': _twilightAccentRed,
      };
    } else if (theme == themeAfterRain) {
      return {
        'textColor': _afterRainTextSecondary,
        'accentColor': _afterRainAccentBlue,
        'displayBg': Colors.white.withOpacity(0.3),
        'displayBorder': Colors.white.withOpacity(0.5),
        'keyBg': Colors.white.withOpacity(0.2), // Water drop keys
        'keyBorder': Colors.white.withOpacity(0.4),
        'keyText': _afterRainAccentBlue,
      };
    }
    return {};
  }

  static SystemUiOverlayStyle getSystemUiOverlayStyle(String theme) {
    switch (theme) {
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
      case themeTwilight:
        return const BoxDecoration(
          color: _twilightBgTop,
          image: DecorationImage(
            image: AssetImage('assets/textures/twilight_bg.png'),
            fit: BoxFit.cover,
            opacity: 1.0, 
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
      case themeTwilight: return _twilightTextPrimary;
      case themeMidnight: return _midnightTextPrimary;
      case themeSeaFlower: return const Color(0xFF880E4F);
      case themeAmberLens: return _amberTextPrimary;
      case themeAfterRain: return _afterRainTextSecondary; // User: "Main body text"
      default: return _vintageTextPrimary;
    }
  }
  
  static Color getTextSecondaryColor(String theme) {
    switch (theme) {
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

  // --- 3. Dynamic Theme Data (Fixes Flash of White & Adds Transitions) ---

  static ThemeData getThemeData(String theme) {
    // 1. Determine Background Color & Brightness
    Color scaffoldBg;
    Color seedColor;
    Brightness brightness;
    Color accentColor = getAccentColor(theme);

    if (theme == themeTwilight) {
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
