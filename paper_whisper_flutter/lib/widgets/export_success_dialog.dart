import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'skeuomorphic_dialog.dart';
import 'skeuomorphic_toast.dart';

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
              Navigator.pop(context); // Close dialog first
              
              try {
                final result = await OpenFilex.open(filePath);
                if (result.type != ResultType.done) {
                   if (context.mounted) {
                     SkeuomorphicToast.error(context, "无法打开文件: ${result.message}");
                   }
                }
              } catch (e) {
                 debugPrint("Error opening file: $e");
                 if (context.mounted) {
                   SkeuomorphicToast.error(context, "打开失败");
                 }
              }
            },
          ),
        ],
      );
    }
  );
}
