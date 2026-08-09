import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/update_info.dart';
import '../../../../widgets/skeuomorphic_dialog.dart';

/// 日记列表统一更新/公告弹窗组件。
///
/// 从旧 `diary_list_page._showUnifiedDialog` 的 SkeuomorphicDialog 树逐字
/// 提取：标题、发布日期、changelog 行（公告行首 emoji 由 version.json
/// 自带，保留空串占位）、感谢文案与按钮顺序（开启体验 / 暂不更新 /
/// 备用下载 / 立即更新）均与旧实现一致。
///
/// 边界约定：`Navigator.pop` 属展示层留在组件内；打开下载链接等副作用
/// 由页面经 [onBackup] / [onUpdate] 回调注入（Wave C 前不直接持有
/// UpdateService）。force barrier 与 showDialog 生命周期由页面保留。
class DiaryUpdateDialog extends StatelessWidget {
  /// 更新/公告信息（title、changelog、releaseDate、force 等）。
  final UpdateInfo info;

  /// true 为版本变更公告，false 为发现新版本。
  final bool isAnnouncement;

  /// 副文本颜色，由页面从主题 Map 取色后传入。
  final Color secondaryColor;

  /// 当前平台是否有备用下载链接（页面决策后传入）。
  final bool hasBackup;

  /// 「备用下载」点击回调（打开备用链接）。
  final VoidCallback? onBackup;

  /// 「立即更新」点击回调（打开主下载链接）。
  final VoidCallback? onUpdate;

  const DiaryUpdateDialog({
    super.key,
    required this.info,
    required this.isAnnouncement,
    required this.secondaryColor,
    required this.hasBackup,
    this.onBackup,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return SkeuomorphicDialog(
      title: isAnnouncement
          ? (info.title ?? '版本更新 ${info.latestVersion}')
          : '发现新版本 ${info.latestVersion}',
      headerIcon: isAnnouncement ? Icons.auto_awesome : Icons.system_update,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (info.releaseDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '发布日期：${info.releaseDate}',
                style: GoogleFonts.notoSerifSc(
                  fontSize: 12,
                  color: secondaryColor,
                ),
              ),
            ),
          // Changelog List
          ...info.changelog.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 公告行首图标已由 version.json 自带 emoji，不再额外生成
                  Text(
                    '',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: secondaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 15,
                        height: 1.6,
                        // 颜色继承自 SkeuomorphicDialog 的 DefaultTextStyle
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isAnnouncement) ...[
            const SizedBox(height: 16),
            Text(
              "感谢您与纸语一同成长。",
              style: GoogleFonts.notoSerifSc(
                fontSize: 13,
                color: secondaryColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (isAnnouncement)
          SkeuomorphicDialogButton(
            label: '开启体验',
            isPrimary: true,
            onPressed: () => Navigator.pop(context),
          )
        else ...[
          if (!info.isForceUpdate)
            SkeuomorphicDialogButton(
              label: '暂不更新',
              isPrimary: false,
              onPressed: () => Navigator.pop(context),
            ),
          // 备用下载按钮
          if (hasBackup)
            SkeuomorphicDialogButton(
              label: '备用下载',
              isPrimary: false,
              onPressed: () {
                Navigator.pop(context);
                onBackup?.call();
              },
            ),
          SkeuomorphicDialogButton(
            label: '立即更新',
            isPrimary: true,
            onPressed: () {
              if (info.downloadUrl != null) {
                Navigator.pop(context);
                onUpdate?.call();
              }
            },
          ),
        ],
      ],
    );
  }
}
