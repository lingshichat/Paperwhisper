import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../features/export/data/export_path_resolver.dart';
import '../features/moments/application/moment_audio_controller.dart';
import 'dart:async';

import 'dart:io';
import 'package:provider/provider.dart';
import '../models/moment.dart';
import '../providers/settings_provider.dart';
import '../config/app_theme.dart';
import 'skeuomorphic_toast.dart';
import 'export_success_dialog.dart';
import 'skeuomorphic_dialog.dart';
import '../pages/moment_detail_page.dart';

class MomentCard extends StatefulWidget {
  final Moment moment;
  final Directory? baseDir;
  final VoidCallback? onTap;

  const MomentCard({
    super.key,
    required this.moment,
    this.baseDir,
    this.onTap,
    this.onDelete,
    this.controller,
  });

  final VoidCallback? onDelete;

  /// 音频控制器（测试注入用）。
  ///
  /// 不注入时生产代码按
  /// `moment.audioPath / baseDir.path / audioDuration` 自行创建并持有
  /// （owned）；注入时卡片只订阅状态流、不负责释放。
  final MomentAudioController? controller;

  @override
  State<MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<MomentCard> {
  final GlobalKey _globalKey = GlobalKey();
  bool _showWatermark = false;
  int _currentIndex = 0;

  // Audio Playback：状态与播放决策全部委托 MomentAudioController。
  MomentAudioController? _audioController;
  bool _ownsAudioController = false;
  StreamSubscription<MomentAudioState>? _audioStateSub;

  @override
  void initState() {
    super.initState();
    final injected = widget.controller;
    if (injected != null) {
      _audioController = injected;
    } else if (widget.moment.audioPath != null) {
      // 生产：按 moment.audioPath / baseDir.path / audioDuration 创建并持有。
      _audioController = MomentAudioController(
        audioPath: widget.moment.audioPath,
        baseDir: widget.baseDir?.path,
        initialDuration: widget.moment.audioDuration != null
            ? Duration(seconds: widget.moment.audioDuration!)
            : null,
      );
      _ownsAudioController = true;
    }
    final controller = _audioController;
    if (controller != null) {
      controller.initialize();
      _audioStateSub = controller.stateStream.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _audioStateSub?.cancel();
    // 只释放自建的控制器；注入的由测试/外部负责。
    if (_ownsAudioController) _audioController?.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    final controller = _audioController;
    if (controller == null) return;

    final result = await controller.toggle();
    switch (result) {
      case MomentAudioToggleMissing():
        if (mounted) SkeuomorphicToast.error(context, '音频文件丢失');
      case MomentAudioToggleFailure():
        // 记录此错误路径改进：网关异常不再成为 unhandled async error，
        // 统一翻译为用户可见反馈。
        if (mounted) SkeuomorphicToast.error(context, '音频播放失败');
      case MomentAudioToggleNoAudio():
      case MomentAudioToggleHandled():
        break;
    }
  }

  // ignore: unused_element
  Future<void> _captureAndSave() async {
    try {
      // 1. Show watermark
      setState(() => _showWatermark = true);
      // Wait for build
      await Future.delayed(const Duration(milliseconds: 50));

      RenderRepaintBoundary? boundary =
          _globalKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      var pngBytes = byteData!.buffer.asUint8List();

      // 导出目录委托 ExportPathResolver（平台/授权三分支，context-free）。
      final exportDir = await const ExportPathResolver().resolve();
      String exportPath = exportDir.path;

      if (!await exportDir.exists()) {
        try {
          await exportDir.create(recursive: true);
        } catch (e) {
          // Final fallback：mkdir 失败时回退到应用文档目录 Exports（原语义）
          final recoverDir = await getApplicationDocumentsDirectory();
          exportPath = path.join(recoverDir.path, 'Exports');
          await Directory(exportPath).create(recursive: true);
        }
      }

      String fileName = 'moment_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path.join(exportPath, fileName));
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        // Use new Dialog
        await showExportSuccessDialog(context, file.path);
      }
    } catch (e) {
      if (mounted) {
        SkeuomorphicToast.error(context, '保存失败: $e');
      }
    } finally {
      // 2. Hide watermark
      if (mounted) {
        setState(() => _showWatermark = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    showDialog(
      context: context,
      builder: (ctx) => SkeuomorphicDialog(
        title: '删除随心记',
        headerIcon: Icons.delete_forever,
        content: const Text(
          '确定要删除这条随心记吗？\n内容会先移入回收站，之后仍可恢复。',
          textAlign: TextAlign.center,
        ),
        actions: [
          SkeuomorphicDialogButton(
            label: '取消',
            isPrimary: false,
            onPressed: () => Navigator.pop(ctx),
          ),
          SkeuomorphicDialogButton(
            label: '移入回收站',
            isPrimary: true,
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onDelete != null) widget.onDelete!();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final themeConfig = AppTheme.getMomentCardTheme(settings.currentTheme);
    final cardBg = themeConfig['cardColor'] as Color;
    final textColor = themeConfig['textColor'] as Color;
    final metaColor = themeConfig['metaColor'] as Color;
    final deleteIconColor = themeConfig['deleteIconColor'] as Color;
    final cardShadows = themeConfig['cardShadows'] as List<BoxShadow>;
    final cardBorder = themeConfig['cardBorder'] as Border?;
    final useGlassEffect = themeConfig['useGlassEffect'] as bool;
    final cardBlurSigma = themeConfig['cardBlurSigma'] as double;
    final imageStackColor = themeConfig['imageStackColor'] as Color;
    final imageStackBorderColor = themeConfig['imageStackBorderColor'] as Color;
    final imageStackShadow = themeConfig['imageStackShadow'] as BoxShadow;
    final imageSurfaceColor = themeConfig['imageSurfaceColor'] as Color;
    final imageSurfaceShadow = themeConfig['imageSurfaceShadow'] as BoxShadow;
    final indicatorActiveColor = themeConfig['indicatorActiveColor'] as Color;
    final indicatorInactiveColor =
        themeConfig['indicatorInactiveColor'] as Color;
    final watermarkDividerColor = themeConfig['watermarkDividerColor'] as Color;

    final bool hasImage = widget.moment.images.isNotEmpty;
    final String heroTag = 'moment_${widget.moment.uuid}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        RepaintBoundary(
          key: _globalKey,
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  opaque: false,
                  pageBuilder: (_, _, _) => MomentDetailPage(
                    moment: widget.moment,
                    baseDir: widget.baseDir,
                    heroTag: heroTag,
                  ),
                  transitionsBuilder: (_, animation, _, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              );
            },
            child: Hero(
              tag: heroTag,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 6,
                  ), // Reduce vertical margin for list
                  decoration: BoxDecoration(
                    color: useGlassEffect ? Colors.transparent : cardBg,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: cardShadows,
                    border: cardBorder,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: useGlassEffect ? cardBlurSigma : 0.001,
                        sigmaY: useGlassEffect ? cardBlurSigma : 0.001,
                      ),
                      child: Container(
                        color: useGlassEffect ? cardBg : Colors.transparent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Text Content (Top)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text(
                                widget.moment.content,
                                style: GoogleFonts.notoSerifSc(
                                  fontSize: 16,
                                  color: textColor,
                                  height: 1.6,
                                ),
                              ),
                            ),

                            // 2. Audio Player (Middle)
                            if (widget.moment.audioPath != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: _buildSkeuomorphicPlayer(themeConfig),
                              ),

                            // 3. Image Section (Bottom)
                            if (hasImage)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  0,
                                ),
                                child: Column(
                                  children: [
                                    // Stack Effect + PageView
                                    SizedBox(
                                      height: 250, // Fixed height for carousel
                                      child: Stack(
                                        clipBehavior: Clip
                                            .none, // Allow stack effect to overflow slightly if needed
                                        alignment: Alignment.center,
                                        children: [
                                          // "Pile" Effect (Background Layers)
                                          if (widget.moment.images.length >
                                              1) ...[
                                            // Bottom Layer
                                            _buildImageStackLayer(
                                              angle: -0.05,
                                              color: imageStackColor,
                                              borderColor:
                                                  imageStackBorderColor,
                                              shadow: imageStackShadow,
                                            ),
                                            // Middle Layer
                                            _buildImageStackLayer(
                                              angle: 0.03,
                                              color: imageStackColor,
                                              borderColor:
                                                  imageStackBorderColor,
                                              shadow: imageStackShadow,
                                            ),
                                          ],

                                          // Main Carousel Layer
                                          Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: imageSurfaceColor,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              boxShadow: [
                                                if (widget
                                                        .moment
                                                        .images
                                                        .length >
                                                    1)
                                                  imageSurfaceShadow,
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              child: PageView.builder(
                                                itemCount:
                                                    widget.moment.images.length,
                                                onPageChanged: (index) {
                                                  setState(() {
                                                    _currentIndex = index;
                                                  });
                                                },
                                                itemBuilder: (context, index) {
                                                  return GestureDetector(
                                                    onTap: () {
                                                      // Pass specific image index if Detail Page supports it
                                                      // For now, standard open.
                                                      Navigator.of(
                                                        context,
                                                      ).push(
                                                        PageRouteBuilder(
                                                          opaque: false,
                                                          pageBuilder: (_, _, _) =>
                                                              MomentDetailPage(
                                                                moment: widget
                                                                    .moment,
                                                                baseDir: widget
                                                                    .baseDir,
                                                                heroTag:
                                                                    heroTag, // Note: Hero might be tricky with Carousel, might need unique tag per image
                                                                initialIndex:
                                                                    index, // TODO: Update MomentDetailPage to accept this
                                                              ),
                                                          transitionsBuilder:
                                                              (
                                                                _,
                                                                animation,
                                                                _,
                                                                child,
                                                              ) {
                                                                return FadeTransition(
                                                                  opacity:
                                                                      animation,
                                                                  child: child,
                                                                );
                                                              },
                                                        ),
                                                      );
                                                    },
                                                    child: _buildImage(
                                                      widget
                                                          .moment
                                                          .images[index],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Indicators
                                    if (widget.moment.images.length > 1)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: List.generate(
                                            widget.moment.images.length,
                                            (index) {
                                              bool isActive =
                                                  _currentIndex == index;
                                              return AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 3,
                                                    ),
                                                width: isActive ? 8 : 6,
                                                height: isActive ? 8 : 6,
                                                decoration: BoxDecoration(
                                                  color: isActive
                                                      ? indicatorActiveColor
                                                      : indicatorInactiveColor,
                                                  shape: BoxShape.circle,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                            // Metadata Footer
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Row(
                                children: [
                                  Text(
                                    _formatTime(widget.moment.createdAt),
                                    style: GoogleFonts.notoSerifSc(
                                      fontSize: 12,
                                      color: metaColor,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (widget.moment.weather != null)
                                    Text(
                                      '${widget.moment.weather!} ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: metaColor,
                                      ),
                                    ),
                                  if (widget.moment.mood != null)
                                    Text(
                                      widget.moment.mood!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: metaColor,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // 3. Watermark Footer (Only visible during export)
                            if (_showWatermark)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  bottom: 12,
                                ),
                                child: Column(
                                  children: [
                                    Divider(
                                      color: watermarkDividerColor,
                                      height: 20,
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Opacity(
                                          opacity: 0.6,
                                          child: Image.asset(
                                            'assets/icon.png',
                                            width: 14,
                                            height: 14,
                                            errorBuilder: (_, _, _) => Icon(
                                              Icons.edit,
                                              size: 14,
                                              color: metaColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "纸语 PaperWhisper",
                                          style: GoogleFonts.notoSerifSc(
                                            fontSize: 10,
                                            color: metaColor,
                                            letterSpacing: 1,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Actions Row (Outside RepaintBoundary)
        Padding(
          padding: const EdgeInsets.only(right: 24, bottom: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Delete
              if (widget.onDelete != null)
                InkWell(
                  onTap: _confirmDelete,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: deleteIconColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageStackLayer({
    required double angle,
    required Color color,
    required Color borderColor,
    required BoxShadow shadow,
  }) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: borderColor),
          boxShadow: [shadow],
        ),
      ),
    );
  }

  Widget _buildImage(String relativePath) {
    if (widget.baseDir == null) return const SizedBox();

    // Sanitize path for cross-platform (Windows might save with '\', Android needs '/')
    // Split by both separators and rejoin using local system separator
    List<String> parts = relativePath.split(RegExp(r'[/\\]'));
    String localPath = path.joinAll(parts);

    File file = File(path.join(widget.baseDir!.path, localPath));
    return Image.file(
      file,
      fit: BoxFit.cover,
      cacheHeight: 750, // Optimize for list view (250dp * 3.0 pixel ratio)
      errorBuilder: (_, _, _) => const SizedBox(),
    );
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildSkeuomorphicPlayer(Map<String, dynamic> themeConfig) {
    final textColor = themeConfig['textColor'] as Color;
    final audioSurfaceColor = themeConfig['audioSurfaceColor'] as Color;
    final audioSurfaceBorderColor =
        themeConfig['audioSurfaceBorderColor'] as Color;
    final audioButtonColor = themeConfig['audioButtonColor'] as Color;
    final audioButtonIconColor = themeConfig['audioButtonIconColor'] as Color;
    final audioButtonShadow = themeConfig['audioButtonShadow'] as BoxShadow;
    final audioProgressBgColor = themeConfig['audioProgressBgColor'] as Color;
    final audioProgressColor = themeConfig['audioProgressColor'] as Color;
    final audioDurationColor = themeConfig['audioDurationColor'] as Color;

    // 播放器 UI 严格读取控制器状态（时间/进度/按钮图标原样呈现）。
    final state = _audioController?.state ?? const MomentAudioState.idle();

    double progress = 0.0;
    if (state.duration.inMilliseconds > 0) {
      progress = state.position.inMilliseconds / state.duration.inMilliseconds;
      if (progress > 1.0) progress = 1.0;
    }

    return GestureDetector(
      onTap: _toggleAudio,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: audioSurfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: audioSurfaceBorderColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: audioButtonColor,
                boxShadow: [audioButtonShadow],
              ),
              child: Icon(
                state.isPlaying ? Icons.pause : Icons.play_arrow,
                color: audioButtonIconColor,
                size: 20,
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.moment.audioTitle ?? "语音记录",
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: audioProgressBgColor,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          audioProgressColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            Text(
              _formatDuration(
                state.isPlaying ? state.position : state.duration,
              ),
              style: GoogleFonts.roboto(
                color: audioDurationColor,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
