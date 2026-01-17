import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
  });

  final VoidCallback? onDelete;

  @override
  State<MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<MomentCard> {
  final GlobalKey _globalKey = GlobalKey();
  bool _showWatermark = false;
  int _currentIndex = 0;

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
      String exportPath;
      
      bool usePublic = false;
      if (Platform.isAndroid) {
        if (await Permission.manageExternalStorage.isGranted) {
           usePublic = true;
           // Change to standard Pictures directory for Gallery visibility
           exportPath = '/storage/emulated/0/Pictures/PaperWhisper';
        } else {
           // Fallback to app specific external dir or standard docs
           final extDir = await getExternalStorageDirectory();
           // extDir is Android/data/.../files
           // Let's use a nice subfolder
           if (extDir != null) {
              exportPath = path.join(extDir.path, 'Exports');
           } else {
              exportPath = path.join(directory.path, 'Exports');
           }
        }
      } else {
        exportPath = path.join(directory.path, 'PaperWhisper_Exports');
      }
      
      final exportDir = Directory(exportPath);
      if (!await exportDir.exists()) {
        try {
          await exportDir.create(recursive: true);
        } catch (e) {
           // Final fallback
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
          '确定要删除这条随心记吗？\n删除后将无法恢复。',
          textAlign: TextAlign.center,
        ),
        actions: [
          SkeuomorphicDialogButton(
            label: '取消', 
            isPrimary: false, 
            onPressed: () => Navigator.pop(ctx)
          ),
          SkeuomorphicDialogButton(
            label: '删除', 
            isPrimary: true, 
            onPressed: () {
               Navigator.pop(ctx);
               if (widget.onDelete != null) widget.onDelete!();
            }
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;
    final bool isAmber = theme == AppTheme.themeAmberLens;
    final bool isSeaFlower = theme == AppTheme.themeSeaFlower;
    final bool isMidnight = theme == AppTheme.themeMidnight;

    // --- Dynamic Styles ---
    final Color cardBg = isAmber || isMidnight ? const Color(0xFF1E1E1E) : (isSeaFlower ? Colors.white.withOpacity(0.8) : Colors.white);
    final Color textColor = isAmber || isMidnight ? const Color(0xFFE0E0E0) : const Color(0xFF3E2723);
    final Color metaColor = isAmber ? const Color(0xFF9E9E9E) : Colors.grey[400]!;
    final Color iconColor = isAmber ? const Color(0xFFFF9800) : (isSeaFlower ? const Color(0xFFEC407A) : (isMidnight ? const Color(0xFF7986cb) : const Color(0xFF8D6E63)));
    
    final List<BoxShadow> shadows = isAmber 
      ? [
          const BoxShadow(color: Colors.black54, offset: Offset(0, 4), blurRadius: 8),
          const BoxShadow(color: Color(0x22FF9800), offset: Offset(0, 0), blurRadius: 10, spreadRadius: 1), // Amber Glow
        ] 
      : (isMidnight
         ? [
             const BoxShadow(color: Colors.black54, offset: Offset(0, 4), blurRadius: 8),
             const BoxShadow(color: Color(0x227986cb), offset: Offset(0, 0), blurRadius: 10, spreadRadius: 1), // Indigo Glow
           ]
         : [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              offset: const Offset(1, 2),
              blurRadius: 3,
            ),
         ]);

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
                   pageBuilder: (_, __, ___) => MomentDetailPage(
                     moment: widget.moment,
                     baseDir: widget.baseDir,
                     heroTag: heroTag,
                   ),
                   transitionsBuilder: (_, animation, __, child) {
                     return FadeTransition(opacity: animation, child: child);
                   }
                 )
               );
            },
            child: Hero(
              tag: heroTag,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6), // Reduce vertical margin for list
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(4), // Slightly rounded for paper feel
                boxShadow: shadows,
                border: isSeaFlower ? Border.all(color: Colors.white.withOpacity(0.4)): null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                   // 1. Image Section (Polaroid Style, truncated for feed?)
                   // Flomo shows full image usually.
// 1. Image Section (Polaroid Style / Carousel)
                   if (hasImage)
                     Padding(
                       padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                       child: Column(
                         children: [
                           // Stack Effect + PageView
                           SizedBox(
                             height: 250, // Fixed height for carousel
                             child: Stack(
                               clipBehavior: Clip.none, // Allow stack effect to overflow slightly if needed
                               alignment: Alignment.center,
                               children: [
                                 // "Pile" Effect (Background Layers)
                                 if (widget.moment.images.length > 1) ...[
                                   // Bottom Layer
                                   Transform.rotate(
                                     angle: -0.05,
                                     child: Container(
                                       margin: const EdgeInsets.symmetric(horizontal: 4),
                                       decoration: BoxDecoration(
                                         color: Colors.white,
                                         borderRadius: BorderRadius.circular(2),
                                         border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                         boxShadow: [
                                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(2, 4))
                                         ]
                                       ),
                                     ),
                                   ),
                                   // Middle Layer
                                   Transform.rotate(
                                     angle: 0.03,
                                     child: Container(
                                       margin: const EdgeInsets.symmetric(horizontal: 4),
                                       decoration: BoxDecoration(
                                         color: Colors.white,
                                          borderRadius: BorderRadius.circular(2),
                                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(2, 4))
                                          ]
                                       ),
                                     ),
                                   ),
                                 ],
                               
                                 // Main Carousel Layer
                                 Container(
                                   width: double.infinity,
                                   decoration: BoxDecoration(
                                     color: isAmber || isMidnight ? Colors.black12 : const Color(0xFFF5F5F5),
                                     borderRadius: BorderRadius.circular(2),
                                     boxShadow: [
                                       if (widget.moment.images.length > 1)
                                          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 5, offset: const Offset(0, 2))
                                     ]
                                   ),
                                   child: ClipRRect(
                                     borderRadius: BorderRadius.circular(2),
                                     child: PageView.builder(
                                       itemCount: widget.moment.images.length,
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
                                               Navigator.of(context).push(
                                                 PageRouteBuilder(
                                                   opaque: false, 
                                                   pageBuilder: (_, __, ___) => MomentDetailPage(
                                                     moment: widget.moment,
                                                     baseDir: widget.baseDir,
                                                     heroTag: heroTag, // Note: Hero might be tricky with Carousel, might need unique tag per image
                                                     initialIndex: index, // TODO: Update MomentDetailPage to accept this
                                                   ),
                                                   transitionsBuilder: (_, animation, __, child) {
                                                     return FadeTransition(opacity: animation, child: child);
                                                   }
                                                 )
                                               );
                                            },
                                            child: _buildImage(widget.moment.images[index]),
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
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: List.generate(widget.moment.images.length, (index) {
                                   bool isActive = _currentIndex == index;
                                   return AnimatedContainer(
                                     duration: const Duration(milliseconds: 300),
                                     margin: const EdgeInsets.symmetric(horizontal: 3),
                                     width: isActive ? 8 : 6,
                                     height: isActive ? 8 : 6,
                                     decoration: BoxDecoration(
                                       color: isActive 
                                         ? (isAmber ? Colors.orange : (isSeaFlower ? Colors.pinkAccent : const Color(0xFF8D6E63))) 
                                         : Colors.grey.withOpacity(0.4),
                                       shape: BoxShape.circle,
                                     ),
                                   );
                                 }),
                               ),
                             ),
                         ],
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
                             color: textColor,
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
                                 color: metaColor,
                               ),
                             ),
                             const Spacer(),
                             if (widget.moment.weather != null) Text(widget.moment.weather! + " ", style: TextStyle(fontSize: 12, color: metaColor)),
                             if (widget.moment.mood != null) Text(widget.moment.mood!, style: TextStyle(fontSize: 12, color: metaColor)),
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
                         Divider(color: isAmber || isMidnight ? Colors.white10 : Colors.black.withOpacity(0.05), height: 20),
                         Row(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             Opacity(
                               opacity: 0.6,
                               child: Image.asset(
                                 'assets/icon.png', 
                                 width: 14, 
                                 height: 14,
                                 errorBuilder: (_,__,___) => Icon(Icons.edit, size: 14, color: metaColor),
                               ),
                             ),
                             const SizedBox(width: 6),
                             Text(
                               "纸语 PaperWhisper",
                               style: GoogleFonts.notoSerifSc(
                                 fontSize: 10,
                                 color: metaColor,
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
        ),
      ),
        
        // Actions Row (Outside RepaintBoundary)
        Padding(
          padding: const EdgeInsets.only(right: 24, bottom: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
               // Delete (Only delete remains)
               if (widget.onDelete != null)
                 InkWell(
                  onTap: _confirmDelete,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(Icons.delete_outline, size: 18, color: iconColor.withOpacity(0.7)),
                  ),
                 ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildImage(String relativePath) {
    if (widget.baseDir == null) return const SizedBox();
    
    // Sanitize path for cross-platform (Windows might save with '\', Android needs '/')
    // Split by both separators and rejoin using local system separator
    List<String> parts = relativePath.split(RegExp(r'[/\\]'));
    String localPath = path.joinAll(parts);
    
    File file = File(path.join(widget.baseDir!.path, localPath));
    return Image.file(file, fit: BoxFit.cover, errorBuilder: (_,__,___) => const SizedBox());
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
