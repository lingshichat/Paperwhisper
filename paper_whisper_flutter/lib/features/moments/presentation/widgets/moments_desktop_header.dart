import 'package:flutter/material.dart';

import 'moments_date_title.dart';

/// 桌面端随心记页头（纯展示，props 驱动）。
///
/// 原 `moments_page._buildDesktopHeader`：月份标题 + 生成日记按钮。
/// 颜色由页面从主题 Map 取出后传入。
class MomentsDesktopHeader extends StatelessWidget {
  const MomentsDesktopHeader({
    super.key,
    required this.selectedDate,
    required this.textColor,
    required this.iconColor,
    required this.onGenerate,
    required this.expanded,
    required this.onTitleTap,
  });

  /// 当前选中日期（用于「2026年3月」标题）。
  final DateTime selectedDate;

  final Color textColor;
  final Color iconColor;

  /// 生成今日日记回调。
  final VoidCallback onGenerate;

  /// 月历是否展开（箭头旋转）。
  final bool expanded;

  /// 点击中央日期标题。
  final VoidCallback onTitleTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, expanded ? 0 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05), // Subtle bg for header
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          // Leading (empty or back?) - No drawer icon needed
          const SizedBox(
            width: 48,
          ), // Spacer to center title if needed, or just let it adjust
          Expanded(
            child: Center(
              child: MomentsDateTitle(
                selectedDate: selectedDate,
                textColor: textColor,
                iconColor: iconColor,
                expanded: expanded,
                onTap: onTitleTap,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('desktop_generate_btn'),
            icon: Icon(Icons.description_outlined, color: iconColor),
            tooltip: '生成今日日记',
            onPressed: onGenerate,
          ),
        ],
      ),
    );
  }
}
