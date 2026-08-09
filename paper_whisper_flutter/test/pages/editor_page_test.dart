import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:paper_whisper_flutter/config/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/models/diary_entry.dart';
import 'package:paper_whisper_flutter/models/sync_config.dart';
import 'package:paper_whisper_flutter/models/sync_trust_snapshot.dart';
import 'package:paper_whisper_flutter/pages/editor_page.dart';
import 'package:paper_whisper_flutter/providers/diary_provider.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/providers/sync_provider.dart';
import 'package:paper_whisper_flutter/widgets/skeuomorphic_date_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/editor_test_fakes.dart';

/// EditorPage 重构前行为刻画测试（阶段 3 测试 lane 第一批）。
///
/// 只通过公共 UI 与公开 Provider 契约断言，不触碰私有状态：
/// 覆盖新建/已有日记渲染、200 字 preview 与长内容、标题/正文/元信息
/// 交互、草稿恢复、debounce 与切后台自动保存、保存/删除/返回确认、
/// 同步反馈三分支、dispose 与导出入口。
///
/// 导出说明：完整导出链路（分块计算、RepaintBoundary 捕获、拼接、文件
/// 写入）已随阶段 3 提取为 DiaryExportService，行为由
/// test/features/editor/diary_export_service_test.dart 单测覆盖；本页
/// widget 测试仍受 fake async 下 GoogleFonts.pendingFonts / toImage
/// 悬挂限制，只稳定刻画导出入口与长图生成覆盖层样式。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Directory> tempDirs;

  setUpAll(() async {
    ThemeRegistry.init();
    // SkeuomorphicDatePicker 使用 DateFormat.yMMMM('zh_CN')，需要
    // 先初始化 locale 符号数据，否则打开日期选择器会抛
    // "Locale data has not been initialized"。
    await initializeDateFormatting('zh_CN');
  });

  setUp(() {
    tempDirs = <Directory>[];
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // 注意：不设置 GoogleFonts.config.allowRuntimeFetching = false。
    // 字体未随应用打包时，false 会让首次 GoogleFonts.notoSerifSc() 的
    // 异步加载立即抛错并成为未处理异步异常，导致所有用例失败；保持
    // 默认 true 时加载 future 在测试 fake async 下静默悬挂，不报错。
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

  // 构造服务替身：返回 record，供各测试取用 diaryService / syncProvider。
  ({EditorFakeDiaryService diaryService, EditorTestSyncProvider syncProvider})
  createHarness({
    SyncConfig? syncConfig,
    SyncTrustSnapshot? snapshot,
    Object? saveError,
  }) {
    final rootDir = Directory.systemTemp.createTempSync('editor_page_test');
    tempDirs.add(rootDir);
    final diaryService = EditorFakeDiaryService(rootDir);
    if (saveError != null) {
      diaryService.saveError = saveError;
    }
    final syncProvider = EditorTestSyncProvider(
      config: syncConfig ?? SyncConfig(),
      snapshot:
          snapshot ?? const SyncTrustSnapshot(state: SyncTrustState.notEnabled),
      tempDirs: tempDirs,
    );
    return (diaryService: diaryService, syncProvider: syncProvider);
  }

  // 将 EditorPage 推入可 pop 的路由，并统一注册收尾销毁（取消所有
  // 页面 Timer，避免跨测试 pending timer / static dialog lock 泄漏）。
  Future<void> pumpEditorPage(
    WidgetTester tester, {
    required EditorFakeDiaryService diaryService,
    required EditorTestSyncProvider syncProvider,
    DiaryEntry? entry,
    bool lazyLoad = false,
    bool usePreviewMode = false,
    void Function(VoidCallback)? onContentReady,
  }) async {
    final diaryProvider = DiaryProvider(
      service: diaryService,
      initialEntries: entry == null ? null : <DiaryEntry>[entry],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>(
            create: (_) => SettingsProvider(),
          ),
          ChangeNotifierProvider<DiaryProvider>.value(value: diaryProvider),
          ChangeNotifierProvider<SyncProvider>.value(value: syncProvider),
        ],
        child: const MaterialApp(home: Scaffold(body: SizedBox())),
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => EditorPage(
          entry: entry,
          lazyLoad: lazyLoad,
          usePreviewMode: usePreviewMode,
          onContentReady: onContentReady,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 收尾销毁整棵 widget 树：dispose 会取消 debounce/自动保存 Timer，
    // 并让 SnackBar 计时器随 ScaffoldMessenger 一并释放。
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  group('EditorPage 基础渲染', () {
    testWidgets('新建编辑器以编辑态渲染标题/正文/导出/返回/元信息', (tester) async {
      final harness = createHarness();
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
      );

      expect(find.text('返回列表'), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
      expect(find.text('完成'), findsOneWidget);
      // 新建无删除入口
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      // 标题 + 正文两个输入框
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('在此输入标题...'), findsOneWidget);
      // 默认元信息：天气 SUNNY、心情 CALM、今天日期
      expect(find.text('SUNNY'), findsOneWidget);
      expect(find.text('CALM'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^\d{4}-\d{2}-\d{2}$')), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('已有日记以只读态初始化并保留元信息与标题', (tester) async {
      final harness = createHarness();
      final entry = DiaryEntry(
        filename: '2026-05-01_abc.txt',
        dateString: '2026-05-01',
        title: '我的第一篇',
        weather: WeatherType.rainy,
        mood: MoodType.excited,
        content: '今天开始写日记。\n第二行。',
      );
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
        entry: entry,
      );

      expect(find.text('我的第一篇'), findsOneWidget);
      expect(find.textContaining('今天开始写日记。'), findsOneWidget);
      expect(find.text('RAINY'), findsOneWidget);
      expect(find.text('EXCITED'), findsOneWidget);
      expect(find.text('2026-05-01'), findsOneWidget);
      // 只读态：显示编辑与删除入口，不显示保存按钮
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.text('完成'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('usePreviewMode 首屏只渲染前 200 字符，长文无异常', (tester) async {
      final harness = createHarness();
      final content = '${'A' * 200}${'B' * 300}';
      final entry = DiaryEntry(
        filename: '2026-05-01_abc.txt',
        dateString: '2026-05-01',
        title: '长文预览',
        content: content,
      );
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
        entry: entry,
        usePreviewMode: true,
      );

      expect(tester.takeException(), isNull);
      // 预览控制器只截取前 200 字符（全部为 A）
      expect(find.textContaining('A' * 200), findsOneWidget);
      expect(find.textContaining('BBB'), findsNothing);
    });

    testWidgets('超长日记（>3000 字符）走性能模式渲染无异常', (tester) async {
      final harness = createHarness();
      final content = List<String>.generate(
        200,
        (i) => '第 $i 行：这是一段较长的正文内容用于撑起性能模式。',
      ).join('\n');
      final entry = DiaryEntry(
        filename: '2026-05-01_abc.txt',
        dateString: '2026-05-01',
        title: '超长日记标题',
        content: content,
      );
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
        entry: entry,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('超长日记标题'), findsOneWidget);
      // 首屏可见首行内容
      expect(find.textContaining('第 0 行'), findsOneWidget);
    });

    testWidgets('onContentReady 就绪后退出首屏预览模式显示完整内容', (tester) async {
      final harness = createHarness();
      VoidCallback? onReady;
      final content = '${'A' * 200}${'B' * 300}';
      final entry = DiaryEntry(
        filename: '2026-05-01_abc.txt',
        dateString: '2026-05-01',
        title: '就绪切换',
        content: content,
      );
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
        entry: entry,
        usePreviewMode: true,
        onContentReady: (callback) => onReady = callback,
      );

      // 就绪前：仅预览截断文本
      expect(find.textContaining('BBB'), findsNothing);

      // 触发内容就绪回调，退出预览模式
      onReady!();
      await tester.pumpAndSettle();

      expect(find.textContaining('BBB'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('EditorPage 编辑交互', () {
    testWidgets('修改标题与正文并回显输入内容', (tester) async {
      final harness = createHarness();
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
      );

      await tester.enterText(find.byType(TextField).at(0), '新标题');
      await tester.enterText(find.byType(TextField).at(1), '这是一段正文');
      await tester.pump();

      expect(find.text('新标题'), findsOneWidget);
      expect(find.text('这是一段正文'), findsOneWidget);
      // 注意：不断言实时字数统计——页面未在文本变更时 setState，
      // 字数区域（_buildWordCount）不会实时刷新，属于既有行为。
      expect(tester.takeException(), isNull);
    });

    testWidgets('天气与心情可通过下拉/菜单切换', (tester) async {
      final harness = createHarness();
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
      );

      // 天气：DropdownButton 选择 RAINY
      await tester.tap(find.byType(DropdownButton<WeatherType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RAINY').last);
      await tester.pumpAndSettle();
      expect(find.text('RAINY'), findsOneWidget);

      // 心情：PopupMenuButton 选择 HAPPY
      await tester.tap(find.byType(PopupMenuButton<MoodType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HAPPY').last);
      await tester.pumpAndSettle();
      expect(find.text('HAPPY'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('日期选择器可打开并更新日记日期', (tester) async {
      final harness = createHarness();
      final entry = DiaryEntry(
        filename: '2026-05-01_abc.txt',
        dateString: '2026-05-01',
        title: '日期测试',
        content: '正文',
      );
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
        entry: entry,
      );

      // 点击日期文本打开拟物日期选择器
      await tester.tap(find.text('2026-05-01'));
      await tester.pumpAndSettle();
      expect(find.byType(SkeuomorphicDatePicker), findsOneWidget);

      // 选择当月 15 号（网格全量构建，必可定位）
      final day15 = find.descendant(
        of: find.byType(SkeuomorphicDatePicker),
        matching: find.text('15'),
      );
      await tester.ensureVisible(day15);
      await tester.pumpAndSettle();
      await tester.tap(day15);
      // 选择后延迟 200ms 关闭对话框
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.byType(SkeuomorphicDatePicker), findsNothing);
      expect(find.text('2026-05-15'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('已有日记编辑态修改元信息后返回需确认', (tester) async {
      final harness = createHarness();
      final entry = DiaryEntry(
        filename: '2026-05-01_abc.txt',
        dateString: '2026-05-01',
        title: '原标题',
        weather: WeatherType.sunny,
        mood: MoodType.calm,
        content: '原文',
      );
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
        entry: entry,
      );

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<MoodType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAD').last);
      await tester.pumpAndSettle();

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pumpAndSettle();
      // 元信息变更计入 hasChanges，返回需要确认
      expect(find.text('尚未保存'), findsOneWidget);

      await tester.tap(find.text('继续编辑'));
      await tester.pumpAndSettle();
      expect(find.byType(EditorPage), findsOneWidget);
      expect(find.text('尚未保存'), findsNothing);
    });
  });

  group('EditorPage 返回与草稿', () {
    testWidgets('无修改时返回直接退出，不弹确认', (tester) async {
      final harness = createHarness();
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
      );

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pumpAndSettle();

      expect(find.byType(EditorPage), findsNothing);
      expect(find.text('尚未保存'), findsNothing);
    });

    testWidgets('有修改时返回弹确认，丢弃则清草稿并退出', (tester) async {
      final harness = createHarness();
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
      );

      await tester.enterText(find.byType(TextField).at(0), '未保存标题');
      await tester.pump();

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('尚未保存'), findsOneWidget);

      // 继续编辑：留在页面
      await tester.tap(find.text('继续编辑'));
      await tester.pumpAndSettle();
      expect(find.byType(EditorPage), findsOneWidget);

      // 再次返回并选择丢弃：清草稿 + 退出
      await navigator.maybePop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('丢弃'));
      await tester.pumpAndSettle();

      expect(find.byType(EditorPage), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('存在草稿时弹出恢复对话框，恢复覆盖写回内容', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'draft_new': jsonEncode(<String, Object>{
          'title': '草稿标题',
          'content': '草稿内容',
          'weather': 'cloudy',
          'mood': 'sad',
          'date': '2026-06-01',
          'timestamp': 1,
        }),
      });
      final harness = createHarness();
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
      );
      // postFrame 触发草稿检查 → 异步读取 → 弹出恢复对话框
      await tester.pumpAndSettle();

      expect(find.text('发现未保存手稿'), findsOneWidget);
      await tester.tap(find.text('恢复覆盖'));
      await tester.pumpAndSettle();

      // 草稿字段写回编辑器
      expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
        '草稿标题',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        '草稿内容',
      );
      expect(find.text('CLOUDY'), findsOneWidget);
      expect(find.text('SAD'), findsOneWidget);
      expect(find.text('内容已恢复'), findsOneWidget);
    });

    testWidgets('已有日记存在更短草稿时判定为残缺手稿', (tester) async {
      final entry = DiaryEntry(
        filename: '2026-05-01_abc.txt',
        dateString: '2026-05-01',
        title: '原标题',
        content: '这是一篇比较长的原文内容，用于测试残缺手稿检测逻辑。',
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'draft_2026-05-01_abc.txt': jsonEncode(<String, Object>{
          'title': '原标题',
          'content': '短',
          'weather': 'sunny',
          'mood': 'calm',
          'date': '2026-05-01',
          'timestamp': 1,
        }),
      });
      final harness = createHarness();
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
        entry: entry,
      );
      await tester.pumpAndSettle();

      expect(find.text('发现残缺手稿'), findsOneWidget);
      expect(find.text('另存为新日记'), findsOneWidget);

      // 丢弃草稿：关闭对话框并清空草稿
      await tester.tap(find.text('丢弃草稿'));
      await tester.pumpAndSettle();
      expect(find.text('草稿已丢弃'), findsOneWidget);
    });

    testWidgets('正文修改后 2 秒防抖自动保存草稿', (tester) async {
      final harness = createHarness();
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
      );

      await tester.enterText(find.byType(TextField).at(1), '自动保存内容');
      await tester.pump();

      // 1 秒内尚未触发
      await tester.pump(const Duration(seconds: 1));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('draft_new'), isNull);

      // 累计超过 2 秒防抖窗口后写入草稿
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      final saved = prefs.getString('draft_new');
      expect(saved, isNotNull);
      final data = jsonDecode(saved!) as Map<String, dynamic>;
      expect(data['content'], '自动保存内容');
      expect(data['title'], '');
    });

    testWidgets('切后台（paused）时立即保存草稿，不等防抖', (tester) async {
      final harness = createHarness();
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
      );

      await tester.enterText(find.byType(TextField).at(1), '后台保存内容');
      await tester.pump();

      // 按系统生命周期合法序列进入后台：resumed → inactive → hidden → paused
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('draft_new');
      expect(saved, isNotNull);
      expect((jsonDecode(saved!) as Map<String, dynamic>)['content'], '后台保存内容');

      // 清理：按合法序列反向恢复 paused → hidden → inactive → resumed
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    });
  });

  group('EditorPage 保存与同步反馈', () {
    testWidgets('保存成功：清草稿、展示成功提示并返回上一页', (tester) async {
      final harness = createHarness();
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
      );

      await tester.enterText(find.byType(TextField).at(0), '标题');
      await tester.enterText(find.byType(TextField).at(1), '正文内容');
      await tester.pump();
      // 先让防抖自动保存落草稿
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('draft_new'), isNotNull);

      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      // 成功反馈 + 草稿清除 + 返回上一页
      expect(find.text('日记已保存'), findsOneWidget);
      expect(prefs.getString('draft_new'), isNull);
      expect(find.byType(EditorPage), findsNothing);
      expect(harness.diaryService.saveCallCount, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('启用自动同步时保存后提示准备同步并触发自动同步', (tester) async {
      final harness = createHarness(
        syncConfig: SyncConfig(
          enabled: true,
          autoSync: true,
          serverUrl: 'https://dav.example.com/',
          username: 'demo',
          password: 'secret',
        ),
      );
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
      );

      await tester.enterText(find.byType(TextField).at(0), '标题');
      await tester.pump();
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(find.text('日记已保存，准备同步...'), findsOneWidget);
      expect(harness.syncProvider.requestAutoSyncCallCount, 1);
      expect(
        harness.syncProvider.refreshTrustSnapshotCallCount,
        greaterThan(0),
      );
    });

    testWidgets('未启用自动同步但有待同步项时提示待同步数量', (tester) async {
      final harness = createHarness(
        syncConfig: SyncConfig(
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
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
      );

      await tester.enterText(find.byType(TextField).at(0), '标题');
      await tester.pump();
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(find.text('已保存，尚有 3 项待同步'), findsOneWidget);
      expect(harness.syncProvider.requestAutoSyncCallCount, 0);
    });

    testWidgets('保存失败：提示失败、保留草稿且不返回', (tester) async {
      final harness = createHarness(saveError: Exception('磁盘写入失败'));
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
      );

      await tester.enterText(find.byType(TextField).at(1), '失败内容');
      await tester.pump();
      // 先落草稿
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('draft_new'), isNotNull);

      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(find.textContaining('保存失败'), findsOneWidget);
      expect(find.byType(EditorPage), findsOneWidget);
      // 失败不清草稿
      expect(prefs.getString('draft_new'), isNotNull);
      expect(harness.diaryService.saveCallCount, 1);
    });

    testWidgets('已有日记编辑后保存：透传字段、清草稿、提示成功并返回', (tester) async {
      final harness = createHarness();
      final entry = DiaryEntry(
        filename: '2026-05-01_abc.txt',
        dateString: '2026-05-01',
        title: '原标题',
        content: '原文',
        isMarkdown: true,
      );
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
        entry: entry,
      );

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '修改后的内容');
      await tester.pump();
      // 先让防抖自动保存落草稿（草稿 id 为日记文件名）
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('draft_2026-05-01_abc.txt'), isNotNull);

      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      // 保存编排：字段透传 + 清草稿 + 成功提示 + 返回上一页
      expect(harness.diaryService.saveCallCount, 1);
      expect(
        harness.diaryService.lastSavedEntry!.filename,
        '2026-05-01_abc.txt',
      );
      expect(harness.diaryService.lastSavedEntry!.isMarkdown, isTrue);
      expect(harness.diaryService.lastSavedEntry!.content, '修改后的内容');
      expect(prefs.getString('draft_2026-05-01_abc.txt'), isNull);
      expect(find.text('日记已保存'), findsOneWidget);
      expect(find.byType(EditorPage), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('EditorPage 删除', () {
    testWidgets('删除需确认：保留分支不删除，确认分支删除并返回', (tester) async {
      final harness = createHarness();
      final entry = DiaryEntry(
        filename: '2026-05-01_abc.txt',
        dateString: '2026-05-01',
        title: '待删除',
        content: '正文',
      );
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
        entry: entry,
      );

      // 保留：不删除不返回
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('移入回收站？'), findsOneWidget);
      await tester.tap(find.text('保留'));
      await tester.pumpAndSettle();
      expect(find.byType(EditorPage), findsOneWidget);
      expect(harness.diaryService.deleteCallCount, 0);

      // 确认：删除并返回
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('移入回收站'));
      await tester.pumpAndSettle();

      expect(harness.diaryService.deleteCallCount, 1);
      expect(harness.diaryService.lastDeletedFilename, '2026-05-01_abc.txt');
      expect(find.byType(EditorPage), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('EditorPage 生命周期与导出', () {
    testWidgets('dispose 后自动保存 Timer 不再回调已销毁 State', (tester) async {
      final harness = createHarness();
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
      );

      await tester.enterText(find.byType(TextField).at(1), '触发自动保存计时');
      await tester.pump();

      // 立即销毁页面：dispose 应取消 Timer、释放 Controller 与监听
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);

      // 推进超过防抖窗口：已取消的 Timer 不得回调已销毁的 State
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('导出入口可见且带导出提示', (tester) async {
      final harness = createHarness();
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
      );

      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
      expect(find.byTooltip('导出为图片'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('点击导出进入长图生成覆盖层，页面销毁安全退出', (tester) async {
      final harness = createHarness();
      await pumpEditorPage(
        tester,
        diaryService: harness.diaryService,
        syncProvider: harness.syncProvider,
      );

      await tester.enterText(find.byType(TextField).at(1), '第一行\n第二行');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.share_outlined));
      await tester.pump();

      // 稳定刻画导出入口的 UI 反馈：进入长图生成模式覆盖层
      expect(find.text('正在生成长图...'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 完整导出链路（分块计算、RepaintBoundary 捕获、拼接、文件写入）
      // 已由 DiaryExportService 承载并由其单测覆盖；widget 测试 fake
      // async 下 GoogleFonts.pendingFonts / toImage 仍会悬挂，这里
      // 不触发捕获完成路径。
      // 仅推进时间消化页面内部可能存在的 800ms 延迟 Timer，避免
      // pending timer；页面销毁由 pumpEditorPage 的 addTearDown 兜底
      // （_captureAndSave 的 finally 受 mounted 保护）。
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
