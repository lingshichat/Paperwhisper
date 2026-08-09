import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/config/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_run_result.dart';
import 'package:paper_whisper_flutter/models/sync_config.dart';
import 'package:paper_whisper_flutter/models/sync_trust_snapshot.dart';
import 'package:paper_whisper_flutter/pages/sync_settings_page.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/providers/sync_provider.dart';
import 'package:paper_whisper_flutter/services/moment_service.dart';
import 'package:paper_whisper_flutter/services/payment_service.dart';
import 'package:paper_whisper_flutter/services/sync_secret_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncSettingsPage', () {
    late List<Directory> tempDirs;

    setUpAll(() {
      ThemeRegistry.init();
    });

    setUp(() {
      tempDirs = <Directory>[];
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    tearDown(() async {
      for (final dir in tempDirs) {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    });

    testWidgets('sync settings shows pending count and retry action', (
      tester,
    ) async {
      final snapshot = SyncTrustSnapshot(
        state: SyncTrustState.syncFailed,
        pendingDiaryCount: 2,
        failureReason: '同步失败，内容仍保留在本地',
        lastSuccessfulSyncAt: DateTime(2026, 3, 12, 9, 30),
        lastSuccessfulSyncPlatform: 's3',
      );
      final provider = TestSyncProvider(snapshot: snapshot, tempDirs: tempDirs);

      await tester.pumpWidget(buildSyncSettingsApp(provider: provider));
      await tester.pump();
      await tester.pump();

      expect(find.text('尚有 2 项待同步'), findsOneWidget);
      expect(find.text('立即同步'), findsOneWidget);
      expect(find.text('同步失败，内容仍保留在本地'), findsOneWidget);
      expect(find.text('最近一次成功同步：2026-3-12 9:30（S3）'), findsOneWidget);
    });

    testWidgets('sync settings uses field-specific validation messages', (
      tester,
    ) async {
      final provider = TestSyncProvider(
        snapshot: const SyncTrustSnapshot(state: SyncTrustState.notEnabled),
        tempDirs: tempDirs,
      );

      await tester.pumpWidget(buildSyncSettingsApp(provider: provider));
      await tester.pump();
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), '');
      await tester.enterText(fields.at(2), '');
      await tester.ensureVisible(find.text('测试连接'));
      await tester.tap(find.text('测试连接'));
      await tester.pump();

      expect(find.text('请输入账号'), findsOneWidget);
      expect(find.text('请输入密码或应用授权码'), findsOneWidget);
      expect(find.text('不能为空'), findsNothing);
      expect(provider.connectCallCount, 0);
    });

    testWidgets('testing connection saves config without triggering sync', (
      tester,
    ) async {
      final provider = TestSyncProvider(
        snapshot: const SyncTrustSnapshot(state: SyncTrustState.notEnabled),
        tempDirs: tempDirs,
      );

      await tester.pumpWidget(buildSyncSettingsApp(provider: provider));
      await tester.pump();
      await tester.pump();

      await tester.ensureVisible(find.text('测试连接'));
      await tester.tap(find.text('测试连接'));
      await tester.pump();
      await tester.pump();

      expect(provider.connectCallCount, 1);
      expect(provider.syncCallCount, 0);
    });

    testWidgets(
      'renders sync toggles on Windows desktop and Android phone without '
      'framework exceptions or overflow',
      (tester) async {
        // 记录原始 view 参数，测试结束时恢复，避免污染其他测试
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // 阶段 1：Windows 桌面尺寸（1280x720 @1.0）
        tester.view.physicalSize = const Size(1280, 720);
        tester.view.devicePixelRatio = 1.0;

        final provider = TestSyncProvider(
          snapshot: const SyncTrustSnapshot(state: SyncTrustState.notEnabled),
          tempDirs: tempDirs,
        );

        await tester.pumpWidget(
          buildSyncSettingsApp(
            provider: provider,
            platform: TargetPlatform.windows,
          ),
        );
        await tester.pump();
        await tester.pump();

        // 结构断言：两处 SwitchListTile 与文案必须存在，构建无异常/溢出
        expect(find.byType(SwitchListTile), findsNWidgets(2));
        expect(find.text('开启自动同步'), findsOneWidget);
        expect(find.text('开启图片压缩'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 交互断言：依次点击两个开关，值翻转且不抛异常
        final autoSwitch = find.byType(SwitchListTile).at(0);
        final compressSwitch = find.byType(SwitchListTile).at(1);

        await tester.ensureVisible(autoSwitch);
        await tester.pump();
        final autoBefore = tester.widget<SwitchListTile>(autoSwitch).value;
        await tester.tap(autoSwitch);
        await tester.pump();
        expect(
          tester.widget<SwitchListTile>(autoSwitch).value,
          isNot(autoBefore),
        );

        await tester.ensureVisible(compressSwitch);
        await tester.pump();
        final compressBefore = tester
            .widget<SwitchListTile>(compressSwitch)
            .value;
        await tester.tap(compressSwitch);
        await tester.pump();
        expect(
          tester.widget<SwitchListTile>(compressSwitch).value,
          isNot(compressBefore),
        );
        expect(tester.takeException(), isNull);

        // 阶段 2：Android 手机尺寸（1080x2400 @3.0 → 逻辑 360x800）
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3.0;

        await tester.pumpWidget(
          buildSyncSettingsApp(
            provider: provider,
            platform: TargetPlatform.android,
          ),
        );
        await tester.pump();
        await tester.pump();

        // 窄屏下同样必须无溢出、无异常
        expect(find.byType(SwitchListTile), findsNWidgets(2));
        expect(find.text('开启自动同步'), findsOneWidget);
        expect(find.text('开启图片压缩'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(autoSwitch);
        await tester.pump();
        final androidAutoBefore = tester
            .widget<SwitchListTile>(autoSwitch)
            .value;
        await tester.tap(autoSwitch);
        await tester.pump();
        expect(
          tester.widget<SwitchListTile>(autoSwitch).value,
          isNot(androidAutoBefore),
        );

        await tester.ensureVisible(compressSwitch);
        await tester.pump();
        final androidCompressBefore = tester
            .widget<SwitchListTile>(compressSwitch)
            .value;
        await tester.tap(compressSwitch);
        await tester.pump();
        expect(
          tester.widget<SwitchListTile>(compressSwitch).value,
          isNot(androidCompressBefore),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('waitUntilReady 引导填充 WebDAV 三字段', (tester) async {
      final provider = TestSyncProvider(
        snapshot: const SyncTrustSnapshot(state: SyncTrustState.notEnabled),
        tempDirs: tempDirs,
        config: SyncConfig(
          enabled: true,
          autoSync: true,
          compressImages: false,
          serverUrl: 'https://dav.example.com/',
          username: 'bootstrap-user',
          password: 'bootstrap-pass',
          s3EndPoint: 'play.min.io',
          s3AccessKey: 'AK123',
          s3SecretKey: 'SK456',
          s3BucketName: 'bucket-name',
          s3Region: 'us-east-1',
        ),
      );

      await tester.pumpWidget(buildSyncSettingsApp(provider: provider));
      await tester.pump();
      await tester.pump();

      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(3)); // WebDAV 三字段
      expect(
        tester.widget<TextFormField>(fields.at(0)).controller!.text,
        'https://dav.example.com/',
      );
      expect(
        tester.widget<TextFormField>(fields.at(1)).controller!.text,
        'bootstrap-user',
      );
      expect(
        tester.widget<TextFormField>(fields.at(2)).controller!.text,
        'bootstrap-pass',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('协议切换：WebDAV ↔ S3 字段组切换且保留引导填充', (tester) async {
      final provider = TestSyncProvider(
        snapshot: const SyncTrustSnapshot(state: SyncTrustState.notEnabled),
        tempDirs: tempDirs,
        config: SyncConfig(
          enabled: true,
          serverUrl: 'https://dav.example.com/',
          username: 'bootstrap-user',
          password: 'bootstrap-pass',
          s3EndPoint: 'play.min.io',
          s3AccessKey: 'AK123',
          s3SecretKey: 'SK456',
          s3BucketName: 'bucket-name',
          s3Region: 'us-east-1',
        ),
      );

      await tester.pumpWidget(buildSyncSettingsApp(provider: provider));
      await tester.pump();
      await tester.pump();
      expect(find.text('WebDAV 服务器配置'), findsOneWidget);

      // 切到 S3：saveConfig(syncType: s3) + 五字段渲染且已填充
      await tester.tap(find.text('S3 存储'));
      await tester.pump();
      await tester.pump();
      expect(provider.lastSavedConfig!.syncType, SyncType.s3);
      expect(find.text('S3 对象存储配置'), findsOneWidget);
      expect(find.text('WebDAV 服务器配置'), findsNothing);
      final s3Fields = find.byType(TextFormField);
      expect(s3Fields, findsNWidgets(5));
      expect(
        tester.widget<TextFormField>(s3Fields.at(0)).controller!.text,
        'play.min.io',
      );
      expect(
        tester.widget<TextFormField>(s3Fields.at(1)).controller!.text,
        'bucket-name',
      );
      expect(
        tester.widget<TextFormField>(s3Fields.at(2)).controller!.text,
        'AK123',
      );
      expect(
        tester.widget<TextFormField>(s3Fields.at(3)).controller!.text,
        'SK456',
      );
      expect(
        tester.widget<TextFormField>(s3Fields.at(4)).controller!.text,
        'us-east-1',
      );

      // 切回 WebDAV：三字段保值（引导填充值不被切协议清空）
      await tester.tap(find.text('WebDAV'));
      await tester.pump();
      await tester.pump();
      expect(provider.lastSavedConfig!.syncType, SyncType.webdav);
      expect(find.text('WebDAV 服务器配置'), findsOneWidget);
      expect(find.text('S3 对象存储配置'), findsNothing);
      final webdavFields = find.byType(TextFormField);
      expect(
        tester.widget<TextFormField>(webdavFields.at(0)).controller!.text,
        'https://dav.example.com/',
      );
      expect(
        tester.widget<TextFormField>(webdavFields.at(2)).controller!.text,
        'bootstrap-pass',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('bootstrap 引导填充 8 字段，切协议保值（S3 起始）', (tester) async {
      final provider = TestSyncProvider(
        snapshot: const SyncTrustSnapshot(state: SyncTrustState.notEnabled),
        tempDirs: tempDirs,
        config: SyncConfig(
          enabled: true,
          syncType: SyncType.s3,
          serverUrl: 'https://dav.example.com/',
          username: 'dav-user',
          password: 'dav-pass',
          s3EndPoint: 'play.min.io',
          s3AccessKey: 'AK123',
          s3SecretKey: 'SK456',
          s3BucketName: 'bucket-name',
          s3Region: 'us-east-1',
        ),
      );

      await tester.pumpWidget(buildSyncSettingsApp(provider: provider));
      await tester.pump();
      await tester.pump();

      // S3 初始：5 字段已填充
      var fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(5));
      expect(
        tester.widget<TextFormField>(fields.at(0)).controller!.text,
        'play.min.io',
      );
      expect(
        tester.widget<TextFormField>(fields.at(4)).controller!.text,
        'us-east-1',
      );

      // 切到 WebDAV：3 字段保值（引导值不丢失）
      await tester.tap(find.text('WebDAV'));
      await tester.pump();
      await tester.pump();
      fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(3));
      expect(
        tester.widget<TextFormField>(fields.at(0)).controller!.text,
        'https://dav.example.com/',
      );
      expect(
        tester.widget<TextFormField>(fields.at(1)).controller!.text,
        'dav-user',
      );
      expect(
        tester.widget<TextFormField>(fields.at(2)).controller!.text,
        'dav-pass',
      );
      expect(provider.lastSavedConfig!.syncType, SyncType.webdav);

      // 切回 S3：5 字段仍保值
      await tester.tap(find.text('S3 存储'));
      await tester.pump();
      await tester.pump();
      fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(5));
      expect(
        tester.widget<TextFormField>(fields.at(0)).controller!.text,
        'play.min.io',
      );
      expect(
        tester.widget<TextFormField>(fields.at(4)).controller!.text,
        'us-east-1',
      );
      expect(provider.lastSavedConfig!.syncType, SyncType.s3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('URL 校验：非法前缀与空值分别提示且不触发连接', (tester) async {
      final provider = TestSyncProvider(
        snapshot: const SyncTrustSnapshot(state: SyncTrustState.notEnabled),
        tempDirs: tempDirs,
      );

      await tester.pumpWidget(buildSyncSettingsApp(provider: provider));
      await tester.pump();
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'ftp://invalid');
      await tester.ensureVisible(find.text('测试连接'));
      await tester.tap(find.text('测试连接'));
      await tester.pump();
      expect(find.text('服务器地址需以 http:// 或 https:// 开头'), findsOneWidget);
      expect(provider.connectCallCount, 0);

      // 清空 → 必填提示（错误文案撑高布局后按钮可能下移，需重新定位）
      await tester.enterText(fields.at(0), '');
      await tester.ensureVisible(find.text('测试连接'));
      await tester.tap(find.text('测试连接'));
      await tester.pump();
      expect(find.text('请输入服务器地址'), findsOneWidget);
      expect(provider.connectCallCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('测试连接成功：保存配置并提示，不触发真实同步', (tester) async {
      final provider = TestSyncProvider(
        snapshot: const SyncTrustSnapshot(state: SyncTrustState.notEnabled),
        tempDirs: tempDirs,
      );

      await tester.pumpWidget(buildSyncSettingsApp(provider: provider));
      await tester.pump();
      await tester.pump();

      await tester.ensureVisible(find.text('测试连接'));
      await tester.tap(find.text('测试连接'));
      await tester.pump();
      await tester.pump();

      expect(find.text('连接成功，配置已保存'), findsOneWidget);
      expect(provider.connectCallCount, 1);
      expect(provider.syncCallCount, 0);
      expect(provider.lastSavedConfig!.enabled, isTrue);
      expect(provider.lastSavedConfig!.serverUrl, 'https://dav.example.com/');
      await drainSnackBarTimers(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('测试连接失败：提示失败文案且不触发真实同步', (tester) async {
      final provider = TestSyncProvider(
        snapshot: const SyncTrustSnapshot(state: SyncTrustState.notEnabled),
        tempDirs: tempDirs,
      )..connectResult = false;

      await tester.pumpWidget(buildSyncSettingsApp(provider: provider));
      await tester.pump();
      await tester.pump();

      await tester.ensureVisible(find.text('测试连接'));
      await tester.tap(find.text('测试连接'));
      await tester.pump();
      await tester.pump();

      expect(find.text('连接失败，请检查配置'), findsOneWidget);
      expect(provider.connectCallCount, 1);
      expect(provider.syncCallCount, 0);
      await drainSnackBarTimers(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('立即同步成功（有变更）：展示分类统计并保存配置', (tester) async {
      final provider =
          TestSyncProvider(
              snapshot: const SyncTrustSnapshot(
                state: SyncTrustState.notEnabled,
              ),
              tempDirs: tempDirs,
            )
            ..syncResultBuilder = () => const SyncRunResult(
              status: SyncRunStatus.success,
              processedDiaries: 1,
              processedMoments: 2,
              processedImages: 3,
              processedAudio: 4,
            );

      await tester.pumpWidget(buildSyncSettingsApp(provider: provider));
      await tester.pump();
      await tester.pump();

      await tester.ensureVisible(find.text('立即同步'));
      await tester.tap(find.text('立即同步'));
      await tester.pump();
      await tester.pump();

      expect(find.text('已同步: 1篇日记, 2篇随心记\n3张图片, 4条语音'), findsOneWidget);
      expect(provider.syncCallCount, 1);
      expect(provider.lastSavedConfig!.enabled, isTrue);
      await drainSnackBarTimers(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('立即同步成功（无变更）：提示「同步完成 (无变更)」', (tester) async {
      final provider = TestSyncProvider(
        snapshot: const SyncTrustSnapshot(state: SyncTrustState.notEnabled),
        tempDirs: tempDirs,
      );

      await tester.pumpWidget(buildSyncSettingsApp(provider: provider));
      await tester.pump();
      await tester.pump();

      await tester.ensureVisible(find.text('立即同步'));
      await tester.tap(find.text('立即同步'));
      await tester.pump();
      await tester.pump();

      expect(find.text('同步完成 (无变更)'), findsOneWidget);
      expect(provider.syncCallCount, 1);
      await drainSnackBarTimers(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('立即同步失败：提示失败原因', (tester) async {
      final provider =
          TestSyncProvider(
              snapshot: const SyncTrustSnapshot(
                state: SyncTrustState.notEnabled,
              ),
              tempDirs: tempDirs,
            )
            ..syncResultBuilder = () => const SyncRunResult(
              status: SyncRunStatus.failed,
              failureMessage: 'WebDAV 连接被拒绝',
            );

      await tester.pumpWidget(buildSyncSettingsApp(provider: provider));
      await tester.pump();
      await tester.pump();

      await tester.ensureVisible(find.text('立即同步'));
      await tester.tap(find.text('立即同步'));
      await tester.pump();
      await tester.pump();

      expect(find.text('WebDAV 连接被拒绝'), findsOneWidget);
      expect(provider.syncCallCount, 1);
      await drainSnackBarTimers(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('立即同步 pending：提示待同步数量', (tester) async {
      final provider =
          TestSyncProvider(
              snapshot: const SyncTrustSnapshot(
                state: SyncTrustState.notEnabled,
              ),
              tempDirs: tempDirs,
            )
            ..syncResultBuilder = () => const SyncRunResult(
              status: SyncRunStatus.pending,
              pendingCount: 2,
            );

      await tester.pumpWidget(buildSyncSettingsApp(provider: provider));
      await tester.pump();
      await tester.pump();

      await tester.ensureVisible(find.text('立即同步'));
      await tester.tap(find.text('立即同步'));
      await tester.pump();
      await tester.pump();

      expect(find.text('尚有 2 项待同步'), findsOneWidget);
      expect(provider.syncCallCount, 1);
      await drainSnackBarTimers(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('停用同步：保存 enabled=false 并提示，按钮随状态消失', (tester) async {
      final provider = TestSyncProvider(
        snapshot: const SyncTrustSnapshot(state: SyncTrustState.notEnabled),
        tempDirs: tempDirs,
      );

      await tester.pumpWidget(buildSyncSettingsApp(provider: provider));
      await tester.pump();
      await tester.pump();

      await tester.ensureVisible(find.text('停用同步'));
      await tester.tap(find.text('停用同步'));
      await tester.pump();
      await tester.pump();

      expect(find.text('已停用同步，内容将继续保留在本地'), findsOneWidget);
      expect(provider.lastSavedConfig!.enabled, isFalse);
      expect(find.text('停用同步'), findsNothing);
      await drainSnackBarTimers(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('自动同步/图片压缩开关反映到保存的配置', (tester) async {
      final provider = TestSyncProvider(
        snapshot: const SyncTrustSnapshot(state: SyncTrustState.notEnabled),
        tempDirs: tempDirs,
      );

      await tester.pumpWidget(buildSyncSettingsApp(provider: provider));
      await tester.pump();
      await tester.pump();

      // 默认 config：autoSync=true、compressImages=true → 翻转后为 false
      final autoSwitch = find.byType(SwitchListTile).at(0);
      final compressSwitch = find.byType(SwitchListTile).at(1);
      await tester.ensureVisible(autoSwitch);
      await tester.pump();
      await tester.tap(autoSwitch);
      await tester.pump();
      await tester.ensureVisible(compressSwitch);
      await tester.pump();
      await tester.tap(compressSwitch);
      await tester.pump();

      await tester.ensureVisible(find.text('测试连接'));
      await tester.tap(find.text('测试连接'));
      await tester.pump();
      await tester.pump();

      expect(provider.lastSavedConfig!.autoSync, isFalse);
      expect(provider.lastSavedConfig!.compressImages, isFalse);
      expect(provider.syncCallCount, 0);
      await drainSnackBarTimers(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('信任状态卡：未启用/待同步/已成功/需检查 标题与行文案', (tester) async {
      final cases = <SyncTrustSnapshot, List<String>>{
        const SyncTrustSnapshot(state: SyncTrustState.notEnabled): <String>[
          '同步未启用',
          '启用后即可把本地内容同步到云端',
        ],
        const SyncTrustSnapshot(
          state: SyncTrustState.localChangesPending,
          pendingDiaryCount: 2,
        ): <String>[
          '本地仍有内容待同步',
          '尚有 2 项待同步',
        ],
        SyncTrustSnapshot(
          state: SyncTrustState.syncedSuccessfully,
          lastSuccessfulSyncAt: DateTime(2026, 3, 12, 9, 30),
          lastSuccessfulSyncPlatform: 's3',
        ): <String>[
          '同步状态正常',
          '最近一次成功同步：2026-3-12 9:30（S3）',
        ],
        const SyncTrustSnapshot(state: SyncTrustState.needsAttention): <String>[
          '需要检查同步配置',
        ],
      };

      for (final entry in cases.entries) {
        final provider = TestSyncProvider(
          snapshot: entry.key,
          tempDirs: tempDirs,
        );
        await tester.pumpWidget(buildSyncSettingsApp(provider: provider));
        await tester.pump();
        await tester.pump();
        for (final text in entry.value) {
          expect(find.text(text), findsOneWidget);
        }
        // 换 provider 前销毁整棵树，释放上一轮计时器
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });
  });
}

/// 消化 SnackBar 的 2s 自动关闭计时：先完成入场动画（约 250ms）使计时
/// 启动，再推进到计时到点与退场动画结束。
Future<void> drainSnackBarTimers(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Widget buildSyncSettingsApp({
  required SyncProvider provider,
  TargetPlatform? platform,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(),
      ),
      ChangeNotifierProvider<SyncProvider>.value(value: provider),
      ChangeNotifierProvider<PaymentService>.value(value: PaymentService()),
    ],
    child: MaterialApp(
      // 测试注入目标平台：ThemeData(platform:) 决定主题与部件平台行为
      theme: platform == null ? null : ThemeData(platform: platform),
      home: const SyncSettingsPage(),
    ),
  );
}

class TestSyncProvider extends SyncProvider {
  TestSyncProvider({
    required SyncTrustSnapshot snapshot,
    required List<Directory> tempDirs,
    SyncConfig? config,
  }) : _snapshot = snapshot,
       _config =
           config ??
           SyncConfig(
             enabled: true,
             autoSync: true,
             serverUrl: 'https://dav.example.com/',
             username: 'demo',
             password: 'secret',
           ),
       super(
         momentService: _createMomentService(tempDirs),
         secretStore: SyncSecretStore.fake(),
         initializeNotifications: false,
       );

  final SyncTrustSnapshot _snapshot;
  SyncConfig _config;
  int connectCallCount = 0;
  int syncCallCount = 0;

  /// [connect] 的返回结果（测试连接成功/失败分支）。
  bool connectResult = true;

  /// 最近一次 [saveConfig] 保存的配置（断言保存编排与字段透传）。
  SyncConfig? lastSavedConfig;

  /// 非 null 时 [sync] 返回该结果；否则返回成功（无变更）。
  SyncRunResult Function()? syncResultBuilder;

  static MomentService _createMomentService(List<Directory> tempDirs) {
    final rootDir = Directory.systemTemp.createTempSync(
      'sync_settings_page_test',
    );
    tempDirs.add(rootDir);
    // 使用真实 MomentService（debug 数据目录注入），避免子类重声明
    // 私有字段（_dataDir/_imagesDir/_audioDir）遮蔽父类实现的模式。
    return MomentService(debugDataDir: rootDir);
  }

  @override
  SyncConfig get config => _config;

  @override
  SyncTrustSnapshot get trustSnapshot => _snapshot;

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<void> waitUntilReady() async {}

  @override
  Future<void> saveConfig(SyncConfig newConfig) async {
    _config = newConfig;
    lastSavedConfig = newConfig;
    notifyListeners();
  }

  @override
  Future<bool> connect({
    bool test = true,
    bool awaitInitialization = true,
  }) async {
    connectCallCount++;
    return connectResult;
  }

  @override
  Future<SyncRunResult> sync({bool isAuto = false}) async {
    syncCallCount++;
    return syncResultBuilder?.call() ??
        const SyncRunResult(status: SyncRunStatus.success);
  }
}
