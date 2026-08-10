import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/update/application/update_download_controller.dart';
import 'package:paper_whisper_flutter/features/update/data/update_info.dart';
import 'package:paper_whisper_flutter/features/update/data/update_service.dart';
import 'package:paper_whisper_flutter/features/update/presentation/update_dialog.dart';

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

  group('UpdateDialog 下载按钮状态', () {
    UpdateInfo makeInfo({List<String> changelog = const ['新增应用内下载']}) {
      return UpdateInfo(
        latestVersion: '1.2.0',
        changelog: changelog,
        downloadUrl: const {'android': 'https://example.com/app.apk'},
        backupUrl: const {'android': 'https://example.com/app-backup.apk'},
      );
    }

    Future<void> pumpDialog(
      WidgetTester tester,
      UpdateDownloadController controller, {
      List<String> changelog = const ['新增应用内下载'],
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateDialog(
              updateInfo: makeInfo(changelog: changelog),
              currentVersion: '1.1.0',
              controller: controller,
            ),
          ),
        ),
      );
    }

    testWidgets('idle：立即更新 + 备用下载；点击进入下载态显示取消与进度', (tester) async {
      final gateway = _WidgetFakeGateway.pending();
      final controller = UpdateDownloadController(gateway: gateway);
      addTearDown(controller.dispose);

      await pumpDialog(tester, controller);
      expect(find.text('立即更新'), findsOneWidget);
      expect(find.text('备用下载'), findsOneWidget);

      await tester.tap(find.text('立即更新'));
      await tester.pump();
      expect(find.text('取消下载'), findsOneWidget);
      expect(find.text('正在连接...'), findsOneWidget);

      // 完成下载 → downloaded 态
      gateway.complete('/tmp/update.apk');
      await tester.pumpAndSettle();
      expect(find.text('下载完成'), findsOneWidget);
      expect(find.text('立即安装'), findsOneWidget);
      expect(find.text('备用下载'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('下载失败：错误信息 + 重试 + 浏览器下载', (tester) async {
      final gateway = _WidgetFakeGateway();
      gateway.downloadError = DioException(
        requestOptions: RequestOptions(path: 'https://example.com/app.apk'),
        type: DioExceptionType.connectionTimeout,
      );
      final controller = UpdateDownloadController(gateway: gateway);
      addTearDown(controller.dispose);

      await pumpDialog(tester, controller, changelog: const []);
      await tester.tap(find.text('立即更新'));
      await tester.pumpAndSettle();

      expect(find.text('网络超时，请检查网络连接后重试'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('浏览器下载'), findsOneWidget);
      expect(find.text('备用下载'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('真实长 changelog + error 态在 Android 360x600 无 Flex 溢出且按钮可滚动到达', (
      tester,
    ) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.physicalSize = const Size(360, 600);
      tester.view.devicePixelRatio = 1.0;

      final gateway = _WidgetFakeGateway();
      gateway.downloadError = DioException(
        requestOptions: RequestOptions(path: 'https://example.com/app.apk'),
        type: DioExceptionType.connectionTimeout,
      );
      final controller = UpdateDownloadController(gateway: gateway);
      addTearDown(controller.dispose);

      // 贴近真实发布的非空 changelog
      final changelog = List.generate(
        12,
        (i) => '更新内容第 ${i + 1} 条：修复了若干问题并优化了整体体验，让每一条日志都足够长以贴近真实发布说明。',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateDialog(
              updateInfo: UpdateInfo(
                latestVersion: '1.2.0',
                changelog: changelog,
                downloadUrl: const {'android': 'https://example.com/app.apk'},
                backupUrl: const {
                  'android': 'https://example.com/app-backup.apk',
                },
              ),
              currentVersion: '1.1.0',
              controller: controller,
            ),
          ),
        ),
      );

      // 触发下载失败 → error 态
      await tester.tap(find.text('立即更新'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('重试'), findsOneWidget);

      // 按钮区在剩余高度不足时可滚动到达（不能隐藏/缩字/改变文案）
      await tester.dragUntilVisible(
        find.text('浏览器下载'),
        find.byType(UpdateDialog),
        const Offset(0, -80),
      );
      expect(find.text('浏览器下载'), findsOneWidget);
      // 滚动后的按钮仍可点击（不因滚动容器失效）
      await tester.tap(find.text('浏览器下载'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '真实长 changelog 下 idle/downloading/downloaded/error 四态均无 Flex 异常',
      (tester) async {
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        tester.view.physicalSize = const Size(360, 600);
        tester.view.devicePixelRatio = 1.0;

        final changelog = List.generate(
          10,
          (i) => '更新内容第 ${i + 1} 条：修复了若干问题并优化了整体体验，让每一条日志都足够长以贴近真实发布说明。',
        );

        // idle
        final idleGateway = _WidgetFakeGateway.pending();
        final idleController = UpdateDownloadController(gateway: idleGateway);
        addTearDown(idleController.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UpdateDialog(
                updateInfo: makeInfo(changelog: changelog),
                currentVersion: '1.1.0',
                controller: idleController,
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('立即更新'), findsOneWidget);

        // downloading
        await tester.tap(find.text('立即更新'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('取消下载'), findsOneWidget);

        // downloaded
        idleGateway.complete('/tmp/update.apk');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('立即安装'), findsOneWidget);

        // error（重新 pump 一个新对话框进入 error 态）
        final errorGateway = _WidgetFakeGateway();
        errorGateway.downloadError = DioException(
          requestOptions: RequestOptions(path: 'https://example.com/app.apk'),
          type: DioExceptionType.connectionTimeout,
        );
        final errorController = UpdateDownloadController(gateway: errorGateway);
        addTearDown(errorController.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UpdateDialog(
                key: UniqueKey(),
                updateInfo: makeInfo(changelog: changelog),
                currentVersion: '1.1.0',
                controller: errorController,
              ),
            ),
          ),
        );
        await tester.tap(find.text('立即更新'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('重试'), findsOneWidget);
      },
    );

    testWidgets('下载失败后重试成功回到下载态', (tester) async {
      final gateway = _WidgetFakeGateway();
      gateway.downloadError = DioException(
        requestOptions: RequestOptions(path: 'https://example.com/app.apk'),
        type: DioExceptionType.connectionTimeout,
      );
      final controller = UpdateDownloadController(gateway: gateway);
      addTearDown(controller.dispose);

      await pumpDialog(tester, controller, changelog: const []);
      await tester.tap(find.text('立即更新'));
      await tester.pumpAndSettle();
      expect(find.text('重试'), findsOneWidget);

      // 清除错误后重试 → 成功
      gateway.downloadError = null;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('下载完成'), findsOneWidget);
      expect(find.text('立即安装'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// UpdateDialog 按钮状态测试用的可驱动下载网关替身。
class _WidgetFakeGateway implements UpdateDownloadGateway {
  _WidgetFakeGateway() : _completer = null;

  _WidgetFakeGateway.pending() : _completer = Completer<String>();

  final Completer<String>? _completer;
  Object? downloadError;

  @override
  String get currentPlatform => 'android';

  @override
  Future<String> downloadUpdate({
    required String url,
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) {
    if (downloadError != null) {
      return Future<void>.delayed(
        Duration.zero,
      ).then((_) => throw downloadError!);
    }
    if (_completer != null) {
      return _completer.future;
    }
    return Future.value('/tmp/update.apk');
  }

  @override
  Future<UpdateInstallResult> installUpdate(String filePath) async {
    return const UpdateInstallResult(UpdateInstallStatus.launched);
  }

  @override
  Future<bool> openDownloadUrl(
    UpdateInfo updateInfo, {
    bool useBackup = false,
  }) async {
    return true;
  }

  void complete(String path) {
    _completer?.complete(path);
  }
}
