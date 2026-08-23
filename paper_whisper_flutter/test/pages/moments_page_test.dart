import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/app/shell/sidebar_widget.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/moments/application/moment_index.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_config.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_trust_snapshot.dart';
import 'package:paper_whisper_flutter/features/diary/presentation/diary_list_page.dart';
import 'package:paper_whisper_flutter/features/moments/presentation/moments_page.dart';
import 'package:paper_whisper_flutter/features/diary/application/diary_provider.dart';
import 'package:paper_whisper_flutter/features/settings/application/settings_provider.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_provider.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment_service.dart';
import 'package:paper_whisper_flutter/features/premium/data/payment_service.dart';
import 'package:paper_whisper_flutter/features/moments/presentation/widgets/moment_input_widget.dart';
import 'package:paper_whisper_flutter/features/moments/presentation/widgets/ruler_date_picker.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/page_coordinator_test_fakes.dart';
import '../support/sync_test_fakes.dart';

/// MomentsPage 重构前行为刻画测试（阶段 4 测试 lane 第一批）。
///
/// 只通过公共 UI 与公开 Provider 契约断言，不触碰私有状态：
/// 覆盖双平台渲染（桌面瀑布流 / 移动 Ruler+PageView）、空态、
/// 按日期展示与搜索过滤、ruler↔page 公共交互、发送成功与失败、
/// 保存后 SyncUiCoordinator 三分支、删除刷新、聚合入口与
/// dispose 清理。
///
/// seam 说明：
/// - 更新检查（`_checkUpdate`）在 initState postFrame 触发，页面内 2s
///   延迟 + 真实网络请求（fake async 下悬挂，10s 超时失败）。每个
///   测试在 pump 阶段统一推进 3s 消化该延迟与失败链路的 timer，避免
///   pending timer 报错；检查委托 UpdateCheckCoordinator（purpose 级
///   会话去重 + 失败回滚，语义等价原 static `_hasCheckedUpdate`），
///   测试不断言更新弹窗行为。
/// - 免费额度（`PaymentService.canUseProFeatures` 恒为 true，硬编码）
///   使「当日 3 条」限制分支在 widget 层不可达；额度决策已下沉到
///   MomentSendPipeline（seam 注入），由
///   `test/features/moments/moment_send_pipeline_test.dart` 覆盖
///   quota/success/failure 三分支。
/// - 发送失败路径：MomentSendPipeline 返回 typed failure，页面展示
///   失败 Toast；重构前该路径是无 catch 的未处理异步错误，无法用
///   takeException 稳定捕获，故此前无独立用例。
/// - 带图片的 moment 依赖真实文件 IO（fake async 下悬挂），图片场景
///   只断言渲染无异常，不断言图片解码结果。
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
    final dataDir = Directory.systemTemp.createTempSync('moments_page_test');
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

  Widget buildMomentsApp({
    required PageCoordinatorSyncProvider syncProvider,
    TargetPlatform? platform,
  }) {
    final diaryService = FakeDiaryService(
      Directory.systemTemp.createTempSync('moments_diary'),
    );
    tempDirs.add(diaryService.rootDir);
    final diaryProvider = DiaryProvider(service: diaryService);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProvider<DiaryProvider>.value(value: diaryProvider),
        ChangeNotifierProvider<SyncProvider>.value(value: syncProvider),
        Provider<MomentService>.value(value: momentService),
        ChangeNotifierProvider<PaymentService>.value(value: PaymentService()),
      ],
      child: MaterialApp(
        theme: AppTheme.getThemeData(
          AppTheme.themeDefault,
        ).copyWith(platform: platform),
        home: const MomentsPage(),
      ),
    );
  }

  Future<void> pumpMomentsPage(
    WidgetTester tester, {
    required PageCoordinatorSyncProvider syncProvider,
    TargetPlatform? platform = TargetPlatform.android,
    Size? physicalSize,
    double devicePixelRatio = 1.0,
  }) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    if (physicalSize != null) {
      tester.view.physicalSize = physicalSize;
      tester.view.devicePixelRatio = devicePixelRatio;
    }

    await tester.pumpWidget(
      buildMomentsApp(syncProvider: syncProvider, platform: platform),
    );
    // initState 异步加载（fake 立即完成）+ 输入区高度 postFrame 上报
    await tester.pump();
    await tester.pump();

    // 必须在测试体内消化 initState postFrame 启动的一次性 timer：
    // 更新检查 2s 延迟（_checkUpdate 的 Future.delayed 无法在 dispose
    // 时取消）。http 在 flutter_test 的 mock 下立即返回 400，失败链路
    // 无后续 timer。addTearDown 在
    // _verifyInvariants 之后才执行，来不及清理 pending timer，故不能
    // 依赖 teardown 推进时间。
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    // 收尾：销毁整棵 widget 树，释放 SnackBar / 动画计时器（dispose
    // 会取消这些 timer，作为防御性清理）。
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

  Moment momentAt(DateTime date, String content) {
    return Moment(
      uuid: 'uuid_${content.hashCode}',
      content: content,
      images: const [],
      createdAt: date,
    );
  }

  // 注：测试用例体内不能声明 getter，用函数返回相对日期
  DateTime todayDate() => DateTime.now();
  DateTime yesterdayDate() => DateTime.now().subtract(const Duration(days: 1));
  DateTime tomorrowDate() => DateTime.now().add(const Duration(days: 1));

  group('MomentsPage 双平台渲染', () {
    testWidgets('移动端（Android 360x800）渲染 Ruler+输入区+空态', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      // AppBar 与未打开的 Drawer（Sidebar 导航项）都可能出现「随心记」，
      // 这里只锚定布局结构元素。
      expect(find.byType(RulerDatePicker), findsOneWidget);
      expect(find.byType(MomentInputWidget), findsOneWidget);
      // 今天无记录 → 空态文案
      expect(find.text('这一天不仅是空白，更是无限可能'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('桌面端（Windows 1280x720）渲染瀑布流与输入岛', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        platform: TargetPlatform.windows,
        physicalSize: const Size(1280, 720),
      );

      // 「随心记」同时出现在 Sidebar 导航与桌面头部，不做唯一性断言
      expect(find.text('随心记'), findsWidgets);
      expect(
        find.byKey(const ValueKey('desktop_generate_btn')),
        findsOneWidget,
      );
      expect(find.byType(MomentInputWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('页面销毁后无异常（输入/卡片组件 dispose 清理）', (tester) async {
      momentService.seedMoments(<Moment>[
        momentAt(todayDate(), 'dispose 测试内容'),
      ]);
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('MomentsPage 数据与搜索', () {
    testWidgets('按日期展示：今天的随心记可见，昨天的不可见', (tester) async {
      momentService.seedMoments(<Moment>[
        momentAt(todayDate(), '今天的内容'),
        momentAt(yesterdayDate(), '昨天的内容'),
      ]);
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      expect(find.text('今天的内容'), findsOneWidget);
      expect(find.text('昨天的内容'), findsNothing);
      expect(
        find.ancestor(
          of: find.text('今天的内容'),
          matching: find.byType(BackdropGroup),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('搜索过滤：命中内容展示，无结果展示空态', (tester) async {
      momentService.seedMoments(<Moment>[
        momentAt(todayDate(), '苹果的回忆'),
        momentAt(todayDate(), '香蕉的回忆'),
      ]);
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      // 打开搜索（AppBar 内 SkeuomorphicSearchBar；Sidebar 在未打开的
      // Drawer 中也有搜索框，需限定作用域）
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      final searchField = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(TextField),
      );
      await tester.enterText(searchField, '苹果');
      await tester.pumpAndSettle();

      expect(find.text('苹果的回忆'), findsOneWidget);
      expect(find.text('香蕉的回忆'), findsNothing);
      expect(
        find.ancestor(
          of: find.text('苹果的回忆'),
          matching: find.byType(BackdropGroup),
        ),
        findsOneWidget,
      );

      // 无命中 → 空态
      await tester.enterText(searchField, '不存在的关键词');
      await tester.pumpAndSettle();
      expect(find.text('没有找到相关记忆...'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('MomentsPage ruler 与 page 联动', () {
    testWidgets('Ruler 滚动后日期联动，今日内容切换为相邻日期', (tester) async {
      momentService.seedMoments(<Moment>[
        momentAt(todayDate(), '今天的内容'),
        momentAt(yesterdayDate(), '昨天的内容'),
        momentAt(tomorrowDate(), '明天的内容'),
      ]);
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );
      expect(find.text('今天的内容'), findsOneWidget);

      // Ruler 是 RotatedBox(-90°) 包裹的横向 ListWheelScrollView：
      // 水平拖拽 ±1 项即切换日期，方向由吸附决定；无论切到昨天还是
      // 明天，今日内容都应离开视口。
      await tester.drag(find.byType(RulerDatePicker), const Offset(70, 0));
      await tester.pumpAndSettle();

      expect(find.text('今天的内容'), findsNothing);
      final hasAdjacent =
          find.text('昨天的内容').evaluate().isNotEmpty ||
          find.text('明天的内容').evaluate().isNotEmpty;
      expect(hasAdjacent, isTrue, reason: 'ruler 拖拽应联动展示相邻日期内容');
      expect(tester.takeException(), isNull);
    });

    testWidgets('PageView 翻页后日期联动，今日内容切换为相邻日期', (tester) async {
      momentService.seedMoments(<Moment>[
        momentAt(todayDate(), '今天的内容'),
        momentAt(yesterdayDate(), '昨天的内容'),
        momentAt(tomorrowDate(), '明天的内容'),
      ]);
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );
      expect(find.text('今天的内容'), findsOneWidget);

      // 向左翻一页（明天）。ScrollEnd 后 _onDateChanged 同步选中日期与 Ruler。
      await tester.drag(find.byType(PageView), const Offset(-360, 0));
      await tester.pumpAndSettle();

      expect(find.text('明天的内容'), findsOneWidget);
      expect(find.text('今天的内容'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('MomentsPage 发送与保存后同步', () {
    testWidgets('发送成功（未启用同步）：保存并提示「记录已保存」', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      // 输入区 TextField（Sidebar 在未打开的 Drawer 中也有搜索框，需限定）
      final inputField = find.descendant(
        of: find.byType(MomentInputWidget),
        matching: find.byType(TextField),
      );
      await tester.enterText(inputField, '新发送的随心记');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(momentService.saveCallCount, 1);
      expect(momentService.lastSavedMoment!.content, '新发送的随心记');
      expect(find.text('记录已保存'), findsOneWidget);
      // 保存后刷新列表，新内容出现在今日
      expect(find.text('新发送的随心记'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('启用自动同步：提示准备同步并触发 requestAutoSync', (tester) async {
      final syncProvider = makeSyncProvider(
        config: SyncConfig(
          enabled: true,
          autoSync: true,
          serverUrl: 'https://dav.example.com/',
          username: 'demo',
          password: 'secret',
        ),
      );
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      final inputField = find.descendant(
        of: find.byType(MomentInputWidget),
        matching: find.byType(TextField),
      );
      await tester.enterText(inputField, '自动同步内容');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('记录已保存，准备同步...'), findsOneWidget);
      expect(syncProvider.requestAutoSyncCallCount, 1);
      expect(syncProvider.refreshTrustSnapshotCallCount, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('未启用自动同步但有待同步项：提示待同步数量', (tester) async {
      final syncProvider = makeSyncProvider(
        config: SyncConfig(
          enabled: true,
          autoSync: false,
          serverUrl: 'https://dav.example.com/',
          username: 'demo',
          password: 'secret',
        ),
        snapshot: const SyncTrustSnapshot(
          state: SyncTrustState.localChangesPending,
          pendingDiaryCount: 3,
          pendingMomentCount: 0,
          pendingImageCount: 0,
          pendingAudioCount: 0,
        ),
      );
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      final inputField = find.descendant(
        of: find.byType(MomentInputWidget),
        matching: find.byType(TextField),
      );
      await tester.enterText(inputField, '待同步内容');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('已保存，尚有 3 项待同步'), findsOneWidget);
      expect(syncProvider.requestAutoSyncCallCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('发送失败（保存抛错）：typed 失败反馈，不崩溃且输入区可用', (tester) async {
      momentService.saveError = Exception('磁盘写入失败');
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      final inputField = find.descendant(
        of: find.byType(MomentInputWidget),
        matching: find.byType(TextField),
      );
      await tester.enterText(inputField, '会失败的内容');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // 尝试保存过一次，但失败内容未进入列表
      expect(momentService.saveCallCount, 1);
      expect(find.text('发送失败，请稍后重试'), findsOneWidget);
      expect(find.text('会失败的内容'), findsNothing);
      // 无未处理异步异常（重构前该路径直接使 widget 测试失败）
      expect(tester.takeException(), isNull);
      // 输入区仍可用，可继续输入重试
      await tester.enterText(inputField, '重试内容');
      await tester.pump();
      expect(find.text('重试内容'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('MomentsPage 删除与聚合', () {
    testWidgets('删除需确认：确认后删除、刷新并提示', (tester) async {
      final target = Moment(
        uuid: 'fixed-uuid-delete',
        content: '待删除内容',
        images: const [],
        createdAt: todayDate(),
      );
      momentService.seedMoments(<Moment>[target]);
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );
      expect(find.text('待删除内容'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('删除随心记'), findsOneWidget);

      await tester.tap(find.text('移入回收站'));
      await tester.pumpAndSettle();

      expect(momentService.deleteCallCount, 1);
      expect(momentService.lastDeletedUuid, 'fixed-uuid-delete');
      expect(find.text('待删除内容'), findsNothing);
      expect(find.text('已移入回收站'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('聚合入口：生成后导出摘要并跳转日记列表', (tester) async {
      momentService.seedMoments(<Moment>[momentAt(todayDate(), '聚合素材')]);
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      await tester.tap(find.byKey(const ValueKey('mobile_generate_btn')));
      await tester.pumpAndSettle();
      expect(find.text('生成长文日记'), findsOneWidget);

      // 对话框内输入标题（页面输入区另有 TextField，需限定作用域）
      final dialogField = find.descendant(
        of: find.byType(SkeuomorphicDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogField, '今日份的日记');
      await tester.tap(find.text('生成'));
      await tester.pumpAndSettle();

      expect(momentService.exportCallCount, 1);
      expect(find.text('生成成功，正在跳转...'), findsOneWidget);
      // pushReplacement 到日记列表页（其更新检查 timer 由 tearDown 消化）
      expect(find.byType(DiaryListPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('MomentsPage 顶栏月历', () {
    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

    Future<void> openCalendar(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('moments_date_title')));
      await tester.pumpAndSettle();
    }

    Future<void> revealMonthOf(WidgetTester tester, DateTime date) async {
      final now = DateTime.now();
      var cursor = DateTime(now.year, now.month);
      final target = DateTime(date.year, date.month);
      while (cursor.isAfter(target)) {
        await tester.tap(find.byIcon(Icons.chevron_left));
        await tester.pumpAndSettle();
        cursor = DateTime(cursor.year, cursor.month - 1);
      }
      while (cursor.isBefore(target)) {
        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pumpAndSettle();
        cursor = DateTime(cursor.year, cursor.month + 1);
      }
    }

    DateTime firstEmptyDay(DateTime month, List<DateTime> occupied) {
      for (var day = 1; day <= 28; day++) {
        final candidate = DateTime(month.year, month.month, day);
        final hit = occupied.any(
          (o) =>
              o.year == candidate.year &&
              o.month == candidate.month &&
              o.day == candidate.day,
        );
        if (!hit) return candidate;
      }
      throw StateError('当月找不到无记录日');
    }

    testWidgets('默认无月历，点标题展开再点收起', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      expect(
        find.byKey(const ValueKey('moments_month_calendar')),
        findsNothing,
      );

      await openCalendar(tester);
      expect(
        find.byKey(const ValueKey('moments_month_calendar')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('moments_date_title')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('moments_month_calendar')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('占用标记 Key：昨天有点、无记录日无点', (tester) async {
      final today = dateOnly(todayDate());
      final yesterday = dateOnly(yesterdayDate());
      momentService.seedMoments(<Moment>[
        momentAt(today, '今天的内容'),
        momentAt(yesterday, '昨天的内容'),
      ]);
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      await openCalendar(tester);
      await revealMonthOf(tester, yesterday);

      expect(
        find.byKey(
          ValueKey('moments_cal_mark_${MomentIndex.dayKey(yesterday)}'),
        ),
        findsOneWidget,
      );
      final empty = firstEmptyDay(DateTime(yesterday.year, yesterday.month), [
        today,
        yesterday,
      ]);
      expect(
        find.byKey(ValueKey('moments_cal_mark_${MomentIndex.dayKey(empty)}')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('点昨天格子：列表与尺子 selectedItem 对齐，月历收起', (tester) async {
      final today = dateOnly(todayDate());
      final yesterday = dateOnly(yesterdayDate());
      momentService.seedMoments(<Moment>[
        momentAt(today, '今天的内容'),
        momentAt(yesterday, '昨天的内容'),
      ]);
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      await openCalendar(tester);
      await revealMonthOf(tester, yesterday);
      await tester.tap(
        find.byKey(ValueKey('moments_cal_${MomentIndex.dayKey(yesterday)}')),
      );
      await tester.pumpAndSettle();

      expect(find.text('昨天的内容'), findsOneWidget);
      expect(find.text('今天的内容'), findsNothing);
      expect(
        find.byKey(const ValueKey('moments_month_calendar')),
        findsNothing,
      );

      final ruler = tester.widget<RulerDatePicker>(
        find.byType(RulerDatePicker),
      );
      final now = DateTime.now();
      final start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 365 * 5));
      expect(
        ruler.controller!.selectedItem,
        yesterday.difference(start).inDays,
      );
      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(
        pageView.controller!.page!.round(),
        yesterday.difference(start).inDays,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('点已选日只收起月历，不换日', (tester) async {
      momentService.seedMoments(<Moment>[momentAt(todayDate(), '今天的内容')]);
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      await openCalendar(tester);
      final today = dateOnly(todayDate());
      await tester.tap(
        find.byKey(ValueKey('moments_cal_${MomentIndex.dayKey(today)}')),
      );
      await tester.pumpAndSettle();

      expect(find.text('今天的内容'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('moments_month_calendar')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('移动搜索开启后标题打不开月历，已打开则收起且退出搜索不弹开', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      await openCalendar(tester);
      expect(
        find.byKey(const ValueKey('moments_month_calendar')),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('moments_month_calendar')),
        findsNothing,
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('moments_month_calendar')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('moments_date_title')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('桌面侧栏搜索 guard：有 query 时点标题不打开，已打开则收起', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        platform: TargetPlatform.windows,
        physicalSize: const Size(1280, 720),
      );

      await openCalendar(tester);
      expect(
        find.byKey(const ValueKey('moments_month_calendar')),
        findsOneWidget,
      );

      final sidebarSearch = find.descendant(
        of: find.byType(SidebarWidget),
        matching: find.byType(TextField),
      );
      await tester.enterText(sidebarSearch, '侧栏关键词');
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('moments_month_calendar')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('moments_date_title')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('moments_month_calendar')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('输入条聚焦时收起月历', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      await openCalendar(tester);
      expect(
        find.byKey(const ValueKey('moments_month_calendar')),
        findsOneWidget,
      );

      final inputField = find.descendant(
        of: find.byType(MomentInputWidget),
        matching: find.byType(TextField),
      );
      await tester.tap(inputField.first);
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('moments_month_calendar')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('键盘从收起到弹出时收起月历', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      await openCalendar(tester);
      expect(
        find.byKey(const ValueKey('moments_month_calendar')),
        findsOneWidget,
      );

      addTearDown(tester.view.resetViewInsets);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('moments_month_calendar')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Android 360×800 展开无溢出，日历在 AppBar 下方', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      await openCalendar(tester);
      expect(tester.takeException(), isNull);

      final appBar = tester.getRect(find.byType(AppBar));
      final cal = tester.getRect(
        find.byKey(const ValueKey('moments_month_calendar')),
      );
      expect(cal.top, closeTo(appBar.bottom, 1.0));
    });

    testWidgets('Windows 1280×720 可展开且尺子仍可点', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        platform: TargetPlatform.windows,
        physicalSize: const Size(1280, 720),
      );

      await openCalendar(tester);
      expect(
        find.byKey(const ValueKey('moments_month_calendar')),
        findsOneWidget,
      );
      expect(find.byType(RulerDatePicker), findsOneWidget);
      expect(find.byType(RulerDatePicker).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('桌面跳到空的非今天显示「这天没有留下记录」', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        platform: TargetPlatform.windows,
        physicalSize: const Size(1280, 720),
      );
      expect(find.text('这一天不仅是空白，更是无限可能'), findsOneWidget);

      final yesterday = dateOnly(yesterdayDate());
      await openCalendar(tester);
      await revealMonthOf(tester, yesterday);
      await tester.tap(
        find.byKey(ValueKey('moments_cal_${MomentIndex.dayKey(yesterday)}')),
      );
      await tester.pumpAndSettle();

      expect(find.text('这天没有留下记录'), findsOneWidget);
      expect(find.text('这一天不仅是空白，更是无限可能'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('从今天跳 ≥90 天前：pump 后 page 已是目标 index', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      final today = dateOnly(todayDate());
      final target = today.subtract(const Duration(days: 90));
      await openCalendar(tester);
      await revealMonthOf(tester, target);
      await tester.tap(
        find.byKey(ValueKey('moments_cal_${MomentIndex.dayKey(target)}')),
      );
      await tester.pump();

      final start = today.subtract(const Duration(days: 365 * 5));
      final expected = target.difference(start).inDays;
      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.controller!.page!.round(), expected);
      final ruler = tester.widget<RulerDatePicker>(
        find.byType(RulerDatePicker),
      );
      expect(ruler.controller!.selectedItem, expected);
      expect(tester.takeException(), isNull);
    });

    testWidgets('日历打开时返回只收起日历，仍停在随心记页', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpMomentsPage(
        tester,
        syncProvider: syncProvider,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      await openCalendar(tester);
      expect(
        find.byKey(const ValueKey('moments_month_calendar')),
        findsOneWidget,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('moments_month_calendar')),
        findsNothing,
      );
      expect(find.byType(MomentsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
