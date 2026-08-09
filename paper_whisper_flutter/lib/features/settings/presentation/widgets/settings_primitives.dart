/// 设置页通用展示 primitive。
///
/// 全部颜色、阴影与装饰由页面显式传入（避免直接依赖 AppTheme 动态 Map 强转），
/// 组件保持纯展示：无业务、无 Provider、不持有 BuildContext 跨 async。
/// 尺寸 / 圆角 / 阴影 / GoogleFonts 与可访问 tap、disabled、loading 行为
/// 与原 settings_page 私有实现逐字一致。
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 设置分组标题。
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({
    super.key,
    required this.title,
    required this.textColor,
  });

  final String title;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.notoSerifSc(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: textColor.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

/// 设置分组容器：承载组背景，内部项保持透明。
class SettingsGroupContainer extends StatelessWidget {
  const SettingsGroupContainer({
    super.key,
    required this.decoration,
    required this.children,
  });

  final BoxDecoration decoration;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

/// 分组内分隔线。
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: color);
  }
}

/// 设置项：图标 + 标题/副标题 + 默认箭头（loading 时显示进度）。
///
/// 背景由外层 Group Container 承担，内部保持透明；
/// [onTap] 为 null 时 InkWell 禁用。
class SettingsItem extends StatelessWidget {
  const SettingsItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.textColor,
    this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color textColor;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // Note: Background is now handled by Group Container. Inner items are transparent.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: textColor.withValues(alpha: 0.8), size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 16,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 13,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      textColor.withValues(alpha: 0.6),
                    ),
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios,
                  color: textColor.withValues(alpha: 0.4),
                  size: 14,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 设置开关项：图标 + 标题/副标题 + Switch。
class SettingsSwitchItem extends StatelessWidget {
  const SettingsSwitchItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.textColor,
    required this.activeThumbColor,
    required this.activeTrackColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color textColor;
  final Color activeThumbColor;
  final Color activeTrackColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: textColor.withValues(alpha: 0.8), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 16,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 13,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: activeThumbColor,
              activeTrackColor: activeTrackColor,
            ),
          ],
        ),
      ),
    );
  }
}

/// 拟物底部弹层框架：顶部胶带/把手 + 标题 + 可滚动内容。
class SettingsBottomSheetFrame extends StatelessWidget {
  const SettingsBottomSheetFrame({
    super.key,
    required this.title,
    required this.titleColor,
    required this.backgroundColor,
    required this.tapeColor,
    required this.shadows,
    required this.border,
    required this.showTape,
    required this.children,
  });

  final String title;
  final Color titleColor;
  final Color backgroundColor;
  final Color tapeColor;
  final List<BoxShadow> shadows;
  final BoxBorder? border;
  final bool showTape;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: shadows,
        border: border,
      ),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Tape Decoration (Top Center)
          if (showTape)
            Positioned(
              top: -15,
              child: Transform.rotate(
                angle: -0.02,
                child: Container(
                  width: 80,
                  height: 25,
                  decoration: BoxDecoration(
                    color: tapeColor,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Handle for other themes
          if (!showTape)
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: titleColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

          Padding(
            padding: const EdgeInsets.only(top: 40), // Space for tape/handle
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch items
              children: [
                Text(
                  title,
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: children,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 选项块：选中/未选中两态样式由页面注入，点击回调由页面决策。
class SettingsOptionTile extends StatelessWidget {
  const SettingsOptionTile({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.selectedBackgroundColor,
    this.unselectedBackgroundColor,
    this.selectedTextColor,
    this.unselectedTextColor,
    this.selectedShadow,
    this.unselectedShadow,
    this.unselectedBorder,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? selectedBackgroundColor;
  final Color? unselectedBackgroundColor;
  final Color? selectedTextColor;
  final Color? unselectedTextColor;
  final BoxShadow? selectedShadow;
  final BoxShadow? unselectedShadow;
  final Border? unselectedBorder;

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? selectedBackgroundColor
        : unselectedBackgroundColor;
    final textColor = isSelected ? selectedTextColor : unselectedTextColor;
    final shadow = isSelected ? selectedShadow : unselectedShadow;
    final border = isSelected ? null : unselectedBorder;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4), // Dialog style small radius
          boxShadow: shadow != null ? [shadow] : null,
          border: border,
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center, // Center text like a button
          children: [
            Text(
              label,
              style: GoogleFonts.notoSerifSc(
                fontSize: 16,
                color: textColor,
                fontWeight: FontWeight.bold, // Always bold like buttons
              ),
            ),
            // Optional: Add Check icon if selected?
            // Dialog buttons usually don't have check icons, just distinct style.
            // But for selection, a check might be nice.
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check,
                size: 18,
                color: textColor?.withValues(alpha: 0.8),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
