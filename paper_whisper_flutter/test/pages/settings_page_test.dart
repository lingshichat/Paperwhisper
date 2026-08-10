import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/config/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/models/sync_config.dart';
import 'package:paper_whisper_flutter/models/sync_trust_snapshot.dart';
import 'package:paper_whisper_flutter/pages/settings_page.dart';
import 'package:paper_whisper_flutter/pages/sync_settings_page.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/providers/sync_provider.dart';
import 'package:paper_whisper_flutter/services/moment_service.dart';
import 'package:paper_whisper_flutter/services/payment_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/page_coordinator_test_fakes.dart';

/// SettingsPage 重构前行为刻画测试（阶段 4 测试 lane 第一批）。
///
/// 只通过公共 UI 与公开 Provider 契约断言，不触碰私有状态：
/// 覆盖 Windows/Android 双平台基本渲染、同步状态文案 7 分支、
/// 主题/启动页选择入口、权限/存储管理入口与更新检查的
/// loading/失败反馈边界、dispose 无泄漏。
///
/// seam 说明：
/// - 存储信息（`_loadStorageInfo` → StorageService 真实文件统计）在
///   fake async 下悬挂，页面稳定停留在「计算中...」，因此存储测试只
///   稳定刻画管理弹窗入口，不断言统计数值；
/// - 权限一律由 channel mock 返回 granted，因此「去授权」交互分支
///   不可达，权限测试只覆盖已授权展示路径；
/// - 更新检查走 package_info mock（版本 1.0.0）+ http 悬挂后的
///   10s 超时失败分支（真实网络在 fake async 下不会完成）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Directory> tempDirs;
  late PageCoordinatorFakeMomentService momentService;

  setUpAll(() {
    ThemeRegistry.init();
  });

  setUp(() {
    tempDirs = <Directory>[];
    SharedPreferences.setMockInitialValues(<String, Object>{});
    installPageCoordinatorPlatformMocks();
    addTearDown(uninstallPageCoordinatorPlatformMocks);
    final dataDir = Directory.systemTemp.createTempSync('settings_page_test');
    tempDirs.add(dataDir);
    momentService = PageCoordinatorFakeMomentService(dataDir: dataDir);
  });

  tearDown(() async {
    for (final dir in tempDirs) {
      if (await dir.exists()) {
        try {
          await dir.delete(recursive: true);
        } catch (_) {
          // Windows 文件占用时忽略，避免拖垮整个批次
        }
      }
    }
  });

  Widget buildSettingsApp({
    required PageCoordinatorSyncProvider syncProvider,
    TargetPlatform? platform,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProvider<SyncProvider>.value(value: syncProvider),
        Provider<MomentService>.value(value: momentService),
        ChangeNotifierProvider<PaymentService>.value(value: PaymentService()),
      ],
      child: MaterialApp(
        theme: platform == null ? null : ThemeData(platform: platform),
        home: const SettingsPage(),
      ),
    );
  }

  Future<void> pumpSettings(
    WidgetTester tester, {
    required PageCoordinatorSyncProvider syncProvider,
    TargetPlatform? platform,
  }) async {
    await tester.pumpWidget(
      buildSettingsApp(syncProvider: syncProvider, platform: platform),
    );
    // initState 触发异步权限检查（channel mock 立即完成）与存储信息加载
    // （真实 IO 悬挂，停留在「计算中...」）。
    await tester.pump();
    await tester.pump();

    // 收尾销毁整棵 widget 树：dispose 让 SnackBar / BottomSheet 计时器
    // 随 ScaffoldMessenger / Navigator 一并释放。
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  PageCoordinatorSyncProvider makeSyncProvider({
    SyncConfig? config,
    SyncTrustSnapshot? snapshot,
  }) {
    return PageCoordinatorSyncProvider(
      config: config,
      snapshot: snapshot,
      momentService: momentService,
    );
  }

  group('SettingsPage 双平台基本渲染', () {
    testWidgets('Windows 桌面渲染主要 section 无溢出无异常', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;

      final syncProvider = makeSyncProvider();
      await pumpSettings(
        tester,
        syncProvider: syncProvider,
        platform: TargetPlatform.windows,
      );

      expect(find.text('设置'), findsOneWidget);
      expect(find.text('账号与会员'), findsOneWidget);
      expect(find.text('支持开发者'), findsOneWidget);
      expect(find.text('数据同步'), findsOneWidget);
      expect(find.text('未启用'), findsOneWidget); // 同步状态：notEnabled
      expect(find.text('权限状态: 3 / 3 已获取'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Android 360x800 渲染顶部内容无溢出无异常', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;

      final syncProvider = makeSyncProvider();
      await pumpSettings(
        tester,
        syncProvider: syncProvider,
        platform: TargetPlatform.android,
      );

      expect(find.text('设置'), findsOneWidget);
      expect(find.text('账号与会员'), findsOneWidget);
      expect(find.text('数据同步'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('页面销毁后无异常（dispose 清理）', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpSettings(tester, syncProvider: syncProvider);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('SettingsPage 同步状态文案', () {
    testWidgets('未启用同步显示「未启用」', (tester) async {
      final syncProvider = makeSyncProvider(
        snapshot: const SyncTrustSnapshot(state: SyncTrustState.notEnabled),
      );
      await pumpSettings(tester, syncProvider: syncProvider);

      expect(find.text('数据同步'), findsOneWidget);
      expect(find.text('未启用'), findsOneWidget);
    });

    testWidgets('同步中显示「同步中...」', (tester) async {
      final syncProvider = makeSyncProvider(
        snapshot: const SyncTrustSnapshot(state: SyncTrustState.syncing),
      );
      await pumpSettings(tester, syncProvider: syncProvider);

      expect(find.text('同步中...'), findsOneWidget);
    });

    testWidgets('有待同步项显示「尚有 N 项待同步」', (tester) async {
      final syncProvider = makeSyncProvider(
        snapshot: const SyncTrustSnapshot(
          state: SyncTrustState.localChangesPending,
          pendingDiaryCount: 3,
          pendingMomentCount: 1,
          pendingImageCount: 2,
          pendingAudioCount: 0,
        ),
      );
      await pumpSettings(tester, syncProvider: syncProvider);

      expect(find.text('尚有 6 项待同步'), findsOneWidget);
    });

    testWidgets('同步失败优先显示失败原因', (tester) async {
      final syncProvider = makeSyncProvider(
        snapshot: const SyncTrustSnapshot(
          state: SyncTrustState.syncFailed,
          failureReason: 'WebDAV 连接被拒绝',
        ),
      );
      await pumpSettings(tester, syncProvider: syncProvider);

      expect(find.text('WebDAV 连接被拒绝'), findsOneWidget);
    });

    testWidgets('同步失败无原因时显示兜底文案', (tester) async {
      final syncProvider = makeSyncProvider(
        snapshot: const SyncTrustSnapshot(state: SyncTrustState.syncFailed),
      );
      await pumpSettings(tester, syncProvider: syncProvider);

      expect(find.text('同步失败，内容仍保留在本地'), findsOneWidget);
    });

    testWidgets('需要检查配置时显示兜底文案', (tester) async {
      final syncProvider = makeSyncProvider(
        snapshot: const SyncTrustSnapshot(state: SyncTrustState.needsAttention),
      );
      await pumpSettings(tester, syncProvider: syncProvider);

      expect(find.text('需要检查同步配置'), findsOneWidget);
    });

    testWidgets('最近成功同步展示时间与平台', (tester) async {
      final syncProvider = makeSyncProvider(
        snapshot: SyncTrustSnapshot(
          state: SyncTrustState.syncedSuccessfully,
          lastSuccessfulSyncAt: DateTime(2026, 3, 12, 9, 30),
          lastSuccessfulSyncPlatform: 's3',
        ),
      );
      await pumpSettings(tester, syncProvider: syncProvider);

      expect(find.text('最近一次成功同步：2026-3-12 9:30（S3）'), findsOneWidget);
    });

    testWidgets('已同步但无最近成功时间显示「已启用」', (tester) async {
      final syncProvider = makeSyncProvider(
        snapshot: const SyncTrustSnapshot(
          state: SyncTrustState.syncedSuccessfully,
        ),
      );
      await pumpSettings(tester, syncProvider: syncProvider);

      expect(find.text('已启用'), findsOneWidget);
    });
  });

  group('SettingsPage 入口与交互', () {
    testWidgets('数据同步入口经 AppRoutes 导航到同步设置页', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpSettings(tester, syncProvider: syncProvider);

      await tester.tap(find.text('数据同步'));
      await tester.pumpAndSettle();

      // AppRoutes.syncSettings() 返回 SlidePageRoute(SyncSettingsPage)
      expect(find.byType(SyncSettingsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('主题风格入口打开选择面板并切换主题', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpSettings(tester, syncProvider: syncProvider);

      await tester.tap(find.text('主题风格'));
      await tester.pumpAndSettle();
      expect(find.text('选择主题'), findsOneWidget);
      expect(find.text('午夜星尘'), findsOneWidget);

      // 主题选择不自动关闭（closeOnSelect: false）；切换后 subtitle 更新。
      // 午夜星尘主题带 StarrySky 无限动画，不能用 pumpAndSettle。
      await tester.tap(find.text('午夜星尘'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 面板选项 + 列表 subtitle 各出现一次
      expect(find.text('午夜星尘'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('启动页入口打开选择面板并更新启动页', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpSettings(tester, syncProvider: syncProvider);

      await tester.tap(find.text('启动页'));
      await tester.pumpAndSettle();
      expect(find.text('选择启动页'), findsOneWidget);

      await tester.tap(find.text('随心记'));
      await tester.pumpAndSettle();

      // 选择后自动关闭（closeOnSelect: true），subtitle 更新为「随心记」
      expect(find.text('选择启动页'), findsNothing);
      expect(find.text('随心记'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('系统权限管理入口展示三行权限与已授权状态', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpSettings(tester, syncProvider: syncProvider);

      // scrollUntilVisible 只保证 item 进入 cacheExtent（可能仍在视口
      // 外），必须再 ensureVisible 确保真正可见后 tap 才会命中。
      final permissionEntry = find.text('系统权限管理');
      await tester.scrollUntilVisible(permissionEntry, 300);
      await tester.ensureVisible(permissionEntry);
      await tester.pumpAndSettle();
      await tester.tap(permissionEntry);
      await tester.pumpAndSettle();

      expect(find.text('应用权限管理'), findsOneWidget);
      expect(find.text('文件存储 (核心)'), findsOneWidget);
      expect(find.text('相册访问'), findsOneWidget);
      expect(find.text('通知提醒'), findsOneWidget);
      // 三行均 mock 为 granted
      expect(find.text('已获取'), findsNWidgets(3));
      expect(tester.takeException(), isNull);

      // 点击遮罩关闭面板
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('应用权限管理'), findsNothing);
    });

    testWidgets('存储空间管理入口展示清理动作', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpSettings(tester, syncProvider: syncProvider);

      final storageEntry = find.text('存储空间管理');
      await tester.scrollUntilVisible(storageEntry, 300);
      await tester.ensureVisible(storageEntry);
      await tester.pumpAndSettle();
      await tester.tap(storageEntry);

      // S3a 后存储弹层由 SettingsStorageContent 呈现：操作行外套透明
      // Material，不再触发「ListTile background color or ink splashes may
      // be invisible」断言，因此直接断言无异常（原 FlutterError 拦截
      // 已移除）。存储统计 IO 在 fake async 下悬挂，subtitle 停留
      // 「计算中...」。
      await tester.pumpAndSettle();

      expect(find.text('用户数据管理'), findsOneWidget);
      expect(find.text('清理无用图片 (深度清理)'), findsOneWidget);
      expect(find.text('立即清理缓存'), findsOneWidget);
      expect(find.text('计算中...'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('检测更新：网络失败后展示失败反馈并恢复状态', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpSettings(tester, syncProvider: syncProvider);

      final updateEntry = find.text('检测更新');
      await tester.scrollUntilVisible(updateEntry, 300);
      await tester.ensureVisible(updateEntry);
      await tester.pumpAndSettle();
      expect(find.text('点击检查新版本'), findsOneWidget);

      await tester.tap(updateEntry);
      // flutter_test 的 HttpOverrides mock 让 http.get 立即返回 400，
      // 失败链路在微任务内完成：loading 态不跨帧渲染，SnackBar 入场
      // 需要两次 pump。
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('检测更新失败，请检查网络'), findsOneWidget);
      expect(find.text('检测中...'), findsNothing);
      // 已记录当前版本号，subtitle 显示 v1.0.0
      expect(find.text('v1.0.0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
