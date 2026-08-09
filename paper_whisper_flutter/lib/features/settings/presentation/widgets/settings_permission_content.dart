/// 设置页「应用权限管理」弹层内容（纯展示）。
///
/// 从 settings_page `_showPermissionManager` / `_buildPermissionRow` 提取：
/// - 输入 typed [PermissionSnapshot] 与颜色 props，请求通过
///   [onRequest] 回调上抛（页面负责 Toast / openAppSettings / 鸿蒙判定）；
/// - 不持有 BuildContext 跨 async，不 request / open settings / dialog；
/// - 权限行为 ListTile 结构，与 settings_page 原 `_buildPermissionRow`
///   逐字视觉等价；外层透明 Material 仅修 ListTile 的
///   "background color or ink splashes may be invisible" 断言；
/// - 行间分隔线复用 S2a [SettingsDivider]；状态文字 / 颜色 / 去授权
///   按钮样式与原文案逐字一致。
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../permissions/application/permission_coordinator.dart';
import '../../application/settings_permission_controller.dart';
import 'settings_primitives.dart';

/// 权限行静态描述（原文案逐字）。
class _PermissionSpec {
  const _PermissionSpec({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isCritical = false,
  });

  final SettingsPermissionKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isCritical;
}

const List<_PermissionSpec> _kPermissionSpecs = [
  _PermissionSpec(
    kind: SettingsPermissionKind.storage,
    title: '文件存储 (核心)',
    subtitle: '用于日记数据的读取与备份',
    icon: Icons.folder_copy_outlined,
    isCritical: true,
  ),
  _PermissionSpec(
    kind: SettingsPermissionKind.photos,
    title: '相册访问',
    subtitle: '用于在日记中插入图片',
    icon: Icons.photo_library_outlined,
  ),
  _PermissionSpec(
    kind: SettingsPermissionKind.notification,
    title: '通知提醒',
    subtitle: '显示数据同步进度与状态',
    icon: Icons.notifications_outlined,
  ),
];

/// 应用权限管理弹层内容：标题说明 + 3 权限行 + 状态文字 / 去授权按钮。
///
/// [snapshot] 三权限状态来自 typed [PermissionSnapshot]；行间分隔线颜色
/// 与文字颜色由页面注入，不依赖 AppTheme 动态 Map 强转。
class SettingsPermissionContent extends StatelessWidget {
  const SettingsPermissionContent({
    super.key,
    required this.snapshot,
    required this.textColor,
    required this.dividerColor,
    required this.onRequest,
  });

  /// 三权限状态快照（storage / photos / notification）。
  final PermissionSnapshot snapshot;

  /// 行内文字颜色（原 sheetTextColor）。
  final Color textColor;

  /// 行间分隔线颜色（原 sheetInfoDividerColor）。
  final Color dividerColor;

  /// 权限请求回调：由页面决定请求与结果反馈。
  final ValueChanged<SettingsPermissionKind> onRequest;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _kPermissionSpecs.length; i++) ...[
          if (i > 0) SettingsDivider(color: dividerColor),
          _PermissionRow(
            spec: _kPermissionSpecs[i],
            status: _statusOf(_kPermissionSpecs[i].kind),
            textColor: textColor,
            onRequest: () => onRequest(_kPermissionSpecs[i].kind),
          ),
        ],
      ],
    );
  }

  PermissionStatus _statusOf(SettingsPermissionKind kind) {
    switch (kind) {
      case SettingsPermissionKind.storage:
        return snapshot.storage;
      case SettingsPermissionKind.photos:
        return snapshot.photos;
      case SettingsPermissionKind.notification:
        return snapshot.notification;
    }
  }
}

/// 单权限行：图标 + 标题/说明 + 状态文字（已获取/部分允许）或去授权按钮。
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.spec,
    required this.status,
    required this.textColor,
    required this.onRequest,
  });

  final _PermissionSpec spec;
  final PermissionStatus status;
  final Color textColor;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final bool isGranted = status.isGranted;
    final bool isLimited = status.isLimited;

    final Color statusColor = isGranted
        ? Colors.green
        : (spec.isCritical ? Colors.red : Colors.orange.shade800);
    final String statusText = isGranted ? '已获取' : (isLimited ? '部分允许' : '未获取');

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(spec.icon, color: textColor, size: 20),
        ),
        title: Text(
          spec.title,
          style: GoogleFonts.notoSerifSc(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          spec.subtitle,
          style: GoogleFonts.notoSerifSc(
            color: textColor.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
        // 行体本身不可点：请求只通过 trailing 去授权按钮触发。
        trailing: isGranted
            ? Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              )
            : InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: onRequest,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '去授权',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
