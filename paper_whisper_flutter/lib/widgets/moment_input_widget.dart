import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../config/app_theme.dart';

class MomentInputWidget extends StatefulWidget {
  final Function(String content, List<XFile> images) onSend;

  const MomentInputWidget({super.key, required this.onSend});

  @override
  State<MomentInputWidget> createState() => _MomentInputWidgetState();
}

class _MomentInputWidgetState extends State<MomentInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  
  void _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  void _handleSend() {
    if (_controller.text.trim().isEmpty && _selectedImages.isEmpty) return;
    
    widget.onSend(_controller.text, List.from(_selectedImages));
    
    // Clear
    _controller.clear();
    setState(() {
      _selectedImages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get Theme
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
            
          // Input Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Image Button
              IconButton(
                icon: Icon(Icons.image_outlined, color: imageIconColor),
                onPressed: _pickImages,
              ),
              const SizedBox(width: 8),
              
              // Text Field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: inputBgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: inputBorderColor),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _controller,
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
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Send Button (Paper Plane)
              IconButton(
                icon: Icon(Icons.send, color: sendColor),
                onPressed: _handleSend,
              ),
            ],
          ),
        ],
          ),
        ),
      ),
    );
  }
}
