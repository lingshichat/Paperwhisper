import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/settings_provider.dart';
import '../config/app_theme.dart';


class SkeuomorphicBook extends StatelessWidget {
  final int year;
  final String title;
  final String subtitle;
  final String? coverImagePath;
  final VoidCallback onTap;
  final Function(String) onMenuAction;

  const SkeuomorphicBook({
    super.key,
    required this.year,
    required this.title,
    this.subtitle = '',
    this.coverImagePath,
    required this.onTap,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    // Theme Adaptation
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currentTheme = settings.currentTheme;
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    
    // Create a bottom color that matches the theme
    Color bottomColor;
    if (currentTheme == AppTheme.themeSeaFlower) {
      // 海底花海：使用柔和的粉紫色，与背景渐变协调
      bottomColor = const Color(0xFFD4A5C3); // 柔和粉紫色，介于背景渐变的中间色调
    } else {
      // 其他主题：使用深色变体
      bottomColor = HSLColor.fromColor(primaryColor).withLightness(0.15).toColor();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3), // Deeper shadow for floating effect
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Area (Cover Image / Leather Texture)
              Expanded(
                flex: 3,
                child: _buildCoverArea(context, currentTheme, primaryColor),
              ),

              
              // 2. Bottom Area (Title Info)
              Expanded(
                flex: 1, // Reduced flex might cause overflow if content is large, checking layout
                child: Container(
                  color: bottomColor, 
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Main Title (Year or Custom)
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSerifSc(
                              color: Colors.white,
                              fontSize: 24, // Larger font
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Separator
                          Container(
                            width: 24,
                            height: 2,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 8),
                          // Subtitle
                          Flexible( // Use Flexible to prevent overflow
                            child: Text(
                              subtitle.isNotEmpty ? subtitle : '$year年',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.notoSerifSc(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建封面区域
  Widget _buildCoverArea(BuildContext context, String theme, Color primaryColor) {
    // 创建封面内容
    return Container(
      color: _getCoverBackgroundColor(theme, primaryColor),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover Image or Texture
          if (coverImagePath != null && File(coverImagePath!).existsSync())
            Image.file(
              File(coverImagePath!),
              fit: BoxFit.cover,
              cacheWidth: 450, // Optimize for grid view
              errorBuilder: (ctx, err, stack) => _buildDefaultCover(context),
            )
          else
            _buildDefaultCover(context),
            
          // Menu Button (Three Dots) - Top Right
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_horiz, color: Colors.white, size: 20),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                color: Colors.white,
                onSelected: onMenuAction,
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'edit_cover',
                    child: Row(
                      children: [
                        Icon(Icons.image, color: primaryColor, size: 20),
                        const SizedBox(width: 12),
                        Text('自定义封面', style: TextStyle(color: Colors.black87)),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'edit_title',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: primaryColor, size: 20),
                        const SizedBox(width: 12),
                        Text('自定义标题', style: TextStyle(color: Colors.black87)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'reset_cover',
                    child: Row(
                      children: [
                        const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 20),
                        const SizedBox(width: 12),
                        const Text('恢复默认封面', style: TextStyle(color: Colors.black87)),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'reset_title',
                    child: Row(
                      children: [
                        const Icon(Icons.title, color: Colors.grey, size: 20),
                        const SizedBox(width: 12),
                        const Text('恢复默认标题', style: TextStyle(color: Colors.black87)),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'reset_subtitle',
                    child: Row(
                      children: [
                        const Icon(Icons.subtitles, color: Colors.grey, size: 20),
                        const SizedBox(width: 12),
                        const Text('恢复默认副标题', style: TextStyle(color: Colors.black87)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取封面背景颜色
  Color _getCoverBackgroundColor(String theme, Color primaryColor) {
    if (theme == AppTheme.themeSeaFlower) {
      // 海底花海：亮白色，微透磨砂质感
      return const Color(0xFFFFFFFF).withOpacity(0.85);
    } else if (theme == AppTheme.themeMidnight) {
      // 午夜星尘：深色半透明
      return const Color(0xFF0D1117).withOpacity(0.9);
    } else if (theme == AppTheme.themeAmberLens) {
      // 琥珀镜头：深灰
      return const Color(0xFF1E1E1E).withOpacity(0.9);
    } else if (theme == AppTheme.themeAfterRain) {
      // 雨后天空：浅白半透明
      return const Color(0xFFFFFDFD).withOpacity(0.85);
    } else {
      // 默认主题：棕色半透明
      return const Color(0xFF3e2723).withOpacity(0.85);
    }
  }

  Widget _buildDefaultCover(BuildContext context) {
    // Access settings to determine current theme string
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;

    String assetPath;
    switch (theme) {
      case AppTheme.themeMidnight:
        assetPath = 'assets/illustrations/illustration_midnight.svg';
        break;
      case AppTheme.themeSeaFlower:
        assetPath = 'assets/illustrations/illustration_seaflower.svg';
        break;
      case AppTheme.themeAmberLens:
        assetPath = 'assets/illustrations/illustration_amber.svg';
        break;
      case AppTheme.themeAfterRain:
        assetPath = 'assets/illustrations/illustration_seaflower.svg'; // Temporarily reuse seaflower as placeholder
        break;
      default:
        assetPath = 'assets/illustrations/illustration_vintage.svg';
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(24.0), // 四周留白
      child: SvgPicture.asset(
        assetPath,
        fit: BoxFit.contain, // 居中显示，保持比例
        placeholderBuilder: (ctx) => Container(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.8),
          child: const Center(
             child: CircularProgressIndicator(color: Colors.white12),
          ),
        ),
      ),
    );
  }
}
