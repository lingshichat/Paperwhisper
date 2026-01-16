import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/hitokoto_service.dart';
import '../config/app_theme.dart';
import '../pages/diary_list_page.dart';
import '../pages/moments_page.dart';
import '../pages/settings_page.dart';
import '../widgets/slide_page_route.dart';
import '../providers/settings_provider.dart';
import '../pages/editor_page.dart';
import '../pages/trash_page.dart';
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
    
    int activeIndex = -1;
    if (isWriter) activeIndex = 0;
    if (isMoments) activeIndex = 1;

    final theme = Provider.of<SettingsProvider>(context).currentTheme;
    
    // Theme Configs
    BoxDecoration bgDecor;
    Color textColor;
    Color activeTextColor;
    Color subTextColor;
    Color pillColor;
    List<BoxShadow> pillShadows;
    BoxBorder? pillBorder;
    
    // 1. Sea Flower (Light/Pink)
    if (theme == AppTheme.themeSeaFlower) {
       bgDecor = BoxDecoration(
          color: const Color(0xFFFCE4EC).withOpacity(0.6), // Pink 50 with opacity for blur
          // Removed leather texture for clean look, or use a soft paper texture if available
          // image: DecorationImage(image: AssetImage('assets/textures/paper_1.png'), opacity: 0.1, fit: BoxFit.cover),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(5, 0))]
       );
       textColor = const Color(0xFF880E4F); // Pink 900
       activeTextColor = const Color(0xFFD81B60); // Pink 600
       subTextColor = const Color(0xFFBC477B); // Pink 300
       pillColor = Colors.white;
       pillShadows = [
          BoxShadow(color: const Color(0xFFF48FB1).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
       ];
       pillBorder = null;
    } 
    // 2. Midnight (Deep Blue/Dark)
    else if (theme == AppTheme.themeMidnight) {
       bgDecor = const BoxDecoration(
          color: Color(0xFF0D1117), 
          // image: DecorationImage(image: AssetImage('assets/textures/starry_bg.png'), fit: BoxFit.cover, opacity: 0.3), // If available
          border: Border(right: BorderSide(color: Colors.white12)),
          boxShadow: [BoxShadow(color: Colors.black87, blurRadius: 10, offset: Offset(5, 0))]
       );
       textColor = const Color(0xFFc9d1d9);
       activeTextColor = const Color(0xFF7986cb); // Indigo Light
       subTextColor = const Color(0xFF8b949e);
       pillColor = const Color(0xFF161b22);
       pillShadows = [
          BoxShadow(color: const Color(0xFF7986cb).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 0), spreadRadius: 1),
       ];
       pillBorder = Border.all(color: Colors.white10);
    }
    // 3. Amber Lens (Existing/Dark Leather)
    else if (theme == AppTheme.themeAmberLens) {
      bgDecor = const BoxDecoration(
          color: Color(0xFF2C2C2C),
          image: DecorationImage(
            image: ResizeImage(
               AssetImage('assets/textures/leather_dark.png'),
               width: 1080,
            ),
            fit: BoxFit.cover,
            opacity: 0.5,
          ),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(5, 0))]
      );
      textColor = const Color(0xFFBDBDBD);
      activeTextColor = const Color(0xFFFF9800); // Amber
      subTextColor = const Color(0xFF757575);
      pillColor = const Color(0xFF222222);
      pillShadows = [
          BoxShadow(color: Colors.white10, offset: Offset(0, 1), blurRadius: 0),
          BoxShadow(color: Colors.black87, offset: Offset(0, -2), blurRadius: 1)
      ];
      pillBorder = null;
    }
    // 4. Default / Vintage (Dark Metal/Leather)
    else {
       bgDecor = const BoxDecoration(
          color: Color(0xFF3E2723), // Dark Brown
          image: DecorationImage(
            image: ResizeImage(
               AssetImage('assets/textures/leather_dark.png'),
               width: 1080
            ), // Reuse leather
            fit: BoxFit.cover,
            opacity: 0.6,
          ),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(5, 0))]
       );
       textColor = const Color(0xFFD7CCC8); // Beige
       activeTextColor = const Color(0xFFFF5252); // Red Accent
       subTextColor = const Color(0xFFA1887F);
       pillColor = const Color(0xFF2D1E1B); 
       pillShadows = [
           BoxShadow(color: Colors.white10, offset: Offset(0, 1), blurRadius: 0),
           BoxShadow(color: Colors.black87, offset: Offset(0, -2), blurRadius: 1)
       ];
       pillBorder = null;
    }

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
                     final diaryProvider = context.watch<DiaryProvider>();
                     return Padding(
                       padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                       child: SkeuomorphicSearchBar(
                         value: diaryProvider.searchQuery,
                         onChanged: (val) => diaryProvider.setSearchQuery(val),
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
                            // This avoids "borderRadius with non-uniform borders" crash
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: theme == AppTheme.themeSeaFlower
                                    ? [const Color(0xFFF06292), const Color(0xFFD81B60)] // Pink Light -> Dark
                                    : theme == AppTheme.themeMidnight
                                        ? [const Color(0xFF7986cb), const Color(0xFF3F51B5)] // Indigo Light -> Dark
                                        : theme == AppTheme.themeAmberLens
                                            ? [const Color(0xFFFFB74D), const Color(0xFFF57C00)] // Amber Light -> Dark
                                            : [const Color(0xFFE57373), const Color(0xFFD32F2F)], // Red Light -> Dark (Simulates Highlight Top, Shadow Bottom)
                            ),
                                        
                            // Rounded Corners (Restore)
                            borderRadius: BorderRadius.circular(10),
                            
                            boxShadow: [
                               // Drop Shadow (Soft)
                               BoxShadow(
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
                           onTap: () {
                              if (context.findAncestorWidgetOfExactType<Drawer>() != null) {
                                 Navigator.pop(context);
                              }
                              
                              if (!isWriter) {
                                Navigator.pushReplacement(
                                    context, 
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
                           onTap: () {
                              if (context.findAncestorWidgetOfExactType<Drawer>() != null) {
                                 Navigator.pop(context);
                              }
                              
                              if (!isMoments) {
                                Navigator.pushReplacement(
                                    context, 
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
                    color: theme == AppTheme.themeSeaFlower ? Colors.white54 : Colors.black26, // Lighter for SeaFlower
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
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
               
               Divider(color: theme == AppTheme.themeSeaFlower ? Colors.black12 : Colors.white10, height: 1),
               

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

    if (theme == AppTheme.themeSeaFlower) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
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
