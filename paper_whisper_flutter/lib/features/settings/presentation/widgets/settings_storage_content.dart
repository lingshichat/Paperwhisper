/// 设置页「用户数据管理」弹层内容（纯展示）。
///
/// 从 settings_page `_showStorageManager` 提取：
/// - 输入 internalStats / hasInternalClutter 与颜色 props，清理动作通过
///   VoidCallback 上抛（页面负责 Navigator.pop / Toast / IO 编排）；
/// - 不持有 BuildContext 跨 async，不执行任何 IO / Toast / Dialog；
/// - 操作行为 ListTile 结构，与 settings_page 原 `_showStorageManager`
///   逐字视觉等价（默认 contentPadding、leading 原色、title 无额外
///   weight/size、subtitle 12）；外层透明 Material 仅修 ListTile 断言；
/// - 两操作行间分隔线保留原默认高度（不设 height）；
/// - 文案 / 图标 / 顺序 / conditional（残留数据、字体缓存）与原实现逐字一致。
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 用户数据管理弹层内容：清理操作 + 系统运行数据 overview 卡片。
///
/// 内部运行数据卡片条件行：
/// - `>> 发现残留数据，点击清理` 仅在 [hasInternalClutter] 时渲染；
/// - `>> 强制清除字体缓存` 仅在 [internalStats] 含 'Support' 且不含
///   '0 B' 时渲染（原 `_showStorageManager` 判定逐字保留）。
class SettingsStorageContent extends StatelessWidget {
  const SettingsStorageContent({
    super.key,
    required this.internalStats,
    required this.hasInternalClutter,
    required this.textColor,
    required this.infoBackgroundColor,
    required this.infoBorderColor,
    required this.infoDividerColor,
    required this.onCleanOrphanImages,
    required this.onCleanTemporaryCache,
    required this.onCleanInternalClutter,
    required this.onCleanFontCache,
  });

  /// 系统运行数据占用文案（原 `_internalStats`，如 "Doc: X / Support: Y"）。
  final String internalStats;

  /// 是否发现内部残留数据（原 `_hasInternalClutter`）。
  final bool hasInternalClutter;

  /// 行内文字颜色（原 sheetTextColor）。
  final Color textColor;

  /// 运行数据卡片背景（原 sheetInfoBackgroundColor）。
  final Color infoBackgroundColor;

  /// 运行数据卡片边框（原 sheetInfoBorderColor）。
  final Color infoBorderColor;

  /// 运行数据卡片内分隔线（原 sheetInfoDividerColor）。
  final Color infoDividerColor;

  /// 清理无用图片。
  final VoidCallback onCleanOrphanImages;

  /// 立即清理缓存。
  final VoidCallback onCleanTemporaryCache;

  /// 清理内部残留数据（仅在发现残留时渲染入口）。
  final VoidCallback onCleanInternalClutter;

  /// 强制清除字体缓存（仅在 Support 占用非 0 时渲染入口）。
  final VoidCallback onCleanFontCache;

  @override
  Widget build(BuildContext context) {
    final bool showFontCacheEntry =
        internalStats.contains('Support') && !internalStats.contains('0 B');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 操作行与 settings_page 原 `_showStorageManager` 的 ListTile 逐字一致；
        // 透明 Material 仅避免 ListTile 处于带背景 DecoratedBox 内时触发断言。
        Material(
          color: Colors.transparent,
          child: ListTile(
            leading: Icon(Icons.delete_sweep, color: textColor),
            title: Text(
              '清理无用图片 (深度清理)',
              style: GoogleFonts.notoSerifSc(color: textColor),
            ),
            subtitle: Text(
              '扫描并删除未被任何随心记引用的冗余图片',
              style: GoogleFonts.notoSerifSc(
                color: textColor.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            onTap: onCleanOrphanImages,
          ),
        ),
        // 原分隔线：默认高度（不设 height，区别于 SettingsDivider 的 height:1）。
        Divider(color: textColor.withValues(alpha: 0.1)),
        Material(
          color: Colors.transparent,
          child: ListTile(
            leading: Icon(Icons.cleaning_services, color: textColor),
            title: Text(
              '立即清理缓存',
              style: GoogleFonts.notoSerifSc(color: textColor),
            ),
            subtitle: Text(
              '清理产生的临时文件 (不影响数据)',
              style: GoogleFonts.notoSerifSc(
                color: textColor.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            onTap: onCleanTemporaryCache,
          ),
        ),
        const SizedBox(height: 10),
        _InternalStatsCard(
          internalStats: internalStats,
          hasInternalClutter: hasInternalClutter,
          showFontCacheEntry: showFontCacheEntry,
          textColor: textColor,
          backgroundColor: infoBackgroundColor,
          borderColor: infoBorderColor,
          dividerColor: infoDividerColor,
          onCleanInternalClutter: onCleanInternalClutter,
          onCleanFontCache: onCleanFontCache,
        ),
      ],
    );
  }
}

/// 系统运行数据卡片（原 `_showStorageManager` 内 Container 逐字）。
class _InternalStatsCard extends StatelessWidget {
  const _InternalStatsCard({
    required this.internalStats,
    required this.hasInternalClutter,
    required this.showFontCacheEntry,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.dividerColor,
    required this.onCleanInternalClutter,
    required this.onCleanFontCache,
  });

  final String internalStats;
  final bool hasInternalClutter;
  final bool showFontCacheEntry;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color dividerColor;
  final VoidCallback onCleanInternalClutter;
  final VoidCallback onCleanFontCache;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.perm_device_information,
                size: 16,
                color: textColor.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                '系统运行数据 (App必须)',
                style: GoogleFonts.notoSerifSc(
                  color: textColor.withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '包含字体缓存 (Support) 及 App 资源文件 (Doc)。\n此部分数据维持 App 正常运行，无需清理。',
            style: GoogleFonts.notoSerifSc(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: dividerColor, height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '占用空间: $internalStats',
                  style: GoogleFonts.notoSerifSc(
                    color: textColor.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          if (hasInternalClutter)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: onCleanInternalClutter,
                child: Text(
                  '>> 发现残留数据，点击清理',
                  style: GoogleFonts.notoSerifSc(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          if (showFontCacheEntry)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: onCleanFontCache,
                child: Text(
                  '>> 强制清除字体缓存 (修复显示异常)',
                  style: GoogleFonts.notoSerifSc(
                    color: Colors.orange[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
