import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'dart:io';
import '../models/moment.dart';

class MomentCard extends StatefulWidget {
  final Moment moment;
  final Directory? baseDir;
  final VoidCallback? onTap;

  const MomentCard({
    super.key,
    required this.moment,
    this.baseDir,
    this.onTap,
  });

  @override
  State<MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<MomentCard> {
  final GlobalKey _globalKey = GlobalKey();
  bool _showWatermark = false;

  Future<void> _captureAndSave() async {
    try {
      // 1. Show watermark
      setState(() => _showWatermark = true);
      // Wait for build
      await Future.delayed(const Duration(milliseconds: 50));

      RenderRepaintBoundary? boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      var pngBytes = byteData!.buffer.asUint8List();

      final directory = await getApplicationDocumentsDirectory(); 
      final exportDir = Directory(path.join(directory.path, 'PaperWhisper_Exports'));
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }
      
      String fileName = 'moment_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path.join(exportDir.path, fileName));
      await file.writeAsBytes(pngBytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已保存图片至: ${file.path}'),
            action: SnackBarAction(label: '打开文件夹', onPressed: () {
               if (Platform.isWindows) {
                 Process.run('explorer', [exportDir.path]);
               }
            }),
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      // 2. Hide watermark
      if (mounted) {
        setState(() => _showWatermark = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = widget.moment.images.isNotEmpty;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        RepaintBoundary(
          key: _globalKey,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6), // Reduce vertical margin for list
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4), // Slightly rounded for paper feel
                boxShadow: [
                   BoxShadow(
                     color: Colors.black.withOpacity(0.08),
                     offset: const Offset(1, 2),
                     blurRadius: 3,
                   ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                   // 1. Image Section (Polaroid Style, truncated for feed?)
                   // Flomo shows full image usually.
                   if (hasImage)
                     Container(
                       padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                       child: ConstrainedBox(
                         constraints: const BoxConstraints(maxHeight: 250), // Limit height
                         child: Container(
                           width: double.infinity,
                           color: const Color(0xFFF5F5F5),
                           child: ClipRRect(
                             borderRadius: BorderRadius.circular(2),
                             child: _buildImage(widget.moment.images.first)
                            ),
                         ),
                       ),
                     ),
                   
                   // 2. Text & Metadata
                   Padding(
                     padding: const EdgeInsets.all(16),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         // Content
                         Text(
                           widget.moment.content,
                           style: GoogleFonts.notoSerifSc( // Use Noto Serif as base, or Try 'Long Cang' if needed
                             fontSize: 16,
                             color: const Color(0xFF3E2723),
                             height: 1.6,
                           ),
                         ),
                         const SizedBox(height: 12),
                         // Metadata Row
                         Row(
                           children: [
                             Text(
                               _formatTime(widget.moment.createdAt),
                               style: GoogleFonts.notoSerifSc(
                                 fontSize: 12,
                                 color: Colors.grey[400],
                               ),
                             ),
                             const Spacer(),
                             if (widget.moment.weather != null) Text(widget.moment.weather! + " ", style: const TextStyle(fontSize: 12)),
                             if (widget.moment.mood != null) Text(widget.moment.mood!, style: const TextStyle(fontSize: 12)),
                           ],
                         ),
                       ],
                     ),
                   ),
                   // 3. Watermark Footer (Only visible during export)
                   if (_showWatermark)
                     Padding(
                       padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                       child: Column(
                       children: [
                         Divider(color: Colors.black.withOpacity(0.05), height: 20),
                         Row(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             Opacity(
                               opacity: 0.6,
                               child: Image.asset(
                                 'assets/icon.png', 
                                 width: 14, 
                                 height: 14,
                                 errorBuilder: (_,__,___) => const Icon(Icons.edit, size: 14, color: Colors.grey),
                               ),
                             ),
                             const SizedBox(width: 6),
                             Text(
                               "纸语 PaperWhisper",
                               style: GoogleFonts.notoSerifSc(
                                 fontSize: 10,
                                 color: Colors.grey[400],
                                 letterSpacing: 1,
                                 fontWeight: FontWeight.w500
                               ),
                             ),
                           ],
                         ),
                       ],
                     ),
                   )
                ],
              ),
            ),
          ),
        ),
        
        // Share Button (Outside RepaintBoundary)
        Padding(
          padding: const EdgeInsets.only(right: 24, bottom: 12),
          child: InkWell(
            onTap: _captureAndSave,
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.share_outlined, size: 18, color: Color(0xFF8D6E63)),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildImage(String relativePath) {
    if (widget.baseDir == null) return const SizedBox();
    File file = File(path.join(widget.baseDir!.path, relativePath));
    return Image.file(file, fit: BoxFit.cover, errorBuilder: (_,__,___) => const SizedBox());
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
