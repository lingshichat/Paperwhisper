import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/config/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/diary/presentation/widgets/diary_empty_state.dart';
import 'package:paper_whisper_flutter/features/diary/presentation/widgets/diary_update_dialog.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_run_result.dart';
import 'package:paper_whisper_flutter/models/diary_entry.dart';
import 'package:paper_whisper_flutter/models/sync_config.dart';
import 'package:paper_whisper_flutter/models/sync_trust_snapshot.dart';
import 'package:paper_whisper_flutter/features/diary/presentation/diary_list_page.dart';
import 'package:paper_whisper_flutter/features/diary/presentation/widgets/diary_card.dart';
import 'package:paper_whisper_flutter/features/editor/presentation/editor_page.dart';
import 'package:paper_whisper_flutter/features/settings/presentation/settings_page.dart';
import 'package:paper_whisper_flutter/providers/diary_provider.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/providers/sync_provider.dart';
import 'package:paper_whisper_flutter/services/moment_service.dart';
import 'package:paper_whisper_flutter/services/payment_service.dart';
import 'package:paper_whisper_flutter/features/diary/presentation/widgets/book_flip_refresh_widget.dart';
import 'package:paper_whisper_flutter/app/shell/sidebar_widget.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_dialog.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/page_coordinator_test_fakes.dart';

/// DiaryListPage 重构前公共行为基线测试（阶段 4 测试 lane）。
///
/// 只通过公共 UI 与公开 Provider 契约断言，不触碰私有状态：
/// 覆盖 Windows/Android 360 空态与有数据布局（无 overflow）、
/// 1/2/3 列响应式结构、搜索过滤、月份目录跳转入口、打开编辑器
/// 导航链、下拉手动同步的 typed 结果、公告/更新入口边界与
/// dispose 清理。
///
/// seam 说明：
/// - `_checkAndroidPermissions` 以 `dart:io Platform.isAndroid` 判定，
///   测试宿主机恒为 false，权限说明弹窗分支不可达；已授权路径由
///   「无权限弹窗且无异常」的渲染断言覆盖，未授权/鸿蒙分支留待
///   协调器提取后的注入点。
/// - 远程更新检查走 flutter_test 的 HttpOverrides mock（http 立即返回
///   400），`_checkRemoteUpdate` 的 try/catch 吞掉异常，稳定呈现
///   「检查执行、无弹窗、无异常」边界；「发现新版本」弹窗需 200 响应，
///   本批不注入自建 HttpClient，留待 UpdateCheckCoordinator 单测。
/// - 公告检查（`_checkAndShowAnnouncement`）读 PackageInfo mock（版本
///   1.0.0）与 SharedPreferences 的 `last_run_version`：版本一致时跳过；
///   不一致时更新记录并加载 assets/version.json（随测试 bundle 打包，
///   rootBundle 可加载），弹「版本更新公告」对话框。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Directory> tempDirs;
  late PageCoordinatorFakeMomentService momentService;
  late PageCoordinatorFakeDiaryService diaryService;

  setUpAll(() {
    ThemeRegistry.init();
  });

  setUp(() {
    tempDirs = <Directory>[];
    // 默认与 PackageInfo mock 的版本（1.0.0）一致：跳过公告弹窗，
    // 版本变更场景在公告用例中单独覆盖。
    SharedPreferences.setMockInitialValues(<String, Object>{
      'last_run_version': '1.0.0',
    });
    installPageCoordinatorPlatformMocks();
    addTearDown(uninstallPageCoordinatorPlatformMocks);
    final dataDir = Directory.systemTemp.createTempSync('diary_list_page_test');
    tempDirs.add(dataDir);
    momentService = PageCoordinatorFakeMomentService(dataDir: dataDir);
    diaryService = PageCoordinatorFakeDiaryService(dataDir);
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

  /// 生成同月条目（日期升序；provider 后台加载会再按降序重排，
  /// 对「每行卡片数」的公开结构断言无影响）。
  List<DiaryEntry> seedEntries({int count = 4, int month = 5}) {
    return List<DiaryEntry>.generate(
      count,
      (i) => DiaryEntry(
        filename:
            '2026-${month.toString().padLeft(2, '0')}-'
            '${(i + 1).toString().padLeft(2, '0')}_seed.txt',
        dateString:
            '2026-${month.toString().padLeft(2, '0')}-'
            '${(i + 1).toString().padLeft(2, '0')}',
        title: '日记 ${i + 1}',
        content: '这是第 ${i + 1} 篇日记的内容，用于布局与导航验证。',
      ),
    );
  }

  Widget buildDiaryListApp({
    required PageCoordinatorSyncProvider syncProvider,
    required DiaryProvider diaryProvider,
    TargetPlatform? platform,
    Widget home = const DiaryListPage(),
  }) {
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
        theme: platform == null ? null : ThemeData(platform: platform),
        home: home,
      ),
    );
  }

  Future<void> pumpDiaryList(
    WidgetTester tester, {
    required PageCoordinatorSyncProvider syncProvider,
    List<DiaryEntry> seeds = const <DiaryEntry>[],
    TargetPlatform? platform,
    Widget home = const DiaryListPage(),
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

    diaryService.seedEntries(seeds);
    final diaryProvider = DiaryProvider(
      service: diaryService,
      initialEntries: seeds.isEmpty ? null : seeds,
    );
    await tester.pumpWidget(
      buildDiaryListApp(
        syncProvider: syncProvider,
        diaryProvider: diaryProvider,
        platform: platform,
        home: home,
      ),
    );
    // initState 异步链路（公告检查、远程更新检查、数据加载）均为
    // mock/微任务，postFrame 回调（目录自动跳转等）随帧推进。
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 消化 Sidebar（桌面常驻 / 移动端 Drawer 内）首次构建调度的 180ms
    // 非关键效果延迟（静默开启背景模糊 + 一言拉取）。统一在 helper 内
    // 消化，避免测试结束遗留 pending timer；后续构建因 static flag 已
    // 置位不再创建该 timer，此 pump 对无 Sidebar 场景亦无副作用。
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    // 收尾销毁整棵 widget 树：dispose 取消刷新动画/滚动监听器，并让
    // SnackBar 计时器随 ScaffoldMessenger 一并释放。
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  PageCoordinatorSyncProvider makeSyncProvider({
    SyncConfig? config,
    SyncTrustSnapshot? snapshot,
  }) {
    return DiaryListSyncProvider(
      config: config,
      snapshot: snapshot,
      momentService: momentService,
    );
  }

  /// 公开结构：每行（布局 Row）内 DiaryCard 数量，用于 1/2/3 列断言。
  List<int> cardsPerRow(WidgetTester tester) {
    final rows = find.descendant(
      of: find.byType(ScrollablePositionedList),
      matching: find.byType(Row),
    );
    return rows
        .evaluate()
        .map(
          (element) => find
              .descendant(
                of: find.byWidget(element.widget),
                matching: find.byType(DiaryCard),
              )
              .evaluate()
              .length,
        )
        .where((count) => count > 0)
        .toList();
  }

  /// 向下滚动 [ScrollablePositionedList] 直到 [target] 可见（公共手势，
  /// 不触碰私有 ItemScrollController），用于懒加载列表的全量访问验证。
  /// 列表只在视口内构建 item，首屏外的行需滚动拉入后才能断言。
  Future<void> scrollDiaryListUntilVisible(
    WidgetTester tester,
    Finder target,
  ) async {
    await tester.scrollUntilVisible(
      target,
      150,
      scrollable: find.descendant(
        of: find.byType(ScrollablePositionedList),
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 40,
    );
    await tester.pump();
  }

  /// 触发下拉刷新（BookFlipRefreshWidget 的 overscroll 手势）并让
  /// onRefresh 的异步链路完成；返回后刷新动画与 SnackBar 计时器仍
  /// 未消化，由调用方决定断言后调用 [drainRefreshTimers]。
  Future<void> triggerRefresh(WidgetTester tester) async {
    await tester.drag(find.byType(BookFlipRefreshWidget), const Offset(0, 240));
    await tester.pump(); // ScrollEnd → _startRefresh
    await tester.pump(); // onRefresh 微任务完成 → toast / 弹窗
  }

  /// 消化刷新组件的一次性 Timer（300ms 收起动画 ×2、800ms 完成停留、
  /// 300ms 复位延迟）与 SnackBar 的 2s 自动关闭计时。
  Future<void> drainRefreshTimers(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  group('DiaryListPage 双平台渲染', () {
    testWidgets('Windows 桌面渲染 Sidebar+头部+空态，无溢出无异常', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        platform: TargetPlatform.windows,
        physicalSize: const Size(1280, 720),
      );

      expect(find.byType(SidebarWidget), findsOneWidget);
      expect(find.text('点击翻阅目录'), findsOneWidget);
      expect(find.text('这里似乎落了一层灰，等待你来翻阅'), findsOneWidget);
      expect(find.text('去擦拭灰尘 (写一篇) →'), findsOneWidget);
      // 空态已拆分为参数化组件并由页面取色传入 props
      expect(find.byType(DiaryEmptyState), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Sidebar 设置入口：经 AppRoutes.settings() 打开设置页', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        platform: TargetPlatform.windows,
        physicalSize: const Size(1280, 720),
      );

      await tester.tap(
        find.descendant(
          of: find.byType(SidebarWidget),
          matching: find.text('设置'),
        ),
      );
      await tester.pump();
      // SlidePageRoute 700ms 转场完成
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();

      expect(find.byType(SettingsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Android 360x800 渲染头部+空态+FAB，无溢出无异常', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        platform: TargetPlatform.android,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      expect(find.text('点击翻阅目录'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('这里似乎落了一层灰，等待你来翻阅'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Windows 有数据布局渲染日记卡片，无溢出无异常', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        seeds: seedEntries(),
        platform: TargetPlatform.windows,
        physicalSize: const Size(1280, 720),
      );

      expect(find.byType(DiaryCard), findsNWidgets(4));
      expect(find.text('日记 1'), findsOneWidget);
      expect(find.textContaining('这是第 1 篇日记的内容'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Android 360 有数据布局渲染日记卡片，无溢出无异常', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        seeds: seedEntries(),
        platform: TargetPlatform.android,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      // ScrollablePositionedList 懒加载：首屏只构建视口内项（1 列布局
      // 约 3 张）。先断言首屏可见 >=3 张，再滚动到第 4 篇验证全量数据
      // 可访问，保持 4 条数据的覆盖，不把断言硬改为 3。
      expect(find.byType(DiaryCard), findsAtLeastNWidgets(3));
      await scrollDiaryListUntilVisible(tester, find.text('日记 4'));
      expect(find.text('日记 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('DiaryListPage 响应式列结构', () {
    testWidgets('360 宽为 1 列：每行 1 张卡片', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        seeds: seedEntries(count: 4),
        platform: TargetPlatform.android,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      // 懒加载列表首屏仅构建视口内行；先断言首屏可见行均为 1 列，
      // 再滚动到第 4 篇所在行，验证滚动后可见行仍为 1 列且第 4 篇
      // 可达（保留 4 行结构覆盖，不因懒加载丢断言）。
      final initialRows = cardsPerRow(tester);
      expect(initialRows, isNotEmpty);
      expect(initialRows.every((count) => count == 1), isTrue);
      await scrollDiaryListUntilVisible(tester, find.text('日记 4'));
      final scrolledRows = cardsPerRow(tester);
      expect(scrolledRows, isNotEmpty);
      expect(scrolledRows.every((count) => count == 1), isTrue);
      expect(find.text('日记 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1280 宽桌面为 2 列：每行 2 张卡片', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        seeds: seedEntries(count: 4),
        platform: TargetPlatform.windows,
        physicalSize: const Size(1280, 720),
      );

      expect(cardsPerRow(tester), <int>[2, 2]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1600 宽桌面为 3 列：每行 3 张卡片', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        seeds: seedEntries(count: 6),
        platform: TargetPlatform.windows,
        physicalSize: const Size(1600, 900),
      );

      expect(cardsPerRow(tester), <int>[3, 3]);
      expect(tester.takeException(), isNull);
    });
  });

  group('DiaryListPage 搜索', () {
    testWidgets('搜索过滤命中/无结果/清空恢复', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        seeds: <DiaryEntry>[
          DiaryEntry(
            filename: '2026-05-01_apple.txt',
            dateString: '2026-05-01',
            title: '苹果的回忆',
            content: '今天吃了苹果。',
          ),
          DiaryEntry(
            filename: '2026-05-02_banana.txt',
            dateString: '2026-05-02',
            title: '香蕉的回忆',
            content: '今天吃了香蕉。',
          ),
        ],
        platform: TargetPlatform.android,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );
      expect(find.text('苹果的回忆'), findsOneWidget);
      expect(find.text('香蕉的回忆'), findsOneWidget);

      // 打开搜索（标题栏内搜索按钮；抽屉 Sidebar 另有搜索框，需限定）
      final searchIcon = find.descendant(
        of: find.byKey(const ValueKey('title_bar')),
        matching: find.byIcon(Icons.search),
      );
      await tester.tap(searchIcon);
      await tester.pumpAndSettle();

      final searchField = find.descendant(
        of: find.byKey(const ValueKey('search_bar')),
        matching: find.byType(TextField),
      );
      await tester.enterText(searchField, '苹果');
      await tester.pumpAndSettle();

      expect(find.text('苹果的回忆'), findsOneWidget);
      expect(find.text('香蕉的回忆'), findsNothing);

      // 无命中 → 搜索空态
      await tester.enterText(searchField, '不存在的关键词');
      await tester.pumpAndSettle();
      expect(find.textContaining('没有找到关于'), findsOneWidget);

      // 返回 → 清空搜索，恢复全部卡片
      final backIcon = find.descendant(
        of: find.byKey(const ValueKey('search_bar')),
        matching: find.byIcon(Icons.arrow_back),
      );
      await tester.tap(backIcon);
      await tester.pumpAndSettle();

      expect(find.text('苹果的回忆'), findsOneWidget);
      expect(find.text('香蕉的回忆'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('DiaryListPage 目录跳转入口', () {
    testWidgets('初始月份自动定位 + 点击标题打开目录并按月份跳转', (tester) async {
      final syncProvider = makeSyncProvider();
      final seeds = <DiaryEntry>[
        DiaryEntry(
          filename: '2026-01-15_jan.txt',
          dateString: '2026-01-15',
          title: '一月的日记',
          content: '新年第一篇。',
        ),
        ...seedEntries(count: 2, month: 5),
      ];
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        seeds: seeds,
        platform: TargetPlatform.android,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
        home: const DiaryListPage(initialYear: 2026, initialMonth: 5),
      );

      // 初始定位到 5 月（2026_5 存在，跳转无异常）
      expect(find.text('一月的日记'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 目录入口：点击标题副文案
      await tester.tap(find.text('点击翻阅目录'));
      await tester.pumpAndSettle();
      expect(find.text('2026 目录'), findsOneWidget);

      // 点击 1 月 → 返回列表并定位（2026_1 存在）
      await tester.tap(find.text('1 月'));
      await tester.pumpAndSettle();

      expect(find.text('2026 目录'), findsNothing);
      expect(find.byType(DiaryListPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('DiaryListPage 打开编辑器导航链', () {
    testWidgets('FAB 新建：进入编辑器并可返回列表', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        platform: TargetPlatform.android,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(); // LetterFoldPageRoute 1600ms

      expect(find.byType(EditorPage), findsOneWidget);
      expect(find.text('在此输入标题...'), findsOneWidget);

      // 返回列表
      await tester.tap(find.text('返回列表'));
      await tester.pumpAndSettle();

      expect(find.byType(EditorPage), findsNothing);
      expect(find.byType(DiaryListPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('点击卡片：展开动画进入编辑器并展示日记内容', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        seeds: seedEntries(count: 1),
        platform: TargetPlatform.android,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      await tester.tap(find.byType(DiaryCard).first);
      await tester.pumpAndSettle(); // UnfoldPageRoute 800ms + 动画完成回调

      expect(find.byType(EditorPage), findsOneWidget);
      // 标题断言限定 EditorPage 子树：路由动画完成后前一页卡片标题
      // 仍可能留在 widget 树中，避免 find.text('日记 1') 命中多个。
      expect(
        find.descendant(
          of: find.byType(EditorPage),
          matching: find.text('日记 1'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('这是第 1 篇日记的内容'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('DiaryListPage 下拉手动同步', () {
    testWidgets('未配置同步：下拉提示前往配置（WebDAV 弹窗）', (tester) async {
      final syncProvider = makeSyncProvider(); // 默认 config 未启用
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        platform: TargetPlatform.android,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      await triggerRefresh(tester);

      expect(find.text('尚未配置同步'), findsOneWidget);
      expect(find.byType(SkeuomorphicDialog), findsOneWidget);

      // 稍后再说 → 关闭弹窗（pop 动画完成后再断言）
      await tester.tap(find.text('稍后再说'));
      await tester.pumpAndSettle();
      expect(find.text('尚未配置同步'), findsNothing);
      await drainRefreshTimers(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('手动同步成功（无变更）：提示「同步完成 (无变更)」', (tester) async {
      final syncProvider = makeSyncProvider(
        config: SyncConfig(
          enabled: true,
          autoSync: true,
          serverUrl: 'https://dav.example.com/',
          username: 'demo',
          password: 'secret',
        ),
      );
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        platform: TargetPlatform.android,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      await triggerRefresh(tester);

      expect(find.text('同步完成 (无变更)'), findsOneWidget);
      expect(syncProvider.syncCallCount, 1);
      await drainRefreshTimers(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('手动同步成功（有变更）：提示分类统计', (tester) async {
      final syncProvider =
          DiaryListSyncProvider(
              config: SyncConfig(
                enabled: true,
                autoSync: true,
                serverUrl: 'https://dav.example.com/',
                username: 'demo',
                password: 'secret',
              ),
              momentService: momentService,
            )
            ..syncResultBuilder = () => const SyncRunResult(
              status: SyncRunStatus.success,
              processedDiaries: 1,
              processedMoments: 2,
              processedImages: 3,
              processedAudio: 4,
            );
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        platform: TargetPlatform.android,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      await triggerRefresh(tester);

      expect(find.text('已同步: 1篇日记, 2篇随心记\n3张图片, 4条语音'), findsOneWidget);
      await drainRefreshTimers(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('手动同步失败：提示失败原因', (tester) async {
      final syncProvider =
          DiaryListSyncProvider(
              config: SyncConfig(
                enabled: true,
                autoSync: true,
                serverUrl: 'https://dav.example.com/',
                username: 'demo',
                password: 'secret',
              ),
              momentService: momentService,
            )
            ..syncResultBuilder = () => const SyncRunResult(
              status: SyncRunStatus.failed,
              failureMessage: 'WebDAV 连接被拒绝',
            );
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        platform: TargetPlatform.android,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      await triggerRefresh(tester);

      expect(find.text('WebDAV 连接被拒绝'), findsOneWidget);
      await drainRefreshTimers(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('手动同步 pending：提示待同步数量', (tester) async {
      final syncProvider =
          DiaryListSyncProvider(
              config: SyncConfig(
                enabled: true,
                autoSync: true,
                serverUrl: 'https://dav.example.com/',
                username: 'demo',
                password: 'secret',
              ),
              momentService: momentService,
            )
            ..syncResultBuilder = () => const SyncRunResult(
              status: SyncRunStatus.pending,
              pendingCount: 2,
            );
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        platform: TargetPlatform.android,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      await triggerRefresh(tester);

      expect(find.text('尚有 2 项待同步'), findsOneWidget);
      await drainRefreshTimers(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('DiaryListPage 公告与更新入口边界', () {
    testWidgets('版本一致：无公告/更新弹窗且无异常', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        platform: TargetPlatform.windows,
        physicalSize: const Size(1280, 720),
      );

      // 远程更新检查（http 400 失败路径）与公告检查（版本一致跳过）
      // 都不产生弹窗
      expect(find.byType(SkeuomorphicDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('版本变更：记录新版本并展示公告弹窗，可关闭', (tester) async {
      // 上次运行版本 0.9.0 < 当前 1.0.0 → 触发公告
      SharedPreferences.setMockInitialValues(<String, Object>{
        'last_run_version': '0.9.0',
      });
      final syncProvider = makeSyncProvider();
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        platform: TargetPlatform.android,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );
      // 公告弹窗在 postFrame 回调中 push，需额外帧构建路由。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 公告弹窗：由提取出的 DiaryUpdateDialog 组件承载（内部仍是
      // SkeuomorphicDialog），标题来自 assets/version.json 的 title
      expect(find.byType(DiaryUpdateDialog), findsOneWidget);
      expect(find.byType(SkeuomorphicDialog), findsOneWidget);
      expect(find.text('开启体验'), findsOneWidget);
      expect(find.textContaining('感谢您与纸语一同成长'), findsOneWidget);

      // 版本已记录，后续不再重复弹
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_run_version'), '1.0.0');

      // 关闭公告
      await tester.tap(find.text('开启体验'));
      await tester.pumpAndSettle();
      expect(find.byType(SkeuomorphicDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('DiaryListPage dispose', () {
    testWidgets('页面销毁后无异常（滚动监听器清理）', (tester) async {
      final syncProvider = makeSyncProvider();
      await pumpDiaryList(
        tester,
        syncProvider: syncProvider,
        seeds: seedEntries(),
        platform: TargetPlatform.android,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

/// DiaryListPage 手动同步用例的 SyncProvider 替身：允许注入 typed 结果。
class DiaryListSyncProvider extends PageCoordinatorSyncProvider {
  DiaryListSyncProvider({
    super.config,
    super.snapshot,
    required super.momentService,
  });

  /// 非 null 时 [sync] 返回该结果；否则返回成功（无变更）。
  SyncRunResult Function()? syncResultBuilder;

  @override
  Future<SyncRunResult> sync({bool isAuto = false}) async {
    syncCallCount++;
    return syncResultBuilder?.call() ??
        const SyncRunResult(status: SyncRunStatus.success);
  }
}
