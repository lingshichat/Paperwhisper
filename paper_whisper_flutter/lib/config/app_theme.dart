import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const String themeDefault = 'default'; // Vintage (时光旧物)
  static const String themeAmberLens = 'amber_lens';

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

  // --- 2. Getters ---

  static SystemUiOverlayStyle getSystemUiOverlayStyle(String theme) {
    switch (theme) {
      case themeSeaFlower:
        return SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: const Color(0xFFF6D9E6), // Match gradient near bottom
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
      case themeMidnight: return _midnightPaper;
      case themeSeaFlower: return const Color(0xD9FFFFFF); // rgba(255, 255, 255, 0.85)
      case themeAmberLens: return _amberPaper;
      default: return _vintagePaper;
    }
  }

  static Color getTextColor(String theme) {
    switch (theme) {
      case themeMidnight: return _midnightTextPrimary;
      case themeSeaFlower: return const Color(0xFF880E4F);
      case themeAmberLens: return _amberTextPrimary;
      default: return _vintageTextPrimary;
    }
  }
  
  static Color getTextSecondaryColor(String theme) {
    switch (theme) {
      case themeMidnight: return _midnightTextSecondary;
      case themeSeaFlower: return const Color(0xFFC2185B);
      case themeAmberLens: return _amberTextSecondary;
      default: return _vintageTextSecondary;
    }
  }

  static Color getAccentColor(String theme) {
    switch (theme) {
      case themeMidnight: return _midnightAccent;
      case themeSeaFlower: return const Color(0xFFF50057);
      case themeAmberLens: return _amberAccent;
      default: return _vintageAccent;
    }
  }

  // 移动端顶栏颜色配置
  static Map<String, Color> getMobileHeaderColors(String theme) {
    switch (theme) {
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

    if (theme == themeSeaFlower) {
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
