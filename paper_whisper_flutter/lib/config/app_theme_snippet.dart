  // 13. Moment Editor Theme
  static Map<String, dynamic> getMomentEditorTheme(String theme) {
    if (theme == themeGardenOfWords) {
      return {
        'bgColor': _gardenSurface.withOpacity(0.95), // Mist White
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
        'bgColor': _twilightSurface, // Deep Purple
        'appBarTextColor': _twilightTextPrimary,
        'appBarIconColor': _twilightTextPrimary,
        'inputBg': Colors.black.withOpacity(0.2), // Dark input
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
        'bgColor': _afterRainSurface, // Alice Blue
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
        'hintColor': const Color(0xFF3E2723).withOpacity(0.5), // Approximate
        'dropdownBg': Colors.white.withOpacity(0.5),
        'dropdownIconColor': const Color(0xFF8D6E63),
        'dropdownMenuBg': const Color(0xFFF4ECD8),
        'dropdownItemColor': const Color(0xFF5D4037), // Standard
         'photoEmptyColor': Colors.white.withOpacity(0.3),
        'photoIconColor': const Color(0xFF8D6E63),
     };
  }
