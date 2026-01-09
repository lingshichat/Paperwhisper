import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/diary_provider.dart';
import '../providers/settings_provider.dart';
import '../models/diary_entry.dart';
import '../config/app_theme.dart';
import '../widgets/skeuomorphic_container.dart';
import '../widgets/sidebar_widget.dart';
import '../widgets/visual_effects.dart'; // Added
import 'editor_page.dart';

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
                         width: 260,
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
          return Scaffold(
            drawer: SidebarWidget(
              width: 260,
              showWriteButton: false, // 移动端不显示"写一篇"按钮，因为有悬浮按钮
              onWritePressed: () {
                Navigator.pop(context);
                _openEditor(null);
              },
              onSearch: (val) {
                 setState(() => _searchQuery = val);
              },
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
               backgroundColor: const Color(0xFFC0392B),
               onPressed: () => _openEditor(null),
               child: const Icon(Icons.edit, color: Colors.white),
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
        // Mobile Header - 优化设计：增加应用名和装饰元素
        if (isMobile)
           Builder(
             builder: (scaffoldContext) => Stack(
               children: [
                 // 主顶栏
                 Container(
                   height: 56 + MediaQuery.of(scaffoldContext).padding.top,
                   padding: EdgeInsets.only(top: MediaQuery.of(scaffoldContext).padding.top),
                   decoration: BoxDecoration(
                     // 半透明毛玻璃效果背景
                     color: const Color(0xFF3e2723).withValues(alpha: 0.85),
                     border: const Border(
                       bottom: BorderSide(color: Color(0xFF1a100d), width: 1),
                     ),
                     boxShadow: [
                       BoxShadow(
                         color: Colors.black.withValues(alpha: 0.3),
                         blurRadius: 8,
                         offset: const Offset(0, 2),
                       ),
                     ],
                   ),
                   child: Row(
                     children: [
                       // 汉堡包菜单按钮
                       IconButton(
                         icon: const Icon(Icons.menu, color: Color(0xFFD7CCC8)),
                         onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
                       ),
                       // 应用名称 - 与侧边栏logo样式一致但更紧凑
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
                                 color: const Color(0xFFEEFFEB),
                                 shadows: const [
                                   Shadow(
                                     color: Color.fromRGBO(0, 0, 0, 0.3),
                                     offset: Offset(0, 1),
                                     blurRadius: 2,
                                   ),
                                 ],
                               ),
                             ),
                             const SizedBox(width: 6),
                             Text(
                               'PaperWhisper',
                               style: GoogleFonts.notoSerifSc(
                                 fontSize: 10,
                                 color: const Color(0xFFD7CCC8).withValues(alpha: 0.8),
                               ),
                             ),
                           ],
                         ),
                       ),
                       // 右侧占位保持标题居中
                       const SizedBox(width: 48),
                     ],
                   ),
                 ),
                 // 底部渐变遮罩 - 实现与主背景的柔和过渡
                 Positioned(
                   left: 0,
                   right: 0,
                   bottom: -10,
                   child: IgnorePointer(
                     child: Container(
                       height: 15,
                       decoration: BoxDecoration(
                         gradient: LinearGradient(
                           begin: Alignment.topCenter,
                           end: Alignment.bottomCenter,
                           colors: [
                             Colors.black.withValues(alpha: 0.15),
                             Colors.transparent,
                           ],
                         ),
                       ),
                     ),
                   ),
                 ),
               ],
             ),
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
    return GestureDetector(
      onTap: () => _openEditor(entry),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: RepaintBoundary(
          child: SkeuomorphicContainer.paper(
            padding: const EdgeInsets.all(25),
            bgColor: AppTheme.getPaperColor(theme),
            shadows: [
               const BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.1), // Initial shadow
                offset: Offset(0, 5),
                blurRadius: 10,
              )
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meta (Bottom Border Dashed)
                Container(
                  padding: const EdgeInsets.only(bottom: 8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Color.fromRGBO(93, 64, 55, 0.15),
                        style: BorderStyle.none // Flutter doesn't support dashed easily without CustomPaint
                        // We can use a Row of dots or small dashes if we want strict fidelity
                        // For now solid light line
                      )
                    )
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.dateString,
                        style: GoogleFonts.courierPrime(
                          fontSize: 12,
                          color: const Color(0xFF8D6E63),
                        ),
                      ),
                      // Icons
                      Row(
                        children: [
                           // Placeholder icons, could be mapped from entry.weather
                           const Icon(Icons.wb_sunny_outlined, size: 16, color: Color(0xFF8D6E63)),
                           const SizedBox(width: 5),
                           const Icon(Icons.sentiment_satisfied, size: 16, color: Color(0xFF8D6E63)),
                        ],
                      )
                    ],
                  ),
                ),
                // CustomPaint for dashed line if needed
                CustomPaint(
                  size: const Size(double.infinity, 1),
                  painter: DashedLinePainter(color: const Color.fromRGBO(93, 64, 55, 0.15)),
                ),
                const SizedBox(height: 12),
                
                // Title
                Text(
                  entry.title,
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF5D4037),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Preview
                Text(
                  entry.content.replaceAll('\n', ' ').substring(0, entry.content.length > 80 ? 80 : entry.content.length) + (entry.content.length > 80 ? '...' : ''),
                  style: GoogleFonts.notoSerifSc(
                     fontSize: 15,
                     height: 1.8,
                     color: const Color(0xFF5D4037).withValues(alpha: 0.9),
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  const DashedLinePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    var max = size.width;
    var dashWidth = 5;
    var dashSpace = 3;
    double startX = 0;
    while (startX < max) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
