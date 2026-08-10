import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:paper_whisper_flutter/features/sync/data/sync_config.dart';
import '../../../sync/presentation/sync_status_formatter.dart';

/// 同步设置页展示组件集合（纯展示，props 驱动）。
///
/// 职责边界：
/// - 颜色、文案、尺寸逐字保持 `sync_settings_page` 原 private helpers 行为；
/// - 不依赖 AppTheme dynamic Map，颜色由页面从主题配置取出后传入；
/// - 不持有 BuildContext 之外的异步/Provider 逻辑，回调全部由页面注入。

/// 分区标题：`_buildSectionTitle` 的提取。
class SyncSettingsSectionTitle extends StatelessWidget {
  const SyncSettingsSectionTitle({
    super.key,
    required this.title,
    required this.color,
  });

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.notoSerifSc(
        color: color,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/// 表单输入域：`_buildTextField` 的提取。
///
/// [borderColor] / [fillColor] 由页面从主题配置解析后传入
/// （原实现读取 `themeConfig['groupDecoration']`）。
class SyncSettingsTextField extends StatelessWidget {
  const SyncSettingsTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.textColor,
    required this.borderColor,
    required this.fillColor,
    this.obscureText = false,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color textColor;
  final Color borderColor;
  final Color? fillColor;
  final bool obscureText;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final hintColor = textColor.withValues(alpha: 0.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.notoSerifSc(
            color: textColor.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.fromBorderSide(BorderSide(color: borderColor)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            style: TextStyle(color: textColor),
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: hintColor, fontSize: 13),
              prefixIcon: Icon(
                icon,
                color: textColor.withValues(alpha: 0.6),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 主/次操作按钮：`_buildButton` 的提取。
///
/// 颜色按 [isPrimary] 分支读取对应 props，逐字保持原实现
/// （主按钮渐变 + 阴影，次按钮描边）。
class SyncSettingsActionButton extends StatelessWidget {
  const SyncSettingsActionButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.isPrimary,
    required this.primaryGradient,
    required this.primaryBtnColor,
    required this.primaryShadowColor,
    required this.secondaryBtnColor,
    required this.secondaryBtnTextColor,
    required this.secondaryBorderColor,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;
  final Gradient? primaryGradient;
  final Color? primaryBtnColor;
  final Color primaryShadowColor;
  final Color secondaryBtnColor;
  final Color secondaryBtnTextColor;
  final Color secondaryBorderColor;

  @override
  Widget build(BuildContext context) {
    final gradient = isPrimary ? primaryGradient : null;
    final color = isPrimary
        ? (primaryBtnColor ?? Colors.transparent)
        : secondaryBtnColor;
    final textColor = isPrimary ? Colors.white : secondaryBtnTextColor;
    final boxShadows = isPrimary
        ? [
            BoxShadow(
              color: primaryShadowColor,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ]
        : null;
    final border = !isPrimary ? Border.all(color: secondaryBorderColor) : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: gradient,
            color: color == Colors.transparent && gradient != null
                ? null
                : color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: boxShadows,
            border: border,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerifSc(
              color: onTap == null
                  ? textColor.withValues(alpha: 0.5)
                  : textColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

/// 信任状态卡：`_buildTrustStatusCard` 的提取。
///
/// 文案由页面通过 [SyncStatusFormatter] 生成 [SyncStatusCardText] 传入；
/// icon 与颜色由页面决定（icon 依赖信任状态映射，颜色来自主题 Map）。
class SyncTrustStatusCard extends StatelessWidget {
  const SyncTrustStatusCard({
    super.key,
    required this.cardText,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  final SyncStatusCardText cardText;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cardText.title,
                  style: GoogleFonts.notoSerifSc(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (cardText.lines.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...cardText.lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        line,
                        style: GoogleFonts.notoSerifSc(
                          color: textColor.withValues(alpha: 0.75),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 协议切换标签：`_buildSwitchLabel` 的提取（滑轨状态机留在页面）。
class SyncSettingsSwitchLabel extends StatelessWidget {
  const SyncSettingsSwitchLabel({
    super.key,
    required this.text,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final String text;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GoogleFonts.notoSerifSc(
              color: isActive ? activeColor : inactiveColor,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
            child: Text(text),
          ),
        ),
      ),
    );
  }
}

/// 小贴士卡片：`_buildTips` 的提取（WebDAV / S3 双分支文案为纯字符串选择）。
class SyncSettingsTips extends StatelessWidget {
  const SyncSettingsTips({
    super.key,
    required this.textColor,
    required this.backgroundColor,
    required this.syncType,
  });

  final Color textColor;
  final Color backgroundColor;
  final SyncType syncType;

  @override
  Widget build(BuildContext context) {
    final tips = syncType == SyncType.webdav
        ? '1. 推荐使用坚果云 WebDAV 服务。\n'
              '2. 坚果云服务器地址通常为：https://dav.jianguoyun.com/dav/ \n'
              '3. 密码必须使用坚果云生成的"第三方应用密码"，不可使用登录密码。\n'
              '4. 同步策略：本地和云端双向合并，默认保留最新的修改。'
        : '1. 支持 MinIO, AWS S3, 阿里云 OSS 等兼容 S3 的对象存储。\n'
              '2. Endpoint 为 API 域名 (例如 play.min.io)，Bucket 需提前创建。\n'
              '3. 请确保 Access Key 和 Secret Key 拥有该 Bucket 的读写权限。\n'
              '4. 开启"图片压缩"可显著节省存储空间和流量。';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: textColor.withValues(alpha: 0.8),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '小贴士',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tips,
            style: GoogleFonts.notoSerifSc(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
