import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../models/moment.dart';
import '../providers/settings_provider.dart';
import '../config/app_theme.dart';

class MomentStandardCard extends StatelessWidget {
  final Moment moment;
  final Directory? baseDir;

  const MomentStandardCard({
    super.key,
    required this.moment,
    required this.baseDir,
  });

  @override
  Widget build(BuildContext context) {
    // For export, we might want to force a light theme or specific look?
    // User image shows a white card (Light theme style).
    // Let's use the current theme logic but ensure it looks good as a fallback.
    // Actually, export should probably respect the user's current theme OR be standard white.
    // The user uploaded a "White Card" style image.
    // Let's support dynamic theme but ensure high contrast.
    
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;
    final tc = AppTheme.getMomentStandardCardTheme(theme);

    final Color cardBg = tc['cardBg'] as Color;
    final Color textColor = tc['textColor'] as Color;
    final Color metaColor = tc['metaColor'] as Color;

    return Container(
      width: 400, // Fixed width for export consistency
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           // 1. Image Section
           if (moment.images.isNotEmpty)
             Container(
               padding: const EdgeInsets.only(left: 12, right: 12, top: 12),
               child: ClipRRect(
                 borderRadius: BorderRadius.circular(4),
                 child: AspectRatio(
                   aspectRatio: 16 / 9, // Or original ratio? 
                   // Current MomentCard uses constrainedBox maxheight 250.
                   // For export, full image is better.
                   child: _buildImage(moment.images.first),
                 ),
               ),
             ),
           
           // 2. Text & Metadata
           Padding(
             padding: const EdgeInsets.all(20),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 // Content
                 Text(
                   moment.content,
                   style: GoogleFonts.notoSerifSc(
                     fontSize: 18, // Slightly larger for export
                     color: textColor,
                     height: 1.6,
                   ),
                 ),
                 const SizedBox(height: 16),
                 // Metadata Row
                 Row(
                   children: [
                     Text(
                       _formatTime(moment.createdAt),
                       style: GoogleFonts.notoSerifSc(
                         fontSize: 14,
                         color: metaColor,
                       ),
                     ),
                     const Spacer(),
                     if (moment.weather != null) Text(moment.weather! + " ", style: TextStyle(fontSize: 14, color: metaColor)),
                     if (moment.mood != null) Text(moment.mood!, style: TextStyle(fontSize: 14, color: metaColor)),
                   ],
                 ),
               ],
             ),
           ),
           
           // 3. Watermark Footer (Always Visible)
           Padding(
             padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
             child: Column(
               children: [
                 Divider(color: Colors.black.withOpacity(0.05), height: 24),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Opacity(
                       opacity: 0.6,
                       child: Image.asset(
                         'assets/icon.png', 
                         width: 16, 
                         height: 16,
                         errorBuilder: (_,__,___) => Icon(Icons.edit, size: 16, color: metaColor),
                       ),
                     ),
                     const SizedBox(width: 8),
                     Text(
                       "纸语 PaperWhisper",
                       style: GoogleFonts.notoSerifSc(
                         fontSize: 12,
                         color: metaColor,
                         letterSpacing: 2,
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
    );
  }

  Widget _buildImage(String relativePath) {
    if (baseDir == null) return const SizedBox();
    List<String> parts = relativePath.split(RegExp(r'[/\\]'));
    String localPath = path.joinAll(parts);
    File file = File(path.join(baseDir!.path, localPath));
    return Image.file(file, fit: BoxFit.cover, errorBuilder: (_,__,___) => const SizedBox());
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
