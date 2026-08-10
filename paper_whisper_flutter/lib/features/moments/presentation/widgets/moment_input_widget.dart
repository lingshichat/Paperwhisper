import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:paper_whisper_flutter/core/theme/components/moment_input_theme_data.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/moments/application/moment_recorder_controller.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_provider.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_dialog.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_toast.dart';
import 'cassette_wheel.dart';

class MomentInputWidget extends StatefulWidget {
  final Function(
    String content,
    List<XFile> images, {
    String? audioPath,
    String? audioTitle,
    int? audioDuration,
  })
  onSend;
  final FocusNode? focusNode;

  /// 可选注入的录音控制器（测试 seam）。生产不传，页面自建并持有；
  /// 注入时页面只订阅状态流与标题监听、不负责释放。
  final MomentRecorderController? recorder;

  const MomentInputWidget({
    super.key,
    required this.onSend,
    this.focusNode,
    this.onHeightChanged,
    this.recorder,
  });

  final ValueChanged<double>? onHeightChanged;

  @override
  State<MomentInputWidget> createState() => _MomentInputWidgetState();
}

class _MomentInputWidgetState extends State<MomentInputWidget>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  // 录音/预览：状态与动作全部委托 MomentRecorderController（context-free）。
  // 生产自建（owned，dispose 释放）；测试可注入（页面不释放）。
  late final MomentRecorderController _recorder;
  late final bool _ownsRecorder;
  StreamSubscription<MomentRecorderState>? _recorderStateSub;
  bool _wasRecording = false;

  // Animation for Tape
  late AnimationController _tapeController;

  // Global Key to preserve TextField state
  final GlobalKey _inputFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final injected = widget.recorder;
    if (injected != null) {
      _recorder = injected;
      _ownsRecorder = false;
    } else {
      _recorder = MomentRecorderController();
      _ownsRecorder = true;
    }
    _recorder.initialize();
    _recorder.audioTitleController.addListener(_onAudioTitleChanged);
    _recorderStateSub = _recorder.stateStream.listen(_onRecorderState);

    // Tape Animation (Infinite rotation when recording)
    _tapeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  /// 标题输入变化 → 刷新（原 `_audioTitleController.addListener`）。
  void _onAudioTitleChanged() {
    if (mounted) setState(() {});
  }

  /// 录音状态流 → 磁带旋转随录制状态启停 + 刷新（原 Timer/预览订阅
  /// 的 setState 汇总点）。
  void _onRecorderState(MomentRecorderState state) {
    if (!mounted) return;
    if (state.isRecording != _wasRecording) {
      if (state.isRecording) {
        _tapeController.repeat(); // Start Spinning
      } else {
        _tapeController.stop(); // Stop Spinning
      }
      _wasRecording = state.isRecording;
    }
    setState(() {});
  }

  Future<void> _toggleRecording() async {
    if (_recorder.state.isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final result = await _recorder.start();
    switch (result) {
      case MomentRecorderPermissionDenied():
        if (mounted) SkeuomorphicToast.error(context, '请授予麦克风权限');
      case MomentRecorderFailure():
        // 控制器已 debugPrint；UI 不新增文案（与原 catch 分支一致）。
        break;
      case MomentRecorderHandled():
        break; // 录制状态经 stateStream 刷新
    }
  }

  Future<void> _stopRecording() async {
    await _recorder.stop();
  }

  void _cancelRecording() async {
    await _recorder.cancel();
  }

  void _deleteAudio() {
    _recorder.deleteAudio(); // 清空经 stateStream 刷新
  }

  Future<void> _togglePreview() async {
    final result = await _recorder.togglePreview();
    switch (result) {
      case MomentRecorderPermissionDenied():
        if (mounted) SkeuomorphicToast.error(context, '请授予麦克风权限');
      case MomentRecorderFailure():
        break; // 控制器已 debugPrint；UI 不新增文案
      case MomentRecorderHandled():
        break; // 预览状态经 stateStream 刷新
    }
  }

  void _pickImages() async {
    final syncProvider = context.read<SyncProvider>();
    final prefs = await SharedPreferences.getInstance();

    // Check educational prompt logic...
    bool webDavConfigured = syncProvider.isConfigured;
    bool hasShownPrompt =
        prefs.getBool('has_shown_compression_prompt') ?? false;

    if (!mounted) return;

    if (webDavConfigured && !hasShownPrompt) {
      bool? confirmCompression = await showDialog<bool>(
        context: context,
        builder: (ctx) => SkeuomorphicDialog(
          title: '图片上传设置',
          headerIcon: Icons.cloud_upload,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [Text('检测到您已开启 WebDAV 同步。为节省您的云端流量，建议开启图片压缩。')],
          ),
          actions: [
            SkeuomorphicDialogButton(
              label: '使用原图',
              isPrimary: false,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            SkeuomorphicDialogButton(
              label: '开启压缩',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );

      if (confirmCompression != null) {
        final newConfig = syncProvider.config.copyWith(
          compressImages: confirmCompression,
        );
        await syncProvider.saveConfig(newConfig);
        await prefs.setBool('has_shown_compression_prompt', true);
      } else {
        return;
      }
    }

    bool compress = syncProvider.config.compressImages;
    final List<XFile> images = await _picker.pickMultiImage(
      maxWidth: compress ? 1920 : null,
      imageQuality: compress ? 80 : null,
    );

    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  void _handleSend() {
    final state = _recorder.state;
    if (_controller.text.trim().isEmpty &&
        _selectedImages.isEmpty &&
        state.audioPath == null) {
      return;
    }

    String? finalAudioTitle = _recorder.audioTitleController.text.trim();
    // Logic: Default title if empty
    if (state.audioPath != null && finalAudioTitle.isEmpty) {
      finalAudioTitle = "语音随记";
    }

    String content = _controller.text;
    // Logic: Default content if empty
    if (content.isEmpty && state.audioPath != null) {
      content = finalAudioTitle;
    }

    widget.onSend(
      content,
      List.from(_selectedImages),
      audioPath: state.audioPath,
      audioTitle: finalAudioTitle.isNotEmpty ? finalAudioTitle : null,
      audioDuration: state.audioPath != null
          ? state.recordDuration.inSeconds
          : null,
    );

    widget.focusNode?.unfocus();
    _controller.clear();
    // 复刻原清理段：标题/路径/时长/预览标记（含"语音随记"默认标题）。
    _recorder.clearAfterSend();
    setState(() {
      _selectedImages.clear();
    });
  }

  @override
  void dispose() {
    _recorderStateSub?.cancel();
    _recorder.audioTitleController.removeListener(_onAudioTitleChanged);
    // 只释放自建的控制器；注入的由测试/外部负责。
    if (_ownsRecorder) _recorder.dispose();
    _controller.dispose();
    _tapeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final themeConfig = ThemeRegistry.get(settings.currentTheme).momentInput;
    final containerColor = themeConfig.containerColor;
    final iconColor = themeConfig.iconColor;
    final sendColor = themeConfig.sendColor;
    final imageIconColor = themeConfig.imageIconColor;
    final recordingColor = themeConfig.recordingColor;
    final cancelColor = themeConfig.cancelColor;
    final boxShadows = themeConfig.containerShadows;
    final isRecording = _recorder.state.isRecording;

    return Container(
      decoration: BoxDecoration(
        color: containerColor,
        boxShadow: boxShadows,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ), // Card Shape
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SafeArea(
        top: false,
        child: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (widget.onHeightChanged != null) {
                final renderBox = context.findRenderObject() as RenderBox?;
                if (renderBox != null) {
                  widget.onHeightChanged!(
                    renderBox.size.height + 20,
                  ); // Add some buffer for shadow/margin
                }
              }
            });
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Content Area (Text or Cassette)
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: isRecording
                      ? _buildCassetteDeck(themeConfig)
                      : _buildTextInputArea(themeConfig),
                ),

                const SizedBox(height: 12),

                // 2. Toolbar Area
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildToolButton(
                          icon: isRecording
                              ? Icons.stop_circle_outlined
                              : Icons.mic_none,
                          iconColor: isRecording ? recordingColor : iconColor,
                          size: isRecording ? 28 : 24,
                          onTap: isRecording
                              ? _stopRecording
                              : _toggleRecording,
                        ),
                        const SizedBox(width: 8),
                        if (isRecording)
                          _buildTextToolButton(
                            label: '取消',
                            textColor: cancelColor,
                            onTap: _cancelRecording,
                          )
                        else
                          _buildToolButton(
                            icon: Icons.image_outlined,
                            iconColor: imageIconColor,
                            onTap: _pickImages,
                          ),
                      ],
                    ),
                    _buildToolButton(
                      icon: Icons.send,
                      iconColor: sendColor,
                      size: 22,
                      onTap: _handleSend,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    double size = 24,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Icon(icon, color: iconColor, size: size),
      ),
    );
  }

  Widget _buildTextToolButton({
    required String label,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          label,
          style: GoogleFonts.notoSerifSc(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTextInputArea(MomentInputThemeData themeConfig) {
    final bgColor = themeConfig.inputBgColor;
    final borderColor = themeConfig.inputBorderColor;
    final textColor = themeConfig.textColor;
    final hintColor = themeConfig.hintColor;
    final cursorColor = themeConfig.cursorColor;
    final imageRemoveBgColor = themeConfig.imageRemoveBgColor;
    final imageRemoveIconColor = themeConfig.imageRemoveIconColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Image Preview
        if (_selectedImages.isNotEmpty)
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8, bottom: 8),
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(File(_selectedImages[index].path)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedImages.removeAt(index)),
                        child: Container(
                          decoration: BoxDecoration(
                            color: imageRemoveBgColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cancel,
                            size: 18,
                            color: imageRemoveIconColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

        // Text Field Container
        Container(
          key: _inputFieldKey,
          constraints: const BoxConstraints(
            minHeight: 0,
          ), // Remove fixed min height for compactness
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                focusNode: widget.focusNode,
                maxLines: 5, // Auto-grow up to 5 lines
                minLines: 1, // Start small, but container minHeight gives space
                style: GoogleFonts.notoSerifSc(
                  color: textColor,
                  fontSize: 16,
                  height: 1.5,
                ),
                cursorColor: cursorColor,
                decoration: InputDecoration(
                  hintText: "记录当下的想法...",
                  hintStyle: TextStyle(color: hintColor),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),

              // Audio Attachment View
              if (_recorder.state.audioPath != null)
                _buildMiniCassette(themeConfig),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCassetteDeck(MomentInputThemeData themeConfig) {
    final deckColor = themeConfig.cassetteDeckColor;
    final deckBorderColor = themeConfig.cassetteDeckBorderColor;
    final deckShadows = themeConfig.cassetteDeckShadows;
    final labelColor = themeConfig.cassetteLabelColor;
    final windowColor = themeConfig.cassetteWindowColor;
    final windowBorderColor = themeConfig.cassetteWindowBorderColor;
    final bridgeColor = themeConfig.cassetteBridgeColor;
    final counterColor = themeConfig.cassetteCounterColor;
    final screwColor = themeConfig.cassetteScrewColor;
    final recordDuration = _recorder.state.recordDuration;
    String durationStr =
        "${recordDuration.inMinutes.toString().padLeft(2, '0')}:${(recordDuration.inSeconds % 60).toString().padLeft(2, '0')}";

    // Compact, Centered Cassette
    return Center(
      child: Container(
        width: 280, // Fixed width for realism
        height: 90, // Compact height
        decoration: BoxDecoration(
          color: deckColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: deckBorderColor, width: 2),
          boxShadow: deckShadows,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Screw Holes
            Positioned(top: 0, left: 0, child: _buildScrew(screwColor)),
            Positioned(top: 0, right: 0, child: _buildScrew(screwColor)),
            Positioned(bottom: 0, left: 0, child: _buildScrew(screwColor)),
            Positioned(bottom: 0, right: 0, child: _buildScrew(screwColor)),

            // 2. Center Label Area
            Container(
              decoration: BoxDecoration(
                color: labelColor,
                borderRadius: BorderRadius.circular(4),
                image: const DecorationImage(
                  image: NetworkImage(
                    "https://www.transparenttextures.com/patterns/paper-fibers.png",
                  ), // Fallback/Texture
                  opacity: 0.1,
                  scale: 0.5,
                ),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 3. Trapezoidal/Rectangular Window
                  Container(
                    height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: windowColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: windowBorderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CassetteWheel(turns: _tapeController, size: 28),
                        Expanded(
                          child: Container(
                            height: 12,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: bridgeColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        CassetteWheel(turns: _tapeController, size: 28),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 4. Digital Counter (Anachronistic but cool) or Label
                  Text(
                    durationStr,
                    style: GoogleFonts.orbitron(
                      color: counterColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrew(Color color) {
    return Icon(Icons.add, size: 10, color: color);
  }

  Widget _buildMiniCassette(MomentInputThemeData themeConfig) {
    final miniBgColor = themeConfig.miniCassetteBgColor;
    final miniPlayColor = themeConfig.miniCassettePlayColor;
    final miniTextColor = themeConfig.miniCassetteTextColor;
    final miniHintColor = themeConfig.miniCassetteHintColor;
    final miniDeleteColor = themeConfig.miniCassetteDeleteColor;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: miniBgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePreview,
            child: Icon(
              _recorder.state.isPreviewPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
              color: miniPlayColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _recorder.audioTitleController,
              style: TextStyle(color: miniTextColor, fontSize: 13),
              decoration: InputDecoration(
                hintText: "音频标题...",
                hintStyle: TextStyle(color: miniHintColor),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          GestureDetector(
            onTap: _deleteAudio,
            child: Icon(Icons.close, color: miniDeleteColor, size: 16),
          ),
        ],
      ),
    );
  }
}
