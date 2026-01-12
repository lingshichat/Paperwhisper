import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

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
    final settings = Provider.of<SettingsProvider>(context);
    final isAmber = settings.currentTheme == 'amber_lens';
    
    // Config colors based on theme
    final containerColor = isAmber ? const Color(0xFF000000) : const Color(0xFFF4ECD8);
    final inputBgColor = isAmber ? const Color(0xFF2C2C2C) : Colors.white;
    final inputBorderColor = isAmber ? Colors.transparent : const Color(0xFFD7CCC8);
    final textColor = isAmber ? Colors.white : const Color(0xFF3E2723);
    final hintColor = isAmber ? Colors.grey : Colors.black26;
    final iconColor = isAmber ? const Color(0xFFFF9800) : const Color(0xFF5D4037);
    final sendColor = isAmber ? const Color(0xFFFF9800) : const Color(0xFF8D6E63);
    final imageIconColor = isAmber ?  Colors.grey : const Color(0xFF5D4037); // Image icon grey in dark mode

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: containerColor,
        boxShadow: isAmber ? [
           const BoxShadow(color: Colors.white10, offset: Offset(0, -1), blurRadius: 1)
        ] : [
           const BoxShadow(color: Colors.black12, offset: Offset(0, -2), blurRadius: 4)
        ]
      ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _controller,
                    maxLines: 4,
                    minLines: 1,
                    style: GoogleFonts.notoSerifSc(color: textColor),
                    cursorColor: isAmber ? const Color(0xFFFF9800) : null,
                    decoration: InputDecoration(
                      hintText: "写点什么...",
                      hintStyle: TextStyle(color: hintColor),
                      border: InputBorder.none,
                      isDense: true,
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
    );
  }
}
