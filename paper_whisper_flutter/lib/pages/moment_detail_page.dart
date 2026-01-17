import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/moment.dart';
import '../widgets/postmark_stamp.dart';
import '../config/app_theme.dart';
import '../providers/settings_provider.dart';
import '../widgets/skeuomorphic_toast.dart';
import '../widgets/export_success_dialog.dart';
import '../widgets/moment_standard_card.dart';
import '../widgets/skeuomorphic_dialog.dart';

class MomentDetailPage extends StatefulWidget {
  final Moment moment;
  final Directory? baseDir;
  final String heroTag;

  const MomentDetailPage({
    super.key,
    required this.moment,
    required this.baseDir,
    required this.heroTag,
    this.initialIndex = 0,
  });

  final int initialIndex;

  @override
  State<MomentDetailPage> createState() => _MomentDetailPageState();
}



class _MomentDetailPageState extends State<MomentDetailPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  final GlobalKey _frontKey = GlobalKey();
  final GlobalKey _backKey = GlobalKey();
  bool _isSaving = false;
  bool _isFront = true;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack), // Bouncy flip
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  Future<void> _captureAndSave() async {
    try {
      setState(() => _isSaving = true);
      await Future.delayed(const Duration(milliseconds: 50));

      // Save whichever side is currently "target" state (User might hit save mid-animation? Let's assume settiled)
      // If controller.value > 0.5, we are showing back.
      bool showBack = _controller.value >= 0.5;
      GlobalKey targetKey = showBack ? _backKey : _frontKey;

      RenderRepaintBoundary? boundary = targetKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      var pngBytes = byteData!.buffer.asUint8List();

      final directory = await getApplicationDocumentsDirectory();
      String exportPath;
      
      if (Platform.isAndroid) {
        if (await Permission.manageExternalStorage.isGranted) {
           // Change to standard Pictures directory for Gallery visibility
           exportPath = '/storage/emulated/0/Pictures/PaperWhisper';
        } else {
           // Fallback to app specific external dir or standard docs
           final extDir = await getExternalStorageDirectory();
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
      
      String prefix = showBack ? 'postcard' : 'polaroid';
      String fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path.join(exportPath, fileName));
      await file.writeAsBytes(pngBytes);
      
      if (mounted) {
         await showExportSuccessDialog(context, file.path);
      }
    } catch (e) {
      if (mounted) {
        SkeuomorphicToast.error(context, '保存失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Blur Background and Dismiss Area
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          
          // 2. Centered Flip Card
          Center(
             child: Hero(
              tag: widget.heroTag,
              flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
                return toHeroContext.widget;
              },
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: _toggleFlip, // Tap to flip
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      double value = _animation.value;
                      double angle = value * math.pi;
                      bool showFront = value < 0.5;

                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001) // Perspective
                          ..rotateY(angle),
                        child: showFront 
                          ? _buildFront()
                          : Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(math.pi), // Mirror back
                              child: _buildBack(),
                            ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // 3. Floating Save Button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _captureAndSave,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2), 
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSaving)
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      else
                        const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        // Dynamic Label based on state? Or generic?
                        "保存回忆",
                        style: GoogleFonts.notoSerifSc(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFront() {
    // Polaroid Style (Tilted originally, but inside flip maybe simpler?)
    // User wants tilt. Inside the flip transform, we can apply the Z-rotation (tilt).
    return SingleChildScrollView(
      child: Transform.rotate(
        angle: -3.14159 / 60, // -3 degrees tilt (Polaroid Look)
        child: RepaintBoundary(
          key: _frontKey,
          child: Container(
            margin: const EdgeInsets.all(32),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: const Color(0xFFFDFBF7), // Warm white paper
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 25,
                  offset: const Offset(5, 15),
                )
              ],
            ),
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 40), 
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.moment.images.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 1.0, 
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                         // Stack Effect (Background)
                         if (widget.moment.images.length > 1) ...[
                            Transform.rotate(
                              angle: -0.04,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(2,2))]
                                ),
                              ),
                            ),
                            Transform.rotate(
                              angle: 0.03,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset:const Offset(2,2))]
                                ),
                              ),
                            ),
                         ],
                         
                         // Carousel
                         PageView.builder(
                           controller: PageController(initialPage: widget.initialIndex),
                           itemCount: widget.moment.images.length,
                           onPageChanged: (index) {
                             setState(() => _currentIndex = index);
                           },
                           itemBuilder: (context, index) {
                             return Container(
                               color: Colors.grey[200],
                               child: _buildImage(widget.moment.images[index]),
                             );
                           },
                         ),

                         // Indicators (Inside Polaroid Image Area, bottom center)
                         if (widget.moment.images.length > 1)
                           Positioned(
                             bottom: 10,
                             left: 0,
                             right: 0,
                             child: Row(
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: List.generate(widget.moment.images.length, (idx) {
                                  bool active = idx == _currentIndex;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: active ? 8 : 6,
                                    height: active ? 8 : 6,
                                    decoration: BoxDecoration(
                                      color: active ? Colors.white : Colors.white.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)]
                                    ),
                                  );
                               }),
                             ),
                           )
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                CustomPaint(
                  painter: _PostcardLinePainter(
                    lineHeight: 36.0,
                    color: Colors.black.withOpacity(0.08),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      widget.moment.content,
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 16, 
                        color: const Color(0xFF333333), 
                        height: 2.25
                      ),
                      strutStyle: StrutStyle(
                        fontFamily: GoogleFonts.notoSerifSc().fontFamily,
                        fontSize: 16,
                        height: 2.25,
                        leading: 0,
                        forceStrutHeight: true,
                        leadingDistribution: TextLeadingDistribution.even,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (widget.moment.mood != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 15, right: 16),
                            child: Text(
                              widget.moment.mood!,
                              style: GoogleFonts.notoSerifSc(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ),
                        PostmarkStamp(date: widget.moment.createdAt, size: 80),
                      ],
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBack() {
    // Standard Card Style (Straight)
    return SingleChildScrollView(
      child: RepaintBoundary(
        key: _backKey,
        child: Container(
           margin: const EdgeInsets.all(32), // Match margin to keep size roughly similar
           child: MomentStandardCard(
             moment: widget.moment,
             baseDir: widget.baseDir,
           ),
        ),
      ),
    );
  }

  Widget _buildImage(String relativePath) {
    if (widget.baseDir == null) return const SizedBox();
    
    // Robust Path Handling
    String normalizedRelative = relativePath.replaceAll('\\', '/');
    List<String> parts = normalizedRelative.split('/');
    String localRelative = path.joinAll(parts);
    File file = File(path.join(widget.baseDir!.path, localRelative));

    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (_,__,___) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
    );
  }
}

class _PostcardLinePainter extends CustomPainter {
  final double lineHeight;
  final Color color;

  _PostcardLinePainter({required this.lineHeight, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (double y = lineHeight; y <= size.height + lineHeight; y += lineHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
