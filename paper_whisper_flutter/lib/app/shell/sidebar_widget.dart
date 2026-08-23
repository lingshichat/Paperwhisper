import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:paper_whisper_flutter/app/navigation/app_routes.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/diary/application/diary_provider.dart';
import 'package:paper_whisper_flutter/features/settings/application/settings_provider.dart';
import 'package:paper_whisper_flutter/app/shell/data/hitokoto_service.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_search_bar.dart';

enum SidebarSection { writer, moments, statistics, none }

class SidebarWidget extends StatefulWidget {
  final SidebarSection activeSection;

  const SidebarWidget({super.key, this.activeSection = SidebarSection.none});

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget> {
  final HitokotoService _hitokotoService = HitokotoService();
  late final Future<HitokotoLine?> _hitokotoFuture;

  @override
  void initState() {
    super.initState();
    _hitokotoFuture = _hitokotoService.fetchHitokoto();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWriter = widget.activeSection == SidebarSection.writer;
    final bool isMoments = widget.activeSection == SidebarSection.moments;
    final bool isStatistics = widget.activeSection == SidebarSection.statistics;
    final bool isInDrawer =
        context.findAncestorWidgetOfExactType<Drawer>() != null;
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    int activeIndex = -1;
    if (isWriter) activeIndex = 0;
    if (isMoments) activeIndex = 1;
    if (isStatistics) activeIndex = 2;

    final theme = context.select<SettingsProvider, String>(
      (provider) => provider.currentTheme,
    );

    // Theme Configs
    final config = ThemeRegistry.get(theme).sidebar;
    BoxDecoration bgDecor = config.bgDecoration;
    Color textColor = config.textColor;
    Color activeTextColor = config.activeTextColor;
    Color subTextColor = config.subTextColor;
    Color hitokotoBackgroundColor = config.hitokotoBackgroundColor;
    Color hitokotoBorderColor = config.hitokotoBorderColor;
    Color dividerColor = config.dividerColor;
    Color pillColor = config.pillColor;
    List<BoxShadow> pillShadows = config.pillShadows;
    BoxBorder? pillBorder = config.pillBorder;

    final bool prefersBlur =
        theme == AppTheme.themeSeaFlower ||
        theme == AppTheme.themeAfterRain ||
        theme == AppTheme.themeTwilight ||
        theme == AppTheme.themeGardenOfWords;

    Widget sidebarContent = RepaintBoundary(
      child: Container(
        width: 280,
        decoration: bgDecor,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "纸语",
                      style: GoogleFonts.notoSerifSc(
                        color: textColor, // Adapted
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "PaperWhisper",
                      style: GoogleFonts.playfairDisplay(
                        color: subTextColor, // Adapted
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              // Search Bar (Desktop Only - 通过屏幕宽度检测)
              // 使用 MediaQuery 检测是否是桌面端，比 Drawer ancestor 更可靠
              if (isDesktop)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Builder(
                    builder: (context) {
                      final searchValue = isMoments
                          ? context.select<DiaryProvider, String>(
                              (provider) => provider.momentsSearchQuery,
                            )
                          : context.select<DiaryProvider, String>(
                              (provider) => provider.diarySearchQuery,
                            );
                      final diaryProvider = context.read<DiaryProvider>();

                      return SkeuomorphicSearchBar(
                        value: searchValue,
                        onChanged: (val) {
                          if (isMoments) {
                            diaryProvider.setMomentsSearchQuery(val);
                          } else {
                            diaryProvider.setDiarySearchQuery(val);
                          }
                        },
                      );
                    },
                  ),
                ),

              // Write Button (Only for Desktop/Non-Drawer)
              if (!isInDrawer)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          AppRoutes.editor(
                            transition: AppRouteTransition.letterFold,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          // Solid-like look but with gradient to simulate lighting (Bevel)
                          gradient: config.buttonGradient,

                          // Rounded Corners (Restore)
                          borderRadius: BorderRadius.circular(10),

                          boxShadow: [
                            config.buttonShadow ??
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  offset: const Offset(0, 3), // Bottom shadow
                                  blurRadius: 6,
                                ),
                          ],
                          // Uniform Border to prevent Crash
                          // We use a subtle white stroke to sharpen edges
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "写一篇",
                              style: GoogleFonts.notoSerifSc(
                                color: Colors.white,
                                fontSize: 16, // Slightly larger
                                fontWeight: FontWeight.bold,
                                letterSpacing:
                                    2, // Wider spacing like reference
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Menu Area with Animated Pill
              Stack(
                children: [
                  // Selection Pill (Hero)
                  if (activeIndex != -1)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      top: activeIndex * 68.0,
                      left: 16,
                      right: 16,
                      height: 56,
                      child: Hero(
                        tag: 'sidebar_selection_pill',
                        child: Container(
                          decoration: BoxDecoration(
                            color: pillColor, // Adapted
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: pillShadows, // Adapted
                            border: pillBorder, // Adapted
                          ),
                        ),
                      ),
                    ),

                  // Menu Items
                  Column(
                    children: [
                      _buildMenuItem(
                        context,
                        icon: Icons.edit_note,
                        label: "专注书写",
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          if (isInDrawer) {
                            navigator.pop();
                            // 等待侧边栏关闭动画，避免路由冲突导致卡死
                            await Future.delayed(
                              const Duration(milliseconds: 300),
                            );
                          }

                          if (!isWriter) {
                            navigator.pushReplacement(AppRoutes.diaryList());
                          }
                        },
                        isActive: isWriter,
                        // Pass colors down
                        textColor: textColor,
                        activeColor: activeTextColor,
                      ),

                      const SizedBox(height: 12),

                      _buildMenuItem(
                        context,
                        icon: Icons.photo_library_outlined,
                        label: "随心记",
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          if (isInDrawer) {
                            navigator.pop();
                            await Future.delayed(
                              const Duration(milliseconds: 300),
                            );
                          }

                          if (!isMoments) {
                            navigator.pushReplacement(AppRoutes.moments());
                          }
                        },
                        isActive: isMoments,
                        textColor: textColor,
                        activeColor: activeTextColor,
                      ),

                      const SizedBox(height: 12),

                      _buildMenuItem(
                        context,
                        icon: Icons.bar_chart_outlined,
                        label: "数据洞察",
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          if (isInDrawer) {
                            navigator.pop();
                            await Future.delayed(
                              const Duration(milliseconds: 300),
                            );
                          }

                          if (!isStatistics) {
                            navigator.push(AppRoutes.statistics());
                          }
                        },
                        isActive: isStatistics,
                        textColor: textColor,
                        activeColor: activeTextColor,
                      ),
                    ],
                  ),
                ],
              ),

              const Spacer(),

              // Hitokoto
              FutureBuilder<HitokotoLine?>(
                future: _hitokotoFuture,
                builder: (context, snapshot) {
                  final hitokoto = snapshot.data;
                  return Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: hitokotoBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: hitokotoBorderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hitokoto?.hitokoto ?? '正在获取一言...',
                          style: GoogleFonts.notoSerifSc(
                            color: subTextColor,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                        ),
                        if (hitokoto != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '—— ${hitokoto.from}',
                              style: GoogleFonts.notoSerifSc(
                                color: subTextColor.withValues(alpha: 0.8),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              Divider(color: dividerColor, height: 1),

              // Settings
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: _buildMenuItem(
                  context,
                  icon: Icons.settings_outlined,
                  label: "设置",
                  onTap: () {
                    if (isInDrawer) {
                      Navigator.pop(context);
                    }
                    Navigator.push(context, AppRoutes.settings());
                  },
                  isActive: false,
                  textColor: textColor,
                  activeColor: activeTextColor,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );

    if (prefersBlur && !isInDrawer) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 20,
            sigmaY: 20,
          ), // Increased blur for rain effect
          child: sidebarContent,
        ),
      );
    }

    return sidebarContent;
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    required Color textColor,
    required Color activeColor,
  }) {
    // Inner height: 16*2 + 24 = 56
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              // Background is handled by Stack Pill
              // But we can add transparent debug color if needed
            ),
            child: Hero(
              tag: 'sidebar_item_$label', // Unique tag per item
              child: Material(
                type: MaterialType.transparency,
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: isActive
                          ? activeColor
                          : textColor.withValues(alpha: 0.7),
                      size: 24,
                    ),
                    const SizedBox(width: 20),
                    Text(
                      label,
                      style: GoogleFonts.notoSerifSc(
                        color: isActive ? activeColor : textColor,
                        fontSize: 16,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.normal,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
