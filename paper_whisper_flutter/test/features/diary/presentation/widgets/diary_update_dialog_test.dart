import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/diary/presentation/widgets/diary_update_dialog.dart';
import 'package:paper_whisper_flutter/features/update/data/update_info.dart';
import 'package:paper_whisper_flutter/features/settings/application/settings_provider.dart';
import 'package:provider/provider.dart';

/// DiaryUpdateDialog 组件测试：公告/更新/强制/备用下载分支的文案、图标、
/// 按钮顺序与回调，以及 Android 360 视口无溢出。
///
/// 行为刻画契约取自旧 `diary_list_page._showUnifiedDialog` 的逐字实现：
/// 标题回退、发布日期、changelog 行、感谢文案、按钮顺序（暂不更新 →
/// 备用下载 → 立即更新）与 Navigator.pop 展示行为。打开链接等副作用
/// 由回调注入，本测试只断言回调触发与弹窗关闭。
void main() {
  setUpAll(() {
    ThemeRegistry.init();
  });

  const secondaryColor = Color(0xFF5D4037);

  UpdateInfo makeInfo({
    String latestVersion = '2.0.0',
    String? releaseDate = '2026-03-12',
    String? title,
    bool isForceUpdate = false,
    List<String> changelog = const ['第一项改进', '第二项修复'],
    Map<String, String>? downloadUrl = const {
      'android': 'https://example.com/app.apk',
    },
    Map<String, String>? backupUrl,
  }) {
    return UpdateInfo(
      latestVersion: latestVersion,
      releaseDate: releaseDate,
      title: title,
      isForceUpdate: isForceUpdate,
      changelog: changelog,
      downloadUrl: downloadUrl,
      backupUrl: backupUrl,
    );
  }

  /// 经真实 showDialog 弹出（组件内 Navigator.pop 依赖 DialogRoute）。
  Future<void> pumpDialog(
    WidgetTester tester,
    DiaryUpdateDialog dialog, {
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>(
            create: (_) => SettingsProvider(),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => dialog,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('DiaryUpdateDialog 公告分支', () {
    testWidgets('公告：标题/auto_awesome/发布日期/changelog/感谢文案/开启体验，无更新按钮', (
      tester,
    ) async {
      await pumpDialog(
        tester,
        DiaryUpdateDialog(
          info: makeInfo(title: '纸语 2.0 发布公告'),
          isAnnouncement: true,
          secondaryColor: secondaryColor,
          hasBackup: false,
        ),
      );

      expect(find.text('纸语 2.0 发布公告'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      expect(find.byIcon(Icons.system_update), findsNothing);
      expect(find.text('发布日期：2026-03-12'), findsOneWidget);
      expect(find.text('第一项改进'), findsOneWidget);
      expect(find.text('第二项修复'), findsOneWidget);
      expect(find.text('感谢您与纸语一同成长。'), findsOneWidget);
      expect(find.text('开启体验'), findsOneWidget);
      expect(find.text('暂不更新'), findsNothing);
      expect(find.text('备用下载'), findsNothing);
      expect(find.text('立即更新'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('公告无 title：标题回退「版本更新 X」', (tester) async {
      await pumpDialog(
        tester,
        DiaryUpdateDialog(
          info: makeInfo(title: null),
          isAnnouncement: true,
          secondaryColor: secondaryColor,
          hasBackup: false,
        ),
      );

      expect(find.text('版本更新 2.0.0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('DiaryUpdateDialog 更新分支', () {
    testWidgets('非强制更新：发现新版本 + 暂不更新/立即更新，无公告文案', (tester) async {
      await pumpDialog(
        tester,
        DiaryUpdateDialog(
          info: makeInfo(),
          isAnnouncement: false,
          secondaryColor: secondaryColor,
          hasBackup: false,
        ),
      );

      expect(find.text('发现新版本 2.0.0'), findsOneWidget);
      expect(find.byIcon(Icons.system_update), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
      expect(find.text('感谢您与纸语一同成长。'), findsNothing);
      expect(find.text('开启体验'), findsNothing);
      expect(find.text('暂不更新'), findsOneWidget);
      expect(find.text('备用下载'), findsNothing);
      expect(find.text('立即更新'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('强制更新：不显示「暂不更新」', (tester) async {
      await pumpDialog(
        tester,
        DiaryUpdateDialog(
          info: makeInfo(isForceUpdate: true),
          isAnnouncement: false,
          secondaryColor: secondaryColor,
          hasBackup: false,
        ),
      );

      expect(find.text('暂不更新'), findsNothing);
      expect(find.text('立即更新'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('DiaryUpdateDialog 备用下载', () {
    testWidgets('hasBackup=true：显示备用下载、按钮顺序正确、回调 onBackup 并关闭弹窗', (
      tester,
    ) async {
      var backupCalled = 0;
      var updateCalled = 0;
      await pumpDialog(
        tester,
        DiaryUpdateDialog(
          info: makeInfo(
            backupUrl: const {'android': 'https://example.com/backup.apk'},
          ),
          isAnnouncement: false,
          secondaryColor: secondaryColor,
          hasBackup: true,
          onBackup: () => backupCalled++,
          onUpdate: () => updateCalled++,
        ),
      );

      expect(find.text('备用下载'), findsOneWidget);
      // 按钮顺序（同一 Row，从左到右）：暂不更新 → 备用下载 → 立即更新
      final skipX = tester.getTopLeft(find.text('暂不更新')).dx;
      final backupX = tester.getTopLeft(find.text('备用下载')).dx;
      final updateX = tester.getTopLeft(find.text('立即更新')).dx;
      expect(skipX, lessThan(backupX));
      expect(backupX, lessThan(updateX));

      await tester.tap(find.text('备用下载'));
      await tester.pumpAndSettle();
      expect(backupCalled, 1);
      expect(updateCalled, 0);
      // Navigator.pop 属组件内展示行为：弹窗已关闭
      expect(find.byType(DiaryUpdateDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hasBackup=false：不显示备用下载', (tester) async {
      await pumpDialog(
        tester,
        DiaryUpdateDialog(
          info: makeInfo(),
          isAnnouncement: false,
          secondaryColor: secondaryColor,
          hasBackup: false,
          onBackup: () => fail('hasBackup=false 时不应回调 onBackup'),
        ),
      );

      expect(find.text('备用下载'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('DiaryUpdateDialog 立即更新', () {
    testWidgets('downloadUrl 非空：点击回调 onUpdate 并关闭弹窗', (tester) async {
      var updateCalled = 0;
      await pumpDialog(
        tester,
        DiaryUpdateDialog(
          info: makeInfo(),
          isAnnouncement: false,
          secondaryColor: secondaryColor,
          hasBackup: false,
          onUpdate: () => updateCalled++,
        ),
      );

      await tester.tap(find.text('立即更新'));
      await tester.pumpAndSettle();
      expect(updateCalled, 1);
      expect(find.byType(DiaryUpdateDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('downloadUrl 为 null：点击立即更新不回调不关闭', (tester) async {
      var updateCalled = 0;
      await pumpDialog(
        tester,
        DiaryUpdateDialog(
          info: makeInfo(downloadUrl: null),
          isAnnouncement: false,
          secondaryColor: secondaryColor,
          hasBackup: false,
          onUpdate: () => updateCalled++,
        ),
      );

      await tester.tap(find.text('立即更新'));
      await tester.pump();
      expect(updateCalled, 0);
      expect(find.byType(DiaryUpdateDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('暂不更新：仅关闭弹窗，不触发任何回调', (tester) async {
      var updateCalled = 0;
      await pumpDialog(
        tester,
        DiaryUpdateDialog(
          info: makeInfo(),
          isAnnouncement: false,
          secondaryColor: secondaryColor,
          hasBackup: false,
          onUpdate: () => updateCalled++,
        ),
      );

      await tester.tap(find.text('暂不更新'));
      await tester.pumpAndSettle();
      expect(updateCalled, 0);
      expect(find.byType(DiaryUpdateDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('DiaryUpdateDialog 跨平台渲染', () {
    testWidgets('Android 360 视口长 changelog + 备用下载：无溢出无异常', (tester) async {
      await pumpDialog(
        tester,
        DiaryUpdateDialog(
          info: makeInfo(
            changelog: List.generate(12, (i) => '改进项 ${i + 1}'),
            backupUrl: const {'android': 'https://example.com/backup.apk'},
          ),
          isAnnouncement: false,
          secondaryColor: secondaryColor,
          hasBackup: true,
        ),
      );

      expect(find.text('改进项 12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
