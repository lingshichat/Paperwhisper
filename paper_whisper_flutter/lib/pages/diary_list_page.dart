import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/diary_provider.dart';
import '../providers/settings_provider.dart';
import '../models/diary_entry.dart';
import '../config/app_theme.dart';
import '../widgets/skeuomorphic_container.dart';
import '../widgets/sidebar_widget.dart';
import '../widgets/visual_effects.dart';
import '../widgets/dashed_line_painter.dart';
import 'editor_page.dart';
import 'diary_card.dart'; // Added

class DiaryListPage extends StatefulWidget {
  const DiaryListPage({super.key});

  @override
  State<DiaryListPage> createState() => _DiaryListPageState();
}

class _DiaryListPageState extends State<DiaryListPage> {
  String _searchQuery = '';
  bool _isSidebarCollapsed = false; // 桌面端侧边栏折叠状态
  
  void _openEditor(DiaryEntry? entry) {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => EditorPage(entry: entry))
    );
  }

  @override
  Widget build(BuildContext context) {
    // We access settings just to trigger rebuilds on theme change if needed
    // But mostly AppTheme handles the static logic or we use Consumer below
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop breakpoint: > 800px (Matches "Tablet/Desktop" logic from plan)
        final bool isDesktop = constraints.maxWidth > 800;

        // Content Area (The Waterfall Layout)
        // We will put this in a Widget to reuse
        final Widget contentArea = _buildContentArea(context, theme, !isDesktop);

        if (isDesktop) {
          // Desktop: Fixed Sidebar + Content
          return Scaffold(
             backgroundColor: Colors.transparent, 
             body: Stack(
               children: [
                 // 1. Background
                 Container(decoration: AppTheme.getBackground(theme)),
                 
                 // 2. Visual Effects
                 if (theme == AppTheme.themeSeaFlower) const PetalRainWidget(),
                 if (theme == AppTheme.themeMidnight) const StarrySkyWidget(),

                 // 3. Main Layout
                 Row(
                    children: [
                       SidebarWidget(
                         width: 300, // Fixed: 260 width + 40 padding = 300 actual width
                         onWritePressed: () => _openEditor(null),
                         onSearch: (val) => setState(() => _searchQuery = val),
                       ),
                       Expanded(
                         child: contentArea,
                       ),
                    ],
                 ),
               ],
             ),
          );
        } else {
          // Mobile: Drawer + Content
          final bool isSeaFlower = theme == AppTheme.themeSeaFlower;
          
          return Scaffold(
            drawerScrimColor: isSeaFlower ? Colors.transparent : Colors.black54, // 海底花海去遮罩，透出背景
            drawer: Drawer(
              width: 300,
              elevation: 0, // Remove elevation shadow
              backgroundColor: Colors.transparent, 
              child: SidebarWidget(
                width: 300, 
                showWriteButton: false, 
                onWritePressed: () {
                  Navigator.pop(context);
                  _openEditor(null);
                },
                onSearch: (val) {
                   setState(() => _searchQuery = val);
                },
              ),
            ),
            // Mobile Body
            body: Stack(
              children: [
                Container(decoration: AppTheme.getBackground(theme)),
                if (theme == AppTheme.themeSeaFlower) const PetalRainWidget(),
                if (theme == AppTheme.themeMidnight) const StarrySkyWidget(),
                contentArea,
              ],
            ),
             floatingActionButton: FloatingActionButton(
               backgroundColor: isSeaFlower || theme == AppTheme.themeMidnight ? Colors.transparent : const Color(0xFFC0392B),
               elevation: (isSeaFlower || theme == AppTheme.themeMidnight) ? 0 : 6, 
               focusElevation: (isSeaFlower || theme == AppTheme.themeMidnight) ? 0 : 6,
               hoverElevation: (isSeaFlower || theme == AppTheme.themeMidnight) ? 0 : 8,
               highlightElevation: (isSeaFlower || theme == AppTheme.themeMidnight) ? 0 : 12,
               onPressed: () => _openEditor(null),
               child: Container(
                 width: 56, 
                 height: 56,
                 decoration: isSeaFlower 
                   ? const BoxDecoration(
                       shape: BoxShape.circle,
                       gradient: LinearGradient(
                         begin: Alignment.topLeft,
                         end: Alignment.bottomRight,
                         colors: [Color(0xFFF8BBD0), Color(0xFFF06292)],
                       ),
                       boxShadow: [
                         BoxShadow(
                           color: Color.fromRGBO(240, 98, 146, 0.5),
                           blurRadius: 12,
                           offset: Offset(0, 4),
                         )
                       ]
                     )
                   : (theme == AppTheme.themeMidnight 
                       ? const BoxDecoration(
                           shape: BoxShape.circle,
                           gradient: LinearGradient(
                             begin: Alignment.topLeft,
                             end: Alignment.bottomRight,
                             colors: [Color(0xFF7986cb), Color(0xFF303f9f)],
                           ),
                           boxShadow: [
                             BoxShadow(
                               color: Color.fromRGBO(121, 134, 203, 0.5), // Indigo Glow
                               blurRadius: 15,
                               offset: Offset(0, 0),
                               spreadRadius: 2,
                             )
                           ]
                         )
                       : null),
                 child: Icon(Icons.edit, color: Colors.white, size: (isSeaFlower || theme == AppTheme.themeMidnight) ? 28 : 24),
               ),
             ),
          );
        }
      },
    );
  }
  
  Widget _buildContentArea(BuildContext context, String theme, bool isMobile) {
    final diaryProvider = Provider.of<DiaryProvider>(context);
    
    // Filter
    final list = diaryProvider.entries.where((e) {
      if (_searchQuery.isEmpty) return true;
      return e.title.contains(_searchQuery) || e.content.contains(_searchQuery) || e.dateString.contains(_searchQuery);
    }).toList();

    return Column(
      children: [
        // Mobile Header
        if (isMobile)
           Builder(
             builder: (scaffoldContext) {
               final headerColors = AppTheme.getMobileHeaderColors(theme);
               final bool isSeaFlower = theme == AppTheme.themeSeaFlower;
               
               Widget headerContent = Container(
                     height: 56 + MediaQuery.of(scaffoldContext).padding.top,
                     padding: EdgeInsets.only(top: MediaQuery.of(scaffoldContext).padding.top),
                     decoration: BoxDecoration(
                       color: headerColors['background'],
                       border: Border(
                         bottom: BorderSide(color: headerColors['border']!, width: 1),
                       ),
                       boxShadow: [
                         BoxShadow(
                           color: Colors.black.withValues(alpha: 0.1), // Lighter shadow
                           blurRadius: 4,
                           offset: const Offset(0, 2),
                         ),
                       ],
                     ),
                     child: Row(
                       children: [
                         IconButton(
                           icon: Icon(Icons.menu, color: headerColors['iconColor']),
                           onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
                         ),
                         Expanded(
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.center,
                             crossAxisAlignment: CrossAxisAlignment.baseline,
                             textBaseline: TextBaseline.alphabetic,
                             children: [
                               Text(
                                 '纸语',
                                 style: GoogleFonts.notoSerifSc(
                                   fontSize: 18,
                                   fontWeight: FontWeight.bold,
                                   color: headerColors['titleColor'],
                                   shadows: const [
                                     Shadow(
                                       color: Color.fromRGBO(0, 0, 0, 0.1),
                                       offset: Offset(0, 1),
                                       blurRadius: 1,
                                     ),
                                   ],
                                 ),
                               ),
                               const SizedBox(width: 6),
                               Text(
                                 'PaperWhisper',
                                 style: GoogleFonts.notoSerifSc(
                                   fontSize: 10,
                                   color: headerColors['subtitleColor'],
                                 ),
                               ),
                             ],
                           ),
                         ),
                         const SizedBox(width: 48),
                       ],
                     ),
                   );

               // Apply Blur for Sea Flower
               if (isSeaFlower) {
                 return ClipRRect(
                   child: BackdropFilter(
                     filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                     child: headerContent,
                   ),
                 );
               }
               
               return headerContent;
             },
           ),

        
        // Waterfall List
        Expanded(
          child: list.isEmpty 
              ? _buildEmptyState(theme)
              : _buildWaterfallGrid(context, list, theme),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String theme) {
    // 使用侧栏文字颜色 - 在深色背景上可见的浅色
    // 参考 web端 CSS: --sidebar-text: #d7ccc8 (浅米色)
    final Color emptyTextColor;
    final Color accentColor;
    
    switch (theme) {
      case AppTheme.themeMidnight:
        emptyTextColor = const Color(0xFFc9d1d9); // 浅灰白色
        accentColor = const Color(0xFF7986cb);    // 靛蓝色
        break;
      case AppTheme.themeSeaFlower:
        emptyTextColor = const Color(0xFFC2185B); // 洋红色
        accentColor = const Color(0xFFF50057);    // 玫瑰红
        break;
      default: // vintage/default
        emptyTextColor = const Color(0xFFd7ccc8); // 浅米色 (与侧栏文字一致)
        accentColor = const Color(0xFFc0392b);    // 红色
    }
    
    return Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           // 图标
           Opacity(
             opacity: 0.5,
             child: Text(
               '🕸️', 
               style: TextStyle(
                 fontSize: 64,
                 color: emptyTextColor,
               ),
             ),
           ),
           const SizedBox(height: 20),
           // 提示文字 - 使用浅色以在深色背景上可见
           Opacity(
             opacity: 0.8,
             child: Text(
               _searchQuery.isNotEmpty 
                 ? '没有找到关于"$_searchQuery"的回忆呢...'
                 : '这里似乎落了一层灰，等待你来翻阅',
               textAlign: TextAlign.center,
               style: GoogleFonts.notoSerifSc(
                 color: emptyTextColor,
                 fontSize: 16,
                 fontStyle: FontStyle.italic,
                 letterSpacing: 2,
               ),
             ),
           ),
           // 只在非搜索模式下显示"写一篇"按钮
           if (_searchQuery.isEmpty) ...[
             const SizedBox(height: 30),
             // "去写一篇"按钮 - 参考web端: 底部虚线边框样式
             GestureDetector(
               onTap: () => _openEditor(null),
               child: MouseRegion(
                 cursor: SystemMouseCursors.click,
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text(
                           '去擦拭灰尘 (写一篇)',
                           style: GoogleFonts.notoSerifSc(
                             color: accentColor,
                             fontSize: 14,
                           ),
                         ),
                         const SizedBox(width: 4),
                         Text(
                           '→',
                           style: TextStyle(
                             color: accentColor,
                             fontSize: 14,
                           ),
                         ),
                       ],
                     ),
                     const SizedBox(height: 2),
                     // 虚线边框
                     CustomPaint(
                       size: const Size(150, 1),
                       painter: DashedLinePainter(color: accentColor),
                     ),
                   ],
                 ),
               ),
             ),
           ],
         ],
       ),
    );
  }

  Widget _buildWaterfallGrid(BuildContext context, List<DiaryEntry> list, String theme) {
    // Determine column count based on width
    // We use LayoutBuilder again for the inner content width
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columnCount = 1;
        if (width > 1100) {
          columnCount = 3;
        } else if (width > 700) {
          columnCount = 2;
        }

        // Masonry Logic: Distribute items into columns
        List<List<DiaryEntry>> columns = List.generate(columnCount, (_) => []);
        for (int i = 0; i < list.length; i++) {
          columns[i % columnCount].add(list[i]);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < columnCount; i++)
                Expanded(
                  child: Padding(
                    padding: i < columnCount - 1 
                        ? const EdgeInsets.only(right: 30) // Column Gap
                        : EdgeInsets.zero,
                    child: Column(
                      children: columns[i].map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 30), // Item Gap
                          child: _buildDiaryCard(context, entry, theme),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiaryCard(BuildContext context, DiaryEntry entry, String theme) {
    return DiaryCard(
      entry: entry, 
      theme: theme,
      onTap: () => _openEditor(entry),
    );
  }
}
