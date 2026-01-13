import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart'; // For Windows check
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'skeuomorphic_dialog.dart';

Future<void> showExportSuccessDialog(BuildContext context, String filePath) async {
  await showDialog(
    context: context,
    builder: (context) {
      return SkeuomorphicDialog(
        title: '导出成功',
        headerIcon: Icons.check_circle_outline,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('图片已保存至：', style: GoogleFonts.notoSerifSc(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(filePath, style: GoogleFonts.notoSerifSc(fontSize: 12, color: Colors.grey[700])),
            const SizedBox(height: 16),
            Text('您也可以在手机相册中也能直接查看到此图片。', style: GoogleFonts.notoSerifSc(fontSize: 13)),
          ],
        ),
        actions: [
          SkeuomorphicDialogButton(
            label: '我知道了',
            isPrimary: false,
            onPressed: () => Navigator.pop(context),
          ),
          SkeuomorphicDialogButton(
            label: '去查看',
            isPrimary: true,
            onPressed: () async {
              Navigator.pop(context);
              if (Platform.isAndroid) {
                 // Try to open directory or file
                 const intent = AndroidIntent(
                    action: 'android.intent.action.VIEW',
                     // Use specific mime type for image or defaults to file manager?
                     // VIEWing a folder is tricky. 
                     // Best attempt: Open generic file manager or gallery
                     type: 'image/*',
                     flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
                 );
                 try {
                   await intent.launch();
                 } catch (e) {
                   debugPrint("Error launching android intent: $e");
                 }
              } else if (Platform.isWindows) {
                 // Open explorer
                 final dir = Directory(filePath).parent.path;
                 Process.run('explorer', [dir]);
              }
            },
          ),
        ],
      );
    }
  );
}
