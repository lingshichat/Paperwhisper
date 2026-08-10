import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:paper_whisper_flutter/features/update/application/update_download_controller.dart';
import 'package:paper_whisper_flutter/features/update/data/update_info.dart';

/// 拟物化更新弹窗
/// 显示新版本信息，提供应用内下载、安装和备用下载选项
class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final String currentVersion;
  final VoidCallback? onLater;

  /// 下载控制器（测试可注入替身；生产由 State 自建，所有权单一）。
  final UpdateDownloadController? controller;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.currentVersion,
    this.onLater,
    this.controller,
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
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  /// 下载控制器：生产默认自建（所有权归 State），测试可注入替身。
  late final UpdateDownloadController _controller =
      widget.controller ?? UpdateDownloadController();

  @override
  void dispose() {
    // 组件销毁时取消正在进行的下载；仅释放自建控制器
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  /// 开始下载更新（委托控制器，UI 经 Listenable 消费状态）
  Future<void> _startDownload() => _controller.start(widget.updateInfo);

  /// 取消下载（状态回 idle 由 Dio cancel 回调驱动）
  void _cancelDownload() => _controller.cancel();

  /// 安装已下载的更新包
  Future<void> _installUpdate() => _controller.install();

  /// 备用下载：跳转浏览器（保持现有行为）
  Future<void> _fallbackDownload({bool useBackup = false}) async {
    await _controller.fallback(widget.updateInfo, useBackup: useBackup);
  }

  @override
  Widget build(BuildContext context) {
    final hasBackup = widget.updateInfo.hasBackupUrl(
      _controller.currentPlatform,
    );

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D4037).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.currentVersion} → ${widget.updateInfo.latestVersion}',
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF5D4037),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 更新日志
                if (widget.updateInfo.changelog.isNotEmpty) ...[
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
                        border: Border.all(color: const Color(0xFFD7CCC8)),
                      ),
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(
                          context,
                        ).copyWith(scrollbars: false),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: widget.updateInfo.changelog.map((item) {
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

                // 按钮区域：根据下载状态显示不同 UI
                // 剩余高度不足时按钮区整体可滚动，避免长 changelog + 高按钮区溢出
                Flexible(
                  child: SingleChildScrollView(
                    child: _buildActionArea(hasBackup),
                  ),
                ),
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

  /// 根据当前下载状态构建操作区域（订阅控制器状态快照）
  Widget _buildActionArea(bool hasBackup) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;
        switch (state.phase) {
          case UpdateDownloadPhase.idle:
            return _buildIdleActions(hasBackup);
          case UpdateDownloadPhase.downloading:
            return _buildDownloadingActions(state);
          case UpdateDownloadPhase.downloaded:
            return _buildDownloadedActions(state, hasBackup);
          case UpdateDownloadPhase.error:
            return _buildErrorActions(state, hasBackup);
        }
      },
    );
  }

  /// 初始状态：「立即更新」+「备用下载」+「暂不更新」
  Widget _buildIdleActions(bool hasBackup) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. 立即更新（应用内下载）
        SizedBox(
          width: double.infinity,
          child: _PrimaryButton(label: '立即更新', onPressed: _startDownload),
        ),

        // 2. 备用下载（跳转浏览器，保持现有行为）
        if (hasBackup) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _SecondaryButton(
              label: '备用下载',
              icon: Icons.cloud_outlined,
              onPressed: () => _fallbackDownload(useBackup: true),
            ),
          ),
        ],

        // 3. 暂不更新（非强制更新时显示）
        if (widget.onLater != null) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: widget.onLater,
            child: Text(
              '暂不更新',
              style: GoogleFonts.notoSerifSc(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF8D6E63).withValues(alpha: 0.8),
                decoration: TextDecoration.underline,
                decorationColor: const Color(0xFF8D6E63).withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  /// 下载中：进度条 + 百分比 + 「取消下载」
  Widget _buildDownloadingActions(UpdateDownloadState state) {
    // 计算下载百分比
    final double progress = state.progress;
    final String percentText = state.total > 0
        ? '${(progress * 100).toStringAsFixed(1)}%'
        : '正在连接...';
    final String sizeText = state.total > 0
        ? '${(state.received / 1024 / 1024).toStringAsFixed(1)} / ${(state.total / 1024 / 1024).toStringAsFixed(1)} MB'
        : '';
    final String statusText = _buildDownloadStatusText(progress, state.total);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '正在下载...',
              style: GoogleFonts.notoSerifSc(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF5D4037),
              ),
            ),
            Text(
              percentText,
              style: GoogleFonts.notoSerifSc(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF5D4037),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _DownloadProgressBar(progress: progress),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                sizeText.isNotEmpty ? sizeText : '正在连接更新源...',
                style: GoogleFonts.notoSerifSc(
                  fontSize: 11,
                  color: const Color(0xFF8D6E63),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              statusText,
              style: GoogleFonts.notoSerifSc(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF7A4B37),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 取消下载按钮
        SizedBox(
          width: double.infinity,
          child: _SecondaryButton(
            label: '取消下载',
            icon: Icons.close,
            onPressed: _cancelDownload,
          ),
        ),
      ],
    );
  }

  String _buildDownloadStatusText(double progress, int total) {
    if (total <= 0) {
      return '正在建立连接';
    }
    if (progress < 0.2) {
      return '正在接收文件';
    }
    if (progress < 0.7) {
      return '正在持续下载';
    }
    if (progress < 1) {
      return '即将完成';
    }
    return '准备安装';
  }

  /// 下载完成：「立即安装」+「备用下载」
  Widget _buildDownloadedActions(UpdateDownloadState state, bool hasBackup) {
    final String? installMessage = state.installMessage;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 完成提示
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 18,
              color: Color(0xFF2E7D32),
            ),
            const SizedBox(width: 6),
            Text(
              '下载完成',
              style: GoogleFonts.notoSerifSc(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (installMessage != null) ...[
          _buildMessageBox(
            message: installMessage,
            icon: Icons.info_outline,
            color: const Color(0xFFBF360C),
          ),
          const SizedBox(height: 16),
        ],

        // 立即安装
        SizedBox(
          width: double.infinity,
          child: _PrimaryButton(label: '立即安装', onPressed: _installUpdate),
        ),

        // 备用下载（始终可用作回退）
        if (hasBackup) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _SecondaryButton(
              label: '备用下载',
              icon: Icons.cloud_outlined,
              onPressed: () => _fallbackDownload(useBackup: true),
            ),
          ),
        ],
      ],
    );
  }

  /// 下载失败：错误信息 + 「重试」+「浏览器下载」
  Widget _buildErrorActions(UpdateDownloadState state, bool hasBackup) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 错误信息
        _buildMessageBox(
          message: state.error ?? '下载失败',
          icon: Icons.error_outline,
          color: const Color(0xFFBF360C),
        ),
        const SizedBox(height: 16),

        // 重试按钮
        SizedBox(
          width: double.infinity,
          child: _PrimaryButton(label: '重试', onPressed: _startDownload),
        ),
        const SizedBox(height: 12),

        // 浏览器下载（回退方案）
        SizedBox(
          width: double.infinity,
          child: _SecondaryButton(
            label: '浏览器下载',
            icon: Icons.open_in_browser,
            onPressed: () => _fallbackDownload(),
          ),
        ),

        // 备用下载
        if (hasBackup) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _SecondaryButton(
              label: '备用下载',
              icon: Icons.cloud_outlined,
              onPressed: () => _fallbackDownload(useBackup: true),
            ),
          ),
        ],
      ],
    );
  }

  /// 统一的提示信息样式
  Widget _buildMessageBox({
    required String message,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.notoSerifSc(
                fontSize: 12,
                color: color,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 普通横向下载进度条
/// 保留纸张质感，但视觉表达回归简单直接
class _DownloadProgressBar extends StatelessWidget {
  final double progress;

  const _DownloadProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final double clampedProgress = progress.clamp(0.0, 1.0);

    return Semantics(
      label: '下载进度 ${(clampedProgress * 100).toStringAsFixed(1)}%',
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE6D8C6), Color(0xFFD5C5B1)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFC8B79F)),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(93, 64, 55, 0.18),
              offset: Offset(0, 2),
              blurRadius: 5,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFFD8C8B3),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(255, 255, 255, 0.35),
                  offset: Offset(0, 1),
                  blurRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (clampedProgress > 0)
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: constraints.maxWidth * clampedProgress,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFFB87A5B),
                                      Color(0xFF7A4B37),
                                    ],
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color.fromRGBO(93, 64, 55, 0.2),
                                      offset: Offset(1, 0),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Container(
                                    height: 3,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      color: Colors.white.withValues(
                                        alpha: 0.22,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
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

/// 次要按钮（备用下载 / 取消等）
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
