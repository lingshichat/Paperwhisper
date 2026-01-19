import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/skeuomorphic_dialog.dart';
import '../widgets/skeuomorphic_toast.dart';
import '../config/app_theme.dart';

class MomentInputWidget extends StatefulWidget {
  final Function(String content, List<XFile> images, {String? audioPath, String? audioTitle}) onSend;
  final FocusNode? focusNode;

  const MomentInputWidget({
    super.key, 
    required this.onSend,
    this.focusNode,
  });

  @override
  State<MomentInputWidget> createState() => _MomentInputWidgetState();
}

class _MomentInputWidgetState extends State<MomentInputWidget> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  
  // Audio Recording State
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _audioPath; // Relative path or temp path? Temp path first.
  Duration _recordDuration = Duration.zero;
  Timer? _timer;
  
  // Audio Title
  final TextEditingController _audioTitleController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _audioTitleController.addListener(() {
      setState(() {});
    });
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
        final path = '${tempDir.path}/temp_record_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(const RecordConfig(), path: path);
        
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
        if(mounted) SkeuomorphicToast.error(context, '请授予麦克风权限');
      }
    } catch (e) {
      debugPrint("Start recording error: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _timer?.cancel();
      
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
    } catch (e) {
      debugPrint("Stop recording error: $e");
    }
  }
  
  void _cancelRecording() async {
    // Stop without saving (or delete immediately)
    if (_isRecording) {
        await _audioRecorder.stop();
        _timer?.cancel();
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
    
    // Check educational prompt (Same logic as EditorPage)
    bool webDavConfigured = syncProvider.isConfigured;
    bool hasShownPrompt = prefs.getBool('has_shown_compression_prompt') ?? false;

    if (webDavConfigured && !hasShownPrompt) {
       // Since this is a widget, we need to be careful with context. 
       // But it is Stateful, so context is available.
       bool? confirmCompression = await showDialog<bool>(
        context: context,
        builder: (ctx) => SkeuomorphicDialog(
          title: '图片上传设置',
          headerIcon: Icons.cloud_upload,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
               Text('检测到您已开启 WebDAV 同步。为节省您的云端流量，建议开启图片压缩。'),
               SizedBox(height: 10),
               Text('• 压缩模式 (推荐)：保留清晰度的同时大幅减小体积。', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
               Text('• 原图模式：占用大量空间和流量。', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
          actions: [
            SkeuomorphicDialogButton(label: '使用原图', isPrimary: false, onPressed: () => Navigator.pop(ctx, false)),
            SkeuomorphicDialogButton(label: '开启压缩', onPressed: () => Navigator.pop(ctx, true)),
          ],
        ),
      );
      
      if (confirmCompression != null) {
          final newConfig = syncProvider.config.copyWith(compressImages: confirmCompression);
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
    if (_controller.text.trim().isEmpty && _selectedImages.isEmpty && _audioPath == null) return;
    
    widget.onSend(
      _controller.text, 
      List.from(_selectedImages),
      audioPath: _audioPath,
      audioTitle: _audioTitleController.text.isNotEmpty ? _audioTitleController.text : null,
    );
    
    // Clear
    _controller.clear();
    _audioTitleController.clear();
    setState(() {
      _selectedImages.clear();
      _audioPath = null;
      _recordDuration = Duration.zero;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioTitleController.dispose();
    _audioRecorder.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get Theme
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;
    final bool isAmber = theme == AppTheme.themeAmberLens;
    final bool isSeaFlower = theme == AppTheme.themeSeaFlower;
    final bool isMidnight = theme == AppTheme.themeMidnight;
    
    // Config colors based on theme
    Color containerColor;
    Color inputBgColor;
    Color inputBorderColor;
    Color textColor;
    Color hintColor;
    Color iconColor;
    Color sendColor;
    Color imageIconColor;
    Color cursorColor;
    List<BoxShadow> boxShadows;

    if (isSeaFlower) {
       containerColor = const Color(0xFFFCE4EC); // Pink 50
       inputBgColor = Colors.white;
       inputBorderColor = const Color(0xFFF8BBD0);
       textColor = const Color(0xFF880E4F);
       hintColor = Colors.black26;
       iconColor = const Color(0xFFD81B60);
       sendColor = const Color(0xFFEC407A);
       imageIconColor = const Color(0xFFD81B60);
       cursorColor = const Color(0xFFD81B60);
       boxShadows = [const BoxShadow(color: Colors.black12, offset: Offset(0, -2), blurRadius: 4)];
    } else if (isMidnight) {
       containerColor = const Color(0xFF0D1117);
       inputBgColor = const Color(0xFF161b22);
       inputBorderColor = const Color(0xFF30363d);
       textColor = const Color(0xFFc9d1d9);
       hintColor = Colors.white24;
       iconColor = const Color(0xFF7986cb);
       sendColor = const Color(0xFF7986cb);
       imageIconColor = const Color(0xFF8b949e);
       cursorColor = const Color(0xFF7986cb);
       boxShadows = [const BoxShadow(color: Colors.black45, offset: Offset(0, -1), blurRadius: 4)];
    } else if (isAmber) {
       containerColor = const Color(0xFF000000);
       inputBgColor = const Color(0xFF2C2C2C);
       inputBorderColor = Colors.transparent;
       textColor = Colors.white;
       hintColor = Colors.grey;
       iconColor = const Color(0xFFFF9800);
       sendColor = const Color(0xFFFF9800);
       imageIconColor = Colors.grey;
       cursorColor = const Color(0xFFFF9800);
       boxShadows = [const BoxShadow(color: Colors.white10, offset: Offset(0, -1), blurRadius: 1)];
    } else {
       // Default (Vintage/Dark Brown)
       containerColor = const Color(0xFF2D1E1B); // Darker brown
       inputBgColor = const Color(0xFF3E2723); // Standard brown
       inputBorderColor = const Color(0xFF5D4037);
       textColor = const Color(0xFFD7CCC8); // Beige
       hintColor = const Color(0xFFA1887F);
       iconColor = const Color(0xFFD7CCC8);
       sendColor = Colors.white; // User requested White
       imageIconColor = const Color(0xFFA1887F);
       cursorColor = AppTheme.getAccentColor(theme);
       boxShadows = [const BoxShadow(color: Colors.black38, offset: Offset(0, -2), blurRadius: 4)];
    }

    return Container(
      decoration: BoxDecoration(
        color: containerColor,
        boxShadow: boxShadows,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                             fit: BoxFit.cover
                          )
                        ),
                      ),
                      Positioned(
                        right: 0, top: 0,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedImages.removeAt(index)),
                          child: const Icon(Icons.cancel, size: 18, color: Colors.grey),
                        ),
                      )
                    ],
                  );
                },
              ),
            ),
            
              Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Mic Button
              Container(
                margin: const EdgeInsets.only(bottom: 1), // Visual alignment correction
                child: IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(_isRecording ? Icons.mic_off : Icons.mic_none, color: _isRecording ? Colors.red : imageIconColor),
                onPressed: _isRecording ? _cancelRecording : _toggleRecording,
                tooltip: _isRecording ? '长按取消/点击停止' : '录音',
              ),
              ),
              
              const SizedBox(width: 4),

              // Image Button
              if (!_isRecording)
              Container(
                margin: const EdgeInsets.only(bottom: 1),
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.image_outlined, color: imageIconColor),
                  onPressed: _pickImages,
                ),
              ),
              if (!_isRecording) const SizedBox(width: 8),
              
              // Input Area or Recording Bar
              Expanded(
                child: _isRecording 
                  ? _buildRecordingBar(inputBgColor, textColor)
                  : Container(
                      decoration: BoxDecoration(
                        color: inputBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: inputBorderColor),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _controller,
                            focusNode: widget.focusNode,
                            maxLines: 4,
                            minLines: 1,
                            style: GoogleFonts.notoSerifSc(color: textColor),
                            cursorColor: cursorColor,
                            decoration: InputDecoration(
                              hintText: "写点什么...",
                              hintStyle: TextStyle(color: hintColor),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            ),
                          ),
                          if (_audioPath != null) _buildCassetteStub(textColor, iconColor, hintColor),
                        ],
                      ),
                    ),
              ),
              
              const SizedBox(width: 8),
              
              // Send Button (Paper Plane) or Stop Button
              if (_isRecording)
                 GestureDetector(
                   onTap: _stopRecording,
                   child: Container(
                     width: 40, height: 40,
                     alignment: Alignment.center,
                     margin: const EdgeInsets.only(bottom: 4),
                     decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.shade400,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0,2))]
                     ),
                     child: const Icon(Icons.stop, color: Colors.white, size: 20),
                   ),
                 )
              else
                Container(
                  margin: const EdgeInsets.only(bottom: 1),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.send, color: sendColor),
                    onPressed: _handleSend,
                  ),
                ),
            ],
          ),
        ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingBar(Color bgColor, Color textColor) {
    String durationStr = "${_recordDuration.inMinutes.toString().padLeft(2,'0')}:${(_recordDuration.inSeconds % 60).toString().padLeft(2,'0')}";
    
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.1), blurRadius: 8, spreadRadius: 1)]
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
           // Blinking Dot
           TweenAnimationBuilder<double>(
             tween: Tween(begin: 0.0, end: 1.0),
             duration: const Duration(seconds: 1),
             builder: (context, value, child) {
               return Opacity(
                 opacity: (value * 2).toInt() % 2 == 0 ? 1.0 : 0.3,
                 child: Container(
                   width: 10, height: 10,
                   decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                 ),
               );
             },
             onEnd: () {}, // Loop handled by parent rebuilds? No.
             // Simple blink implementation: based on duration odd/even
           ),
           const SizedBox(width: 12),
           Text(
             "正在录音  $durationStr",
             style: GoogleFonts.notoSerifSc(color: Colors.red.shade400, fontWeight: FontWeight.bold),
           ),
           const Spacer(),
           Text("点击右侧结束", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCassetteStub(Color textColor, Color accentColor, Color hintColor) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87, // Dark cassette plastic
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
           const BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4)
        ]
      ),
      child: Row(
        children: [
            // Cassette Spools visuals (Static for now)
            Container(
               width: 32, height: 20,
               decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: Colors.white24, width: 1),
               ),
               child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                     CircleAvatar(backgroundColor: Colors.white, radius: 4),
                     CircleAvatar(backgroundColor: Colors.white, radius: 4),
                  ],
               ),
            ),
            const SizedBox(width: 12),
            
            // Label Area (Editable Title)
            Expanded(
               child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                     color: const Color(0xFFF0F0F0), // White label paper
                     borderRadius: BorderRadius.circular(2),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.centerLeft,
                  child: TextField(
                     controller: _audioTitleController,
                     style: GoogleFonts.handlee(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
                     textAlignVertical: TextAlignVertical.center,
                     decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: "语音记录 ${_recordDuration.inSeconds}''",
                        hintStyle: GoogleFonts.handlee(color: Colors.black45),
                        contentPadding: EdgeInsets.zero,
                     ),
                  ),
               ),
            ),
            
            const SizedBox(width: 8),
            
            // Delete Button
            GestureDetector(
               onTap: _deleteAudio,
               child: const Icon(Icons.close, color: Colors.white54, size: 18),
            )
        ],
      ),
    );
  }
}

