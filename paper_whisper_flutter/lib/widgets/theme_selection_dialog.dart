import 'package:flutter/material.dart'; // Added
import 'package:google_fonts/google_fonts.dart'; // Added
import 'dart:ui'; // Added
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../config/app_theme.dart';
import 'skeuomorphic_container.dart'; // Added


class ThemeSelectionDialog extends StatelessWidget {
  const ThemeSelectionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final currentTheme = settings.currentTheme;
    final dialogTheme = AppTheme.getDialogTheme(currentTheme);
    
    // Fallback constants
    final bg = dialogTheme['paper'] ?? const Color(0xFFF7F1E3);
    final closeColor = dialogTheme['icon'] ?? const Color(0xFF8D6E63);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Center(
        child: SkeuomorphicContainer(
          width: 600,
          padding: const EdgeInsets.all(40),
          borderRadius: BorderRadius.circular(12),
          color: bg,
          shadows: [
             dialogTheme['shadow'] is Color 
                 ? BoxShadow(color: dialogTheme['shadow'], blurRadius: 30, offset: const Offset(0, 10))
                 : const BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.5),
                      offset: Offset(0, 20),
                      blurRadius: 60,
                   ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Stack(
                alignment: Alignment.center,
                children: [
                   Align(
                    alignment: Alignment.centerRight,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Text(
                          '×',
                          style: TextStyle(fontSize: 24, color: closeColor),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '风格画廊',
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: dialogTheme['title'] ?? const Color(0xFF5D4037),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Grid
              SizedBox(
                height: 300, 
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 1.2, 
                  children: [
                    _buildThemeCard(
                      context,
                      settings,
                      AppTheme.themeDefault, // Actually 'default' key
                      '复古纸张',
                      '深色圆木，温润如玉',
                      const RadialGradient(
                        colors: [Color(0xFF4A3B32), Color(0xFF2D241F)],
                        center: Alignment.center,
                      ),
                      currentTheme == AppTheme.themeDefault,
                    ),
                    _buildThemeCard(
                      context,
                      settings,
                      AppTheme.themeAmberLens, // Correct key: 'amber_lens'
                      '琥珀光圈',
                      '深邃皮革，暖橙微光',
                      const SolidColor(Color(0xFF2C2C2C)), // Dark grey leather base
                      currentTheme == AppTheme.themeAmberLens,
                    ),
                    _buildThemeCard(
                      context,
                      settings,
                      AppTheme.themeSeaFlower,
                      '海底花海',
                      '深邃梦境，繁花相拥',
                      const LinearGradient(
                         colors: [Color(0xFFF6D9E6), Color(0xFFDBBAD0)],
                         begin: Alignment.topLeft,
                         end: Alignment.bottomRight,
                      ),
                      currentTheme == AppTheme.themeSeaFlower,
                    ),
                    _buildThemeCard(
                      context,
                      settings,
                      AppTheme.themeMidnight,
                      '午夜星尘',
                      '静谧深夜，独处时光',
                      const SolidColor(Color(0xFF161B22)),
                      currentTheme == AppTheme.themeMidnight,
                    ),
                    _buildThemeCard(
                      context,
                      settings,
                      AppTheme.themeAfterRain,
                      '雨后天空',
                      '极简呼吸，宁静希望',
                      const LinearGradient(
                        colors: [Color(0xFF4FC3F7), Color(0xFFB3E5FC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      currentTheme == AppTheme.themeAfterRain,
                    ),
                    _buildThemeCard(
                      context,
                      settings,
                      AppTheme.themeTwilight,
                      '黄昏之时',
                      '逢魔时刻，梦幻交织',
                      const LinearGradient(
                        colors: [Color(0xFF352044), Color(0xFF7B1FA2), Color(0xFFFF6F00)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomRight,
                      ),
                      currentTheme == AppTheme.themeTwilight,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeCard(
      BuildContext context,
      SettingsProvider settings,
      String id, 
      String name, 
      String desc, 
      dynamic background,
      bool isActive) {
      
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          settings.setTheme(id);
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color.fromRGBO(0, 0, 0, 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isActive ? const Color(0xFFC0392B) : Colors.transparent, 
                width: 2
            ), 
            boxShadow: isActive ? [
                BoxShadow(
                    color: const Color(0xFFC0392B).withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1
                )
            ] : [],
          ),
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                     color: background is SolidColor ? background.color : null,
                     gradient: background is! SolidColor ? background as Gradient? : null,
                     borderRadius: BorderRadius.circular(4),
                     boxShadow: const [
                       BoxShadow(
                         color: Color.fromRGBO(0, 0, 0, 0.2),
                         blurRadius: 10,
                       )
                     ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                style: GoogleFonts.notoSerifSc(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isActive ? const Color(0xFFC0392B) : const Color(0xFF5D4037),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                desc,
                style: GoogleFonts.notoSerifSc(
                  fontSize: 12,
                  color: const Color(0xFF8D6E63),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SolidColor {
  final Color color;
  const SolidColor(this.color);
}
