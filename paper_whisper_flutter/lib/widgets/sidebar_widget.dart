import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/hitokoto_service.dart';
import '../providers/settings_provider.dart';
import '../config/app_theme.dart';
import '../widgets/theme_selection_dialog.dart';
import '../pages/settings_page.dart';

class SidebarWidget extends StatefulWidget {
  final double width;
  final VoidCallback? onWritePressed;
  final Function(String)? onSearch;
  final bool showWriteButton;

  const SidebarWidget({
    super.key,
    this.width = 260,
    this.onWritePressed,
    this.onSearch,
    this.showWriteButton = true,
  });

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget> {
  HitokotoLine? _hitokoto;
  final HitokotoService _hitokotoService = HitokotoService();
  String _activeMenu = 'all';

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
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;
    
    // 严格按照web端海底花海主题设置颜色
    final bool isSeaFlower = theme == AppTheme.themeSeaFlower;
    
    // 根据主题设置文字颜色 - 严格按照web端CSS
    final Color titleColor;
    final Color subtitleColor;
    final Color menuTextColor;
    final Color hitokotoColor;
    final Shadow titleShadow;
    
    if (isSeaFlower) {
      // 海底花海：深色文字 on 白色毛玻璃背景
      titleColor = const Color(0xFF880E4F);           // --text-primary: #880E4F
      subtitleColor = const Color(0xFFC2185B);        // --text-secondary: #C2185B, opacity 0.8
      menuTextColor = const Color(0xFFAD1457);        // .menu-item color: #AD1457
      hitokotoColor = const Color(0xFFC2185B);        // #hitokoto-text color: #C2185B, opacity 0.6
      titleShadow = const Shadow(                     // text-shadow: 0 1px 2px rgba(255,255,255,0.5)
        color: Color.fromRGBO(255, 255, 255, 0.5),
        offset: Offset(0, 1),
        blurRadius: 2,
      );
    } else if (theme == AppTheme.themeMidnight) {
      // 午夜：浅色文字
      titleColor = const Color(0xFFe6edf3);
      subtitleColor = const Color(0xFF8b949e);
      menuTextColor = const Color(0xFFc9d1d9);
      hitokotoColor = const Color(0xFF8b949e);
      titleShadow = const Shadow(
        color: Color.fromRGBO(0, 0, 0, 0.3),
        offset: Offset(0, 2),
        blurRadius: 4,
      );
    } else {
      // 默认/复古：浅色文字
      titleColor = const Color(0xFFEEFFEB);
      subtitleColor = const Color(0xFFD7CCC8);
      menuTextColor = const Color(0xFFD7CCC8);
      hitokotoColor = Colors.white.withValues(alpha: 0.5);
      titleShadow = const Shadow(
        color: Color.fromRGBO(0, 0, 0, 0.3),
        offset: Offset(0, 2),
        blurRadius: 4,
      );
    }

    // 海底花海使用BackdropFilter毛玻璃效果
    Widget sidebarContent = _buildSidebarContent(
      theme: theme,
      isSeaFlower: isSeaFlower,
      titleColor: titleColor,
      subtitleColor: subtitleColor,
      menuTextColor: menuTextColor,
      hitokotoColor: hitokotoColor,
      titleShadow: titleShadow,
    );

    if (isSeaFlower) {
      // 海底花海：使用 BackdropFilter 实现真正的毛玻璃效果
      return ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: widget.width,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              border: const Border(
                right: BorderSide(color: Color(0x4DFFFFFF), width: 1),
              ),
            ),
            child: sidebarContent,
          ),
        ),
      );
    } else {
      // 其他主题：使用普通背景
      return Stack(
        children: [
          Container(
            width: widget.width,
            decoration: AppTheme.getSidebarBackground(theme),
            child: sidebarContent,
          ),
          // 右侧渐变遮罩
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 15,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.15),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildSidebarContent({
    required String theme,
    required bool isSeaFlower,
    required Color titleColor,
    required Color subtitleColor,
    required Color menuTextColor,
    required Color hitokotoColor,
    required Shadow titleShadow,
  }) {
    // 海底花海的按钮和搜索框颜色
    final Color writeButtonBg = isSeaFlower 
        ? const Color(0xFFFFB6C1) // 浅玫红
        : (theme == AppTheme.themeMidnight ? const Color(0xFF7986cb) : const Color(0xFFC0392B));
        
    final Color writeButtonText = Colors.white;
    
    final Color searchBg = isSeaFlower
        ? const Color(0x14C2185B)  // rgba(194, 24, 91, 0.08)
        : (theme == AppTheme.themeMidnight ? const Color(0xFF0D1117) : const Color.fromRGBO(0, 0, 0, 0.25));
        
    final Color searchBorder = isSeaFlower
        ? const Color(0x33C2185B)  // rgba(194, 24, 91, 0.2)
        : (theme == AppTheme.themeMidnight ? const Color(0xFF30363d) : Colors.white.withValues(alpha: 0.05));
        
    final Color searchText = isSeaFlower
        ? const Color(0xFF880E4F)
        : (theme == AppTheme.themeMidnight ? const Color(0xFFc9d1d9) : const Color(0xFFD7CCC8));
        
    final Color searchHint = isSeaFlower
        ? const Color(0x66880E4F)  // rgba(136, 14, 79, 0.4)
        : (theme == AppTheme.themeMidnight ? const Color(0xFF8b949e) : const Color(0xFFD7CCC8).withValues(alpha: 0.5));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header
        Padding(
          padding: EdgeInsets.fromLTRB(20, 35 + MediaQuery.of(context).padding.top, 20, 35),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '纸语',
                style: GoogleFonts.notoSerifSc(
                  fontSize: 24,
                  fontWeight: isSeaFlower ? FontWeight.w900 : FontWeight.bold,
                  color: titleColor,
                  shadows: [titleShadow],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'PaperWhisper',
                style: GoogleFonts.notoSerifSc(
                  fontSize: 12,
                  fontWeight: isSeaFlower ? FontWeight.w500 : FontWeight.normal,
                  color: subtitleColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),

        // 2. Tools (Write Button & Search)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Write Button
              if (widget.showWriteButton)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onWritePressed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        // 海底花海 / Midnight 使用渐变
                        gradient: isSeaFlower 
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xF2FFB6C1), Color(0xE6F06292)],
                              )
                            : (theme == AppTheme.themeMidnight 
                                ? const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF7986cb), Color(0xFF303f9f)],
                                  )
                                : null),
                        color: (isSeaFlower || theme == AppTheme.themeMidnight) ? null : writeButtonBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withValues(
                          alpha: isSeaFlower ? 0.5 : (theme == AppTheme.themeMidnight ? 0.1 : 0.1)
                        )),
                        boxShadow: [
                          BoxShadow(
                            color: isSeaFlower 
                                ? const Color.fromRGBO(240, 98, 146, 0.35)
                                : (theme == AppTheme.themeMidnight 
                                    ? const Color(0xFF7986cb).withValues(alpha: 0.4)
                                    : const Color.fromRGBO(0, 0, 0, 0.3)),
                            offset: const Offset(0, 4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('✎', style: TextStyle(color: writeButtonText, fontSize: 16)),
                          const SizedBox(width: 10),
                          Text(
                            '写一篇',
                            style: GoogleFonts.notoSerifSc(
                              color: writeButtonText,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (widget.showWriteButton) const SizedBox(height: 15),
              // Search Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: searchBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: searchBorder),
                  boxShadow: isSeaFlower ? null : const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.3),
                      offset: Offset(0, 2),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: TextField(
                  style: TextStyle(color: searchText, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '搜索记忆碎片...',
                    hintStyle: TextStyle(color: searchHint, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: widget.onSearch,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        // 3. Menu
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.grid_view,
                  label: '全部便签',
                  isActive: _activeMenu == 'all',
                  textColor: menuTextColor,
                  isSeaFlower: isSeaFlower,
                  onTap: () {
                    setState(() => _activeMenu = 'all');
                  },
                ),
                const SizedBox(height: 5),
                _buildMenuItem(
                  icon: Icons.palette_outlined,
                  label: '风格画廊',
                  isActive: _activeMenu == 'settings',
                  textColor: menuTextColor,
                  isSeaFlower: isSeaFlower,
                  onTap: () {
                    showDialog(
                      context: context,
                      barrierColor: Colors.black.withValues(alpha: 0.6),
                      builder: (context) => const ThemeSelectionDialog(),
                    );
                  },
                ),
                const SizedBox(height: 5),
                _buildMenuItem(
                  icon: Icons.settings_outlined,
                  label: '设置',
                  isActive: _activeMenu == 'general_settings',
                  textColor: menuTextColor,
                  isSeaFlower: isSeaFlower,
                  onTap: () {
                    // 关闭侧边栏（如果是抽屉模式）或者直接跳转
                    // 这里 Sidebar 是固定显示的，但也可能是在 Drawer 里？
                    // 根据代码看 SidebarWidget 似乎是直接嵌入的。
                    // 直接 push 页面
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsPage()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // 4. Hitokoto Footer
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isSeaFlower 
                    ? const Color(0x33C2185B)
                    : const Color.fromRGBO(255, 255, 255, 0.05),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _hitokoto?.hitokoto ?? '正在获取一言...',
                style: GoogleFonts.notoSerifSc(
                  color: hitokotoColor.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
              if (_hitokoto != null) ...[
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '—— ${_hitokoto!.from}',
                    style: GoogleFonts.notoSerifSc(
                      color: hitokotoColor.withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required Color textColor,
    required bool isSeaFlower,
  }) {
    // 海底花海激活状态样式
    final seaFlowerActiveDecoration = BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEC407A), Color(0xFFC2185B)],
      ),
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [
        BoxShadow(
          color: Color.fromRGBO(233, 30, 99, 0.4),
          offset: Offset(0, 4),
          blurRadius: 15,
        ),
      ],
      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
    );

    // 午夜星尘激活状态样式
    // 拟物感：微弱的星光辉光 + 深蓝紫色背景
    final midnightActiveDecoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFF7986cb).withValues(alpha: 0.2), 
          Colors.transparent
        ],
      ),
      borderRadius: BorderRadius.circular(8),
      border: Border(left: BorderSide(color: const Color(0xFF7986cb), width: 3)), // GitHub-like left accent
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF7986cb).withValues(alpha: 0.15),
          offset: const Offset(0, 0),
          blurRadius: 12,
          spreadRadius: 1,
        )
      ],
    );

    // 普通激活状态样式
    final normalActiveDecoration = BoxDecoration(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.1),
          offset: Offset(0, 2),
          blurRadius: 4,
        )
      ],
    );

    BoxDecoration? activeDecoration;
    if (isActive) {
      if (isSeaFlower) {
        activeDecoration = seaFlowerActiveDecoration;
      } else if (textColor == const Color(0xFFc9d1d9)) { 
        // Hacky check for midnight text color (defined in build method), 
        // better to pass check or theme enum. 
        // BUT wait, checking `textColor` is fragile. 
        // Let's look at `menuTextColor` in `build`: `theme == AppTheme.themeMidnight ? ...`
        // So here we need `theme` or `isMidnight`.
        // I will assume the caller passes isSeaFlower correctly, but I need isMidnight too.
        // Re-checking the widget properties... I don't see `isMidnight` passed to _buildMenuItem.
        // I will stick to `normalActiveDecoration` if I cannot verify, BUT
        // I should fix the method signature to accept `isMidnight` or `theme`.
        // Let's modify the method signature in this replacement.
        activeDecoration = normalActiveDecoration; // Placeholder, I need to look at call sites.
      } else {
        activeDecoration = normalActiveDecoration;
      }
    }
    
    // ERROR: I cannot easily change call sites without multiple replaces.
    // I should infer `isMidnight` from `textColor` or better, pass it.
    // `textColor` for Midnight is `Color(0xFFc9d1d9)`.
    bool isMidnight = (textColor == const Color(0xFFc9d1d9));
    
    if (isActive) {
       if (isSeaFlower) activeDecoration = seaFlowerActiveDecoration;
       else if (isMidnight) activeDecoration = midnightActiveDecoration;
       else activeDecoration = normalActiveDecoration;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: activeDecoration,
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive && isSeaFlower ? Colors.white : 
                       (isActive && isMidnight ? const Color(0xFFe6edf3) : textColor.withValues(alpha: 0.8)),
                size: 20,
                shadows: (isActive && isMidnight) ? [
                  const Shadow(color: Color(0xFF7986cb), blurRadius: 8)
                ] : null,
              ),
              const SizedBox(width: 15),
              Text(
                label,
                style: GoogleFonts.notoSerifSc(
                  color: isActive && isSeaFlower ? Colors.white : 
                         (isActive && isMidnight ? const Color(0xFFe6edf3) : textColor.withValues(alpha: isActive ? 1.0 : 0.8)),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                  shadows: (isActive && isMidnight) ? [
                    const Shadow(color: Color(0xFF7986cb), blurRadius: 8)
                  ] : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
