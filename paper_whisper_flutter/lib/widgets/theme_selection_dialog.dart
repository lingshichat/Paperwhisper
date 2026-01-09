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

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Center(
        child: SkeuomorphicContainer(
          width: 600,
          padding: const EdgeInsets.all(40),
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFF7F1E3), // Paper color
          shadows: const [
            BoxShadow(
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
                        child: const Text(
                          '×',
                          style: TextStyle(fontSize: 24, color: Color(0xFF8D6E63)),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '风格画廊',
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF5D4037),
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
                      '经典木纹',
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
                      'vintage', // Assuming vintage key maps to something or just alias
                      '时光旧物',
                      '泛黄羊皮，怀旧岁月',
                      const SolidColor(Color(0xFF3E2723)),
                      currentTheme == 'vintage',
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
