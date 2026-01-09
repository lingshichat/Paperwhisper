import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/hitokoto_service.dart';
import '../providers/settings_provider.dart'; // Added
import '../config/app_theme.dart';
import '../widgets/theme_selection_dialog.dart'; // Will create this later

class SidebarWidget extends StatefulWidget {
  final double width;
  final VoidCallback? onWritePressed;
  final Function(String)? onSearch;
  final bool showWriteButton; // 是否显示"写一篇"按钮

  const SidebarWidget({
    super.key,
    this.width = 260,
    this.onWritePressed,
    this.onSearch,
    this.showWriteButton = true, // 默认显示
  });

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget> {
  HitokotoLine? _hitokoto;
  final HitokotoService _hitokotoService = HitokotoService();
  String _activeMenu = 'all'; // 'all', 'settings'

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
    final textColor = theme == AppTheme.themeDefault ? const Color(0xFFEEFFEB) : Colors.white;
    final subTextColor = theme == AppTheme.themeDefault ? const Color(0xFFD7CCC8) : Colors.white70;

    return Stack(
      children: [
        // 主侧边栏内容
        Container(
          width: widget.width,
          decoration: AppTheme.getSidebarBackground(theme),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 35, 20, 35),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '纸语',
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    shadows: [
                      const Shadow(
                        color: Color.fromRGBO(0, 0, 0, 0.3),
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'PaperWhisper',
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 12,
                    color: subTextColor.withValues(alpha: 0.8),
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
                // Write Button - 根据参数决定是否显示
                if (widget.showWriteButton)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: widget.onWritePressed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC0392B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(0, 0, 0, 0.3),
                              offset: Offset(0, 4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('✎', style: TextStyle(color: Colors.white, fontSize: 16)),
                            const SizedBox(width: 10),
                            Text(
                              '写一篇',
                              style: GoogleFonts.notoSerifSc(
                                color: Colors.white,
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
                    color: const Color.fromRGBO(0, 0, 0, 0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.3),
                        offset: Offset(0, 2),
                        blurRadius: 5,
                        // blurStyle: BlurStyle.inner // Flutter doesn't support inset shadow directly yet simply
                        // We will simulate inset via a stack if needed, or stick to this for now
                      ),
                    ],
                  ),
                  child: TextField(
                    style: const TextStyle(color: Color(0xFFD7CCC8), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '搜索记忆碎片...',
                      hintStyle: TextStyle(
                        color: const Color(0xFFD7CCC8).withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
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
                    icon: '≡',
                    label: '全部便签',
                    isActive: _activeMenu == 'all',
                    onTap: () {
                      setState(() => _activeMenu = 'all');
                      // Navigate or filter
                    },
                  ),
                  const SizedBox(height: 5),
                  _buildMenuItem(
                    icon: '⚙',
                    label: '设置风格',
                    isActive: _activeMenu == 'settings',
                    onTap: () {
                      // Show Theme Dialog
                       showDialog(
                        context: context,
                        barrierColor: Colors.black.withValues(alpha: 0.6),
                        builder: (context) => const ThemeSelectionDialog(),
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
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.05))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hitokoto?.hitokoto ?? '正在获取一言...',
                  style: GoogleFonts.notoSerifSc(
                    color: Colors.white.withValues(alpha: 0.5),
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
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
        ),
        // 右侧渐变遮罩 - 实现与主背景的柔和过渡
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

  Widget _buildMenuItem({
    required String icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    const BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.1),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              Text(
                icon,
                style: TextStyle(
                  color: const Color(0xFFD7CCC8).withValues(alpha: 0.8),
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 15),
              Text(
                label,
                style: GoogleFonts.notoSerifSc(
                  color: const Color(0xFFD7CCC8).withValues(alpha: isActive ? 1.0 : 0.8),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
