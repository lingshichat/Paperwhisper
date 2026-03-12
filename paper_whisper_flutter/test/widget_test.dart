import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/models/update_info.dart';
import 'package:paper_whisper_flutter/widgets/update_dialog.dart';

void main() {
  testWidgets('UpdateDialog renders basic update info', (
    WidgetTester tester,
  ) async {
    final updateInfo = UpdateInfo(
      latestVersion: '1.2.0',
      changelog: ['新增应用内下载', '优化下载进度展示'],
      downloadUrl: {
        'android': 'https://example.com/app.apk',
        'windows': 'https://example.com/app.exe',
      },
      backupUrl: {
        'android': 'https://example.com/app-backup.apk',
        'windows': 'https://example.com/app-backup.exe',
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdateDialog(updateInfo: updateInfo, currentVersion: '1.1.0'),
        ),
      ),
    );

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('1.1.0 → 1.2.0'), findsOneWidget);
    expect(find.text('新增应用内下载'), findsOneWidget);
    expect(find.text('优化下载进度展示'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);
  });
}
