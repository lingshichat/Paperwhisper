import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/skeuomorphic_dialog.dart';
import '../widgets/skeuomorphic_toast.dart';
import '../config/app_theme.dart';
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

  const MomentInputWidget({
    super.key,
    required this.onSend,
    this.focusNode,
    this.onHeightChanged,
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

  // Audio Recording State
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _audioPath;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;

  // Animation for Tape
  late AnimationController _tapeController;

  // Audio Preview
  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _isPreviewPlaying = false;

  // Audio Title
  final TextEditingController _audioTitleController = TextEditingController();

  // Global Key to preserve TextField state
  final GlobalKey _inputFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _audioTitleController.addListener(() {
      setState(() {});
    });

    _previewPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPreviewPlaying = state == PlayerState.playing);
      }
    });

    _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPreviewPlaying = false);
    });

    // Tape Animation (Infinite rotation when recording)
    _tapeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path =
            '${tempDir.path}/temp_record_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: path);

        _tapeController.repeat(); // Start Spinning

        setState(() {
          _isRecording = true;
          _recordDuration = Duration.zero;
        });

        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordDuration += const Duration(seconds: 1);
          });
        });
      } else {
        if (mounted) SkeuomorphicToast.error(context, '请授予麦克风权限');
      }
    } catch (e) {
      debugPrint("Start recording error: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _timer?.cancel();
      _tapeController.stop(); // Stop Spinning

      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
    } catch (e) {
      debugPrint("Stop recording error: $e");
    }
  }

  void _cancelRecording() async {
    // Stop without saving
    if (_isRecording) {
      await _audioRecorder.stop();
      _timer?.cancel();
      _tapeController.stop();
      setState(() {
        _isRecording = false;
        _recordDuration = Duration.zero;
      });
    }
  }

  void _deleteAudio() {
    setState(() {
      _audioPath = null;
      _audioTitleController.clear();
      _recordDuration = Duration.zero;
    });
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
        builder:
            (ctx) => SkeuomorphicDialog(
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
    if (_controller.text.trim().isEmpty &&
        _selectedImages.isEmpty &&
        _audioPath == null) {
      return;
    }

    String? finalAudioTitle = _audioTitleController.text.trim();
    // Logic: Default title if empty
    if (_audioPath != null && finalAudioTitle.isEmpty) {
      finalAudioTitle = "语音随记";
    }

    String content = _controller.text;
    // Logic: Default content if empty
    if (content.isEmpty && _audioPath != null) {
      content = finalAudioTitle;
    }

    widget.onSend(
      content,
      List.from(_selectedImages),
      audioPath: _audioPath,
      audioTitle: finalAudioTitle.isNotEmpty ? finalAudioTitle : null,
      audioDuration: _audioPath != null ? _recordDuration.inSeconds : null,
    );

    widget.focusNode?.unfocus();
    _controller.clear();
    _audioTitleController.clear();
    setState(() {
      _selectedImages.clear();
      _audioPath = null;
      _recordDuration = Duration.zero;
      _isPreviewPlaying = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioTitleController.dispose();
    _audioRecorder.dispose();
    _previewPlayer.dispose();
    _timer?.cancel();
    _tapeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final themeConfig = AppTheme.getMomentInputTheme(settings.currentTheme);
    final containerColor = themeConfig['containerColor'] as Color;
    final iconColor = themeConfig['iconColor'] as Color;
    final sendColor = themeConfig['sendColor'] as Color;
    final imageIconColor = themeConfig['imageIconColor'] as Color;
    final recordingColor = themeConfig['recordingColor'] as Color;
    final cancelColor = themeConfig['cancelColor'] as Color;
    final boxShadows = themeConfig['containerShadows'] as List<BoxShadow>;

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
                  child:
                      _isRecording
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
                          icon:
                              _isRecording
                                  ? Icons.stop_circle_outlined
                                  : Icons.mic_none,
                          iconColor: _isRecording ? recordingColor : iconColor,
                          size: _isRecording ? 28 : 24,
                          onTap:
                              _isRecording ? _stopRecording : _toggleRecording,
                        ),
                        const SizedBox(width: 8),
                        if (_isRecording)
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

  Widget _buildTextInputArea(Map<String, dynamic> themeConfig) {
    final bgColor = themeConfig['inputBgColor'] as Color;
    final borderColor = themeConfig['inputBorderColor'] as Color;
    final textColor = themeConfig['textColor'] as Color;
    final hintColor = themeConfig['hintColor'] as Color;
    final cursorColor = themeConfig['cursorColor'] as Color;
    final imageRemoveBgColor = themeConfig['imageRemoveBgColor'] as Color;
    final imageRemoveIconColor = themeConfig['imageRemoveIconColor'] as Color;

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
                        onTap:
                            () =>
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
              if (_audioPath != null) _buildMiniCassette(themeConfig),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCassetteDeck(Map<String, dynamic> themeConfig) {
    final deckColor = themeConfig['cassetteDeckColor'] as Color;
    final deckBorderColor = themeConfig['cassetteDeckBorderColor'] as Color;
    final deckShadows = themeConfig['cassetteDeckShadows'] as List<BoxShadow>;
    final labelColor = themeConfig['cassetteLabelColor'] as Color;
    final windowColor = themeConfig['cassetteWindowColor'] as Color;
    final windowBorderColor = themeConfig['cassetteWindowBorderColor'] as Color;
    final bridgeColor = themeConfig['cassetteBridgeColor'] as Color;
    final counterColor = themeConfig['cassetteCounterColor'] as Color;
    final screwColor = themeConfig['cassetteScrewColor'] as Color;
    String durationStr =
        "${_recordDuration.inMinutes.toString().padLeft(2, '0')}:${(_recordDuration.inSeconds % 60).toString().padLeft(2, '0')}";

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

  Widget _buildMiniCassette(Map<String, dynamic> themeConfig) {
    final miniBgColor = themeConfig['miniCassetteBgColor'] as Color;
    final miniPlayColor = themeConfig['miniCassettePlayColor'] as Color;
    final miniTextColor = themeConfig['miniCassetteTextColor'] as Color;
    final miniHintColor = themeConfig['miniCassetteHintColor'] as Color;
    final miniDeleteColor = themeConfig['miniCassetteDeleteColor'] as Color;

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
            onTap: () async {
              if (_audioPath == null) return;
              if (_isPreviewPlaying) {
                await _previewPlayer.pause();
              } else {
                await _previewPlayer.play(DeviceFileSource(_audioPath!));
              }
            },
            child: Icon(
              _isPreviewPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
              color: miniPlayColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _audioTitleController,
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
