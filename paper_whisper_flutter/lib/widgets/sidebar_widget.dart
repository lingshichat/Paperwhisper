import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/hitokoto_service.dart';
import '../config/app_theme.dart';
import '../pages/diary_list_page.dart';
import '../pages/moments_page.dart';
import '../pages/settings_page.dart';
import '../pages/statistics_page.dart';
import '../widgets/slide_page_route.dart';
import '../providers/settings_provider.dart';
import '../pages/editor_page.dart';
import '../widgets/paper_fold_page_route.dart';
import '../widgets/skeuomorphic_search_bar.dart';
import '../providers/diary_provider.dart';

class SidebarWidget extends StatefulWidget {
  const SidebarWidget({super.key});

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget> {
  HitokotoLine? _hitokoto;
  final HitokotoService _hitokotoService = HitokotoService();

  @override
  void initState() {
    super.initState();
    _fetchHitokoto();
  }

  Future<void> _fetchHitokoto() async {
    final hitokoto = await _hitokotoService.fetchHitokoto();
    if (mounted) {
      setState(() {
        _hitokoto = hitokoto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isWriter = context.findAncestorWidgetOfExactType<DiaryListPage>() != null;
    bool isMoments = context.findAncestorWidgetOfExactType<MomentsPage>() != null;
    bool isStatistics = context.findAncestorWidgetOfExactType<StatisticsPage>() != null;
    
    int activeIndex = -1;
    if (isWriter) activeIndex = 0;
    if (isMoments) activeIndex = 1;
    if (isStatistics) activeIndex = 2;

    final theme = Provider.of<SettingsProvider>(context).currentTheme;
    
    // Theme Configs
    final config = AppTheme.getSidebarTheme(theme);
    BoxDecoration bgDecor = config['bgDecoration'];
    Color textColor = config['textColor'];
    Color activeTextColor = config['activeTextColor'];
    Color subTextColor = config['subTextColor'];
    Color pillColor = config['pillColor'];
    List<BoxShadow> pillShadows = config['pillShadows'];
    BoxBorder? pillBorder = config['pillBorder'];

    Widget sidebarContent = Container(
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
                           Shadow(color: Colors.black.withOpacity(0.3), offset: const Offset(0, 2), blurRadius: 4)
                         ]
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
               Builder(
                 builder: (context) {
                   // 桌面端判断：屏幕宽度 > 800
                   final isDesktop = MediaQuery.of(context).size.width > 800;
                   if (!isDesktop) return const SizedBox.shrink();
                   
                   try {
                     // 使用 watch 以响应外部清空搜索的操作
                     final diaryProvider = context.watch<DiaryProvider>();
                     // Determine context
                     final bool isMomentsContext = context.findAncestorWidgetOfExactType<MomentsPage>() != null;
                     
                     return Padding(
                       padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                       child: SkeuomorphicSearchBar(
                         value: isMomentsContext 
                             ? diaryProvider.momentsSearchQuery 
                             : diaryProvider.diarySearchQuery,
                         onChanged: (val) {
                           if (isMomentsContext) {
                             diaryProvider.setMomentsSearchQuery(val);
                           } else {
                             diaryProvider.setDiarySearchQuery(val);
                           }
                         },
                       ),
                     );
                   } catch (e) {
                     return const SizedBox.shrink();
                   }
                 }
               ),
               
               // Write Button (Only for Desktop/Non-Drawer)
               if (context.findAncestorWidgetOfExactType<Drawer>() == null)
                 Padding(
                   padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                   child: Material(
                     color: Colors.transparent,
                     child: InkWell(
                       onTap: () {
                          Navigator.push(
                            context,
                            LetterFoldPageRoute(page: EditorPage(entry: null)),
                          );
                       },
                       borderRadius: BorderRadius.circular(12),
                       child: Container(
                         padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            // Solid-like look but with gradient to simulate lighting (Bevel)
                            gradient: config['buttonGradient'],
                                        
                            // Rounded Corners (Restore)
                            borderRadius: BorderRadius.circular(10),
                            
                            boxShadow: [
                               config['buttonShadow'] as BoxShadow? ?? BoxShadow(
                                 color: Colors.black.withOpacity(0.3),
                                 offset: const Offset(0, 3), // Bottom shadow
                                 blurRadius: 6,
                               ),
                            ],
                            // Uniform Border to prevent Crash
                            // We use a subtle white stroke to sharpen edges
                            border: Border.all(
                                color: Colors.white.withOpacity(0.2), 
                                width: 1.0
                            ),
                          ),
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             const Icon(Icons.edit, color: Colors.white, size: 20),
                             const SizedBox(width: 8),
                             Text(
                               "写一篇",
                               style: GoogleFonts.notoSerifSc(
                                 color: Colors.white,
                                 fontSize: 16, // Slightly larger
                                 fontWeight: FontWeight.bold,
                                 letterSpacing: 2, // Wider spacing like reference
                                 shadows: [
                                   Shadow(color: Colors.black.withOpacity(0.2), offset: const Offset(0, 1), blurRadius: 2)
                                 ]
                               ),
                             )
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
                              if (context.findAncestorWidgetOfExactType<Drawer>() != null) {
                                 navigator.pop();
                                 // 等待侧边栏关闭动画，避免路由冲突导致卡死
                                 await Future.delayed(const Duration(milliseconds: 300));
                              }
                              
                              if (!isWriter) {
                                navigator.pushReplacement(
                                    PageRouteBuilder(
                                      pageBuilder: (_, __, ___) => const DiaryListPage(),
                                      transitionDuration: const Duration(milliseconds: 500), 
                                      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                                    )
                                );
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
                              if (context.findAncestorWidgetOfExactType<Drawer>() != null) {
                                 navigator.pop();
                                 await Future.delayed(const Duration(milliseconds: 300));
                              }
                              
                              if (!isMoments) {
                                navigator.pushReplacement(
                                    PageRouteBuilder(
                                      pageBuilder: (_, __, ___) => const MomentsPage(),
                                      transitionDuration: const Duration(milliseconds: 500),
                                      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                                    )
                                );
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
                              if (context.findAncestorWidgetOfExactType<Drawer>() != null) {
                                 navigator.pop();
                                 await Future.delayed(const Duration(milliseconds: 300));
                              }
                              
                              if (!isStatistics) {
                                navigator.push(
                                    PageRouteBuilder(
                                      pageBuilder: (_, __, ___) => const StatisticsPage(),
                                      transitionDuration: const Duration(milliseconds: 500),
                                      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                                    )
                                );
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
               Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: (theme == AppTheme.themeSeaFlower || theme == AppTheme.themeAfterRain) 
                        ? Colors.white.withOpacity(0.4) 
                        : (theme == AppTheme.themeGardenOfWords 
                            ? const Color(0xFF263238).withOpacity(0.4) // Deeper dark for Garden
                            : (theme == AppTheme.themeTwilight ? const Color(0xFF352044).withOpacity(0.4) : Colors.black26)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme == AppTheme.themeGardenOfWords ? Colors.white.withOpacity(0.05) : Colors.white10
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hitokoto?.hitokoto ?? '正在获取一言...',
                        style: GoogleFonts.notoSerifSc(
                          color: subTextColor, // Adapted
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                      if (_hitokoto != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '—— ${_hitokoto!.from}',
                            style: GoogleFonts.notoSerifSc(
                              color: subTextColor.withOpacity(0.8), // Adapted
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
               ),
               
               Divider(
                 color: (theme == AppTheme.themeSeaFlower) 
                    ? Colors.black12 
                    : (theme == AppTheme.themeGardenOfWords ? Colors.white.withOpacity(0.1) : Colors.white10), 
                 height: 1
               ),
               

               // Settings
               Padding(
                 padding: const EdgeInsets.symmetric(vertical: 10),
                 child: _buildMenuItem(
                   context, 
                   icon: Icons.settings_outlined, 
                   label: "设置", 
                   onTap: () {
                      if (context.findAncestorWidgetOfExactType<Drawer>() != null) {
                         Navigator.pop(context);
                      }
                      Navigator.push(context, SlidePageRoute(page: const SettingsPage()));
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
    );

    if (theme == AppTheme.themeSeaFlower || theme == AppTheme.themeAfterRain || theme == AppTheme.themeTwilight || theme == AppTheme.themeGardenOfWords) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Increased blur for rain effect
          child: sidebarContent,
        ),
      );
    }

    return sidebarContent;
  }

  Widget _buildMenuItem(BuildContext context, {
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
                    Icon(icon, color: isActive ? activeColor : textColor.withOpacity(0.7), size: 24),
                    const SizedBox(width: 20),
                    Text(
                      label,
                      style: GoogleFonts.notoSerifSc(
                        color: isActive ? activeColor : textColor,
                        fontSize: 16,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        letterSpacing: 1,
                      ),
                    )
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
