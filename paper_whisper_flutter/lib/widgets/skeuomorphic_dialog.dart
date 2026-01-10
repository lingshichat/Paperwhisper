import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SkeuomorphicDialog extends StatelessWidget {
  final String title;
  final Widget? content;
  final List<Widget>? actions;
  final Color paperColor;
  final bool showTape;
  final IconData? headerIcon;
  final Color? headerIconColor;

  const SkeuomorphicDialog({
    super.key,
    required this.title,
    this.content,
    this.actions,
    this.paperColor = const Color(0xFFF4ECD8), // Vintage paper default
    this.showTape = true,
    this.headerIcon,
    this.headerIconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 1. Paper Background (Skeuomorphic)
          Container(
            width: 320,
            constraints: const BoxConstraints(maxHeight: 500), // Limit height
            padding: const EdgeInsets.fromLTRB(30, 40, 30, 30),
            decoration: BoxDecoration(
              color: paperColor,
              borderRadius: BorderRadius.circular(2),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.4),
                  offset: Offset(0, 10),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Icon (Optional)
                if (headerIcon != null) ...[
                  Icon(headerIcon, size: 48, color: headerIconColor ?? const Color(0xFF5D4037)),
                  const SizedBox(height: 20),
                ],

                // Title
                Text(
                  title,
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2d241f),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                // Content
                if (content != null) ...[
                  const SizedBox(height: 15),
                  Flexible(
                    child: SingleChildScrollView(
                      child: content!,
                    ),
                  ),
                ],

                // Actions
                if (actions != null && actions!.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  Row(
                    children: actions!.map((action) {
                      // If action is Expanded, keep it, else wrap in Expanded if needed or flexible
                      // Ideally user passes Expanded widgets or we wrap them.
                      // Let's assume user passes buttons, we wrap them in Expanded for equal width 
                      // if there are multiple, or just put them in a row.
                      // For a generic dialog, Row is risky if widgets are wide. 
                      // Let's let the user handle Expanded if they want, OR enforce standardized buttons.
                      // Implementation decision: Direct mapping. User lays out complex actions if needed.
                      // BUT for this specific "Dialog" feel, usually evenly spaced buttons.
                      return Expanded(child: action);
                    }).expand((widget) => [widget, const SizedBox(width: 10)]).take(actions!.length * 2 - 1).toList(),
                  ),
                ],
              ],
            ),
          ),
          
          // 2. Paper Texture / Tape (Optional decoration)
          if (showTape)
            Positioned(
              top: -15,
              child: Container(
                transform: Matrix4.rotationZ(-0.05),
                width: 120,
                height: 35,
                decoration: const BoxDecoration(
                  color: Color(0xD9E0E0E0), // Semi-transparent tape
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.1),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Helper for standard primary button in dialog
class SkeuomorphicDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const SkeuomorphicDialogButton({
    super.key, 
    required this.label, 
    required this.onPressed,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPrimary) {
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF8D6E63),
        ),
        child: Text(
          label,
          style: GoogleFonts.notoSerifSc(fontWeight: FontWeight.bold),
        ),
      );
    }

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF5D4037),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(93, 64, 55, 0.4),
              offset: Offset(0, 4),
              blurRadius: 8,
            )
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.notoSerifSc(
            color: const Color(0xFFF4ECD8),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
