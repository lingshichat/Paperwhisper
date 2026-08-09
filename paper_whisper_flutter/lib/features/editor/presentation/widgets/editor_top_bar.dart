import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../config/app_theme.dart';

/// 编辑器顶栏：返回 / 导出 / 删除 / 保存 / 编辑切换。
///
/// 纯展示组件（props 驱动）：接收当前主题、编辑态与动作回调，渲染顶栏
/// 视觉（含部分主题的毛玻璃效果）。返回确认、保存/删除/导出流程、Toast
/// 与 Navigator 均由页面装配，本组件不持有会话与业务编排。
class EditorTopBar extends StatelessWidget {
  /// 当前主题名（AppTheme 主题配置入口，决定顶栏配色与模糊效果）。
  final String theme;

  /// 是否处于编辑态（编辑态显示保存按钮，否则显示编辑入口）。
  final bool isEditing;

  /// 是否显示删除入口（已有日记且非编辑态）。
  final bool showDelete;

  /// 返回回调：由页面执行返回确认（_onWillPop）与 Navigator.pop。
  final VoidCallback onBack;

  /// 保存回调：由页面执行保存编排。
  final VoidCallback onSave;

  /// 删除回调：由页面执行删除确认与编排。
  final VoidCallback onDelete;

  /// 导出回调：由页面执行长图导出编排。
  final VoidCallback onExport;

  /// 进入编辑态回调。
  final VoidCallback onEditToggle;

  const EditorTopBar({
    super.key,
    required this.theme,
    required this.isEditing,
    required this.showDelete,
    required this.onBack,
    required this.onSave,
    required this.onDelete,
    required this.onExport,
    required this.onEditToggle,
  });

  @override
  Widget build(BuildContext context) {
    final tc = AppTheme.getEditorTheme(theme);

    final Color barBg = tc['appBarBg'];
    final Color iconColor = tc['iconColor'];
    final Border? border = tc['appBarBorder'];

    Widget barContent = Container(
      // 移除固定高度，改用最小高度约束+padding适配
      constraints: BoxConstraints(
        minHeight: kToolbarHeight + MediaQuery.of(context).padding.top,
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top > 0
            ? MediaQuery.of(context).padding.top
            : 24,
        left: 10,
        right: 20,
        bottom: 8, // 添加底部留白以保证美观
      ),
      decoration: BoxDecoration(color: barBg, border: border),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, color: iconColor, size: 18),
                  const SizedBox(width: 4),
                  Text('返回列表', style: TextStyle(color: iconColor)),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Action Buttons
          IconButton(
            icon: Icon(Icons.share_outlined, color: iconColor),
            onPressed: onExport,
            tooltip: '导出为图片',
          ),
          const SizedBox(width: 5),

          if (!isEditing && showDelete) ...[
            IconButton(
              icon: Icon(Icons.delete_outline, color: iconColor),
              onPressed: onDelete,
              tooltip: '撕毁',
            ),
            const SizedBox(width: 10),
          ],

          if (isEditing)
            GestureDetector(
              onTap: onSave,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: tc['saveButtonBg'],
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.3),
                      offset: const Offset(0, -1),
                      blurRadius: 0,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '✓',
                      style: TextStyle(
                        color: tc['saveButtonCheckColor'],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '完成',
                      style: TextStyle(
                        color: tc['saveButtonTextColor'],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.edit_outlined, color: iconColor),
              onPressed: onEditToggle,
              tooltip: '编辑',
            ),
        ],
      ),
    );

    // 部分主题需要模糊效果
    if (tc['applyBlur'] == true) {
      return ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: barContent,
        ),
      );
    }

    return barContent;
  }
}
