import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF4ECD8),
        boxShadow: [
          BoxShadow(color: Colors.black12, offset: Offset(0, -2), blurRadius: 4)
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
                icon: const Icon(Icons.image_outlined, color: Color(0xFF5D4037)),
                onPressed: _pickImages,
              ),
              const SizedBox(width: 8),
              
              // Text Field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFD7CCC8)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _controller,
                    maxLines: 4,
                    minLines: 1,
                    style: GoogleFonts.notoSerifSc(color: const Color(0xFF3E2723)),
                    decoration: const InputDecoration(
                      hintText: "写点什么...",
                      hintStyle: TextStyle(color: Colors.black26),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Send Button (Paper Plane)
              IconButton(
                icon: const Icon(Icons.send, color: Color(0xFF8D6E63)),
                onPressed: _handleSend,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
