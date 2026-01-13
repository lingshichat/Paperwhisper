import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/update_info.dart';
import '../services/update_service.dart';

/// 拟物化更新弹窗
/// 显示新版本信息，提供主下载和备用下载选项
class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;
  final String currentVersion;
  final VoidCallback? onLater;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.currentVersion,
    this.onLater,
  });

  /// 显示更新弹窗
  static Future<void> show(
    BuildContext context, {
    required UpdateInfo updateInfo,
    required String currentVersion,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: !updateInfo.isForceUpdate,
      builder: (context) => UpdateDialog(
        updateInfo: updateInfo,
        currentVersion: currentVersion,
        onLater: updateInfo.isForceUpdate ? null : () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final updateService = UpdateService();
    final platform = updateService.currentPlatform;
    final hasBackup = updateInfo.hasBackupUrl(platform);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 纸张背景
          Container(
            width: 340,
            constraints: const BoxConstraints(maxHeight: 500),
            padding: const EdgeInsets.fromLTRB(28, 45, 28, 28),
            decoration: BoxDecoration(
              color: const Color(0xFFF4ECD8), // 复古纸张色
              borderRadius: BorderRadius.circular(3),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.4),
                  offset: Offset(0, 12),
                  blurRadius: 24,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题图标
                const Icon(
                  Icons.celebration_outlined,
                  size: 48,
                  color: Color(0xFFE65100),
                ),
                const SizedBox(height: 16),
                
                // 标题
                Text(
                  '发现新版本',
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2d241f),
                  ),
                ),
                const SizedBox(height: 8),
                
                // 版本号
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D4037).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$currentVersion → ${updateInfo.latestVersion}',
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF5D4037),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 更新日志
                if (updateInfo.changelog.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '更新内容',
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5D4037),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFD7CCC8),
                        ),
                      ),
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: updateInfo.changelog.map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  item,
                                  style: GoogleFonts.notoSerifSc(
                                    fontSize: 13,
                                    color: const Color(0xFF4E342E),
                                    height: 1.4,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // 按钮区域
                Row(
                  children: [
                    // 主下载按钮
                    Expanded(
                      child: _PrimaryButton(
                        label: '立即更新',
                        onPressed: () async {
                          await updateService.openDownloadUrl(updateInfo);
                        },
                      ),
                    ),
                    // 备用下载按钮（如果有）
                    if (hasBackup) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SecondaryButton(
                          label: '备用下载',
                          icon: Icons.cloud_outlined,
                          onPressed: () async {
                            await updateService.openDownloadUrl(updateInfo, useBackup: true);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                
                // 稍后更新按钮（非强制更新时显示）
                if (onLater != null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onLater,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF8D6E63),
                    ),
                    child: Text(
                      '稍后更新',
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 胶带装饰
          Positioned(
            top: -15,
            child: Transform.rotate(
              angle: -0.05,
              child: Container(
                width: 120,
                height: 35,
                decoration: BoxDecoration(
                  color: const Color(0xD9E0E0E0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 主要按钮
class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF5D4037),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(93, 64, 55, 0.4),
              offset: Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.notoSerifSc(
            color: const Color(0xFFF4ECD8),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

/// 次要按钮（备用下载）
class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF8D6E63)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF5D4037)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.notoSerifSc(
                color: const Color(0xFF5D4037),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
