import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:paper_whisper_flutter/config/app_theme.dart';
import 'package:paper_whisper_flutter/config/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/editor/data/diary_export_service.dart';
import 'package:paper_whisper_flutter/features/editor/presentation/widgets/editor_body.dart';
import 'package:paper_whisper_flutter/features/editor/presentation/widgets/editor_branding_footer.dart';
import 'package:paper_whisper_flutter/features/editor/presentation/widgets/editor_export_surface.dart';
import 'package:paper_whisper_flutter/features/editor/presentation/widgets/editor_meta_selector.dart';
import 'package:paper_whisper_flutter/features/editor/presentation/widgets/editor_top_bar.dart';
import 'package:paper_whisper_flutter/features/editor/presentation/widgets/export_ribbon_painter.dart';
import 'package:paper_whisper_flutter/features/editor/presentation/widgets/lined_paper_painter.dart';
import 'package:paper_whisper_flutter/models/diary_entry.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_date_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 阶段 3 测试 lane 第五批：editor presentation widgets 独立行为测试。
///
/// 只通过公共 props 与真实 PaperWhisperTheme（AppTheme / ThemeRegistry）
/// 断言，不复制视觉实现、不触碰私有状态：
/// - EditorTopBar：编辑/只读/可删除可见性、tooltip/icon、5 个回调
/// - EditorMetaSelector：只读纯文本、编辑态 weather/mood/date 回调、
///   dialog 取消不回调、dialog 期间页面 dispose 不回调
/// - EditorBody：controller/focus props、编辑/只读/preview200、字数、
///   hideLines、>3000 性能路径与 onTapToEdit
/// - EditorBrandingFooter：文案
/// - LinedPaperPainter：shouldRepaint 与绘制不异常
///
/// 交互时间全部由 fake clock 驱动（tester.pump），无真实等待；
/// 不设 GoogleFonts.config.allowRuntimeFetching=false（字体加载 future
/// 在 fake async 下静默悬挂，与 editor_page_test 同一约定）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const theme = AppTheme.themeDefault;
  // 依赖 ThemeRegistry.init()，不能在 main 顶层同步初始化，延迟到
  // setUpAll（registry 就绪后）赋值。
  late final Color textColor;
  late final Color secondaryColor;

  setUpAll(() async {
    ThemeRegistry.init();
    // SkeuomorphicDatePicker 使用 DateFormat.yMMMM('zh_CN')，需要先初始化
    // locale 符号数据，否则打开日期选择器会抛异常。
    await initializeDateFormatting('zh_CN');
    textColor = AppTheme.getTextColor(theme);
    secondaryColor = AppTheme.getTextSecondaryColor(theme);
  });

  // SettingsProvider() 无参构造会异步读取 SharedPreferences，每次构建前
  // 重置 mock 初始值，避免跨测试残留写入与 MissingPluginException。
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // 切换到 Android 360x800 窄屏视图：设置全局平台覆盖与视口尺寸，并
  // 注册 addTearDown 完整恢复（platform/physicalSize/devicePixelRatio）。
  // 注意：flutter_test 在测试体结束时校验 debugDefaultTargetPlatformOverride
  // 必须已复位（debugAssertAllFoundationVarsUnset，addTearDown 在其后才
  // 执行），因此调用方在测试体末尾仍需显式复位一次；addTearDown 负责
  // 失败路径的兜底清理。
  void useAndroidNarrowScreen(WidgetTester tester) {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  // 统一装配：真实主题 + SettingsProvider（PaperSheetWidget /
  // SkeuomorphicDatePicker 内部 Provider.of 依赖）。
  Future<void> pumpInApp(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(),
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
  }

  // 从渲染树中取出唯一的 LinedPaperPainter（foregroundPainter）。
  LinedPaperPainter linedPainterOf(WidgetTester tester) {
    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.foregroundPainter)
        .whereType<LinedPaperPainter>()
        .toList();
    expect(painters, hasLength(1), reason: '渲染树中应恰好有一个 LinedPaperPainter');
    return painters.single;
  }

  group('EditorTopBar', () {
    Widget buildTopBar({
      required bool isEditing,
      required bool showDelete,
      required VoidCallback onBack,
      required VoidCallback onSave,
      required VoidCallback onDelete,
      required VoidCallback onExport,
      required VoidCallback onEditToggle,
    }) {
      return EditorTopBar(
        theme: theme,
        isEditing: isEditing,
        showDelete: showDelete,
        onBack: onBack,
        onSave: onSave,
        onDelete: onDelete,
        onExport: onExport,
        onEditToggle: onEditToggle,
      );
    }

    testWidgets('编辑态：显示返回/导出/完成，隐藏删除与编辑入口', (tester) async {
      await pumpInApp(
        tester,
        buildTopBar(
          isEditing: true,
          showDelete: true,
          onBack: () {},
          onSave: () {},
          onDelete: () {},
          onExport: () {},
          onEditToggle: () {},
        ),
      );

      expect(find.text('返回列表'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
      expect(find.text('完成'), findsOneWidget);
      // 编辑态不显示删除与编辑入口
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('只读态且可删除：显示返回/导出/撕毁/编辑，隐藏完成', (tester) async {
      await pumpInApp(
        tester,
        buildTopBar(
          isEditing: false,
          showDelete: true,
          onBack: () {},
          onSave: () {},
          onDelete: () {},
          onExport: () {},
          onEditToggle: () {},
        ),
      );

      expect(find.text('返回列表'), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.text('完成'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('只读态且不可删除（新建/草稿场景）：隐藏撕毁入口', (tester) async {
      await pumpInApp(
        tester,
        buildTopBar(
          isEditing: false,
          showDelete: false,
          onBack: () {},
          onSave: () {},
          onDelete: () {},
          onExport: () {},
          onEditToggle: () {},
        ),
      );

      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tooltip：导出为图片/撕毁/编辑按可见性提供', (tester) async {
      await pumpInApp(
        tester,
        buildTopBar(
          isEditing: true,
          showDelete: true,
          onBack: () {},
          onSave: () {},
          onDelete: () {},
          onExport: () {},
          onEditToggle: () {},
        ),
      );

      expect(find.byTooltip('导出为图片'), findsOneWidget);
      expect(find.byTooltip('撕毁'), findsNothing);
      expect(find.byTooltip('编辑'), findsNothing);

      await pumpInApp(
        tester,
        buildTopBar(
          isEditing: false,
          showDelete: true,
          onBack: () {},
          onSave: () {},
          onDelete: () {},
          onExport: () {},
          onEditToggle: () {},
        ),
      );

      expect(find.byTooltip('撕毁'), findsOneWidget);
      expect(find.byTooltip('编辑'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('编辑态回调：返回/导出/保存分别触发', (tester) async {
      var backCount = 0;
      var exportCount = 0;
      var saveCount = 0;
      await pumpInApp(
        tester,
        buildTopBar(
          isEditing: true,
          showDelete: true,
          onBack: () => backCount++,
          onSave: () => saveCount++,
          onDelete: () {},
          onExport: () => exportCount++,
          onEditToggle: () {},
        ),
      );

      await tester.tap(find.text('返回列表'));
      await tester.tap(find.byIcon(Icons.share_outlined));
      await tester.tap(find.text('完成'));
      await tester.pump();

      expect(backCount, 1);
      expect(exportCount, 1);
      expect(saveCount, 1);
    });

    testWidgets('只读态回调：返回/导出/删除/进入编辑分别触发', (tester) async {
      var backCount = 0;
      var exportCount = 0;
      var deleteCount = 0;
      var editCount = 0;
      await pumpInApp(
        tester,
        buildTopBar(
          isEditing: false,
          showDelete: true,
          onBack: () => backCount++,
          onSave: () {},
          onDelete: () => deleteCount++,
          onExport: () => exportCount++,
          onEditToggle: () => editCount++,
        ),
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.tap(find.byIcon(Icons.share_outlined));
      await tester.pump();

      expect(deleteCount, 1);
      expect(editCount, 1);
      expect(exportCount, 1);
      expect(backCount, 0);
    });
  });

  group('EditorMetaSelector', () {
    Widget buildMetaSelector({
      required bool isEditing,
      required String dateString,
      required WeatherType weather,
      required MoodType mood,
      ValueChanged<DateTime>? onDateChanged,
      ValueChanged<WeatherType>? onWeatherChanged,
      ValueChanged<MoodType>? onMoodChanged,
    }) {
      return EditorMetaSelector(
        theme: theme,
        metaTextColor: secondaryColor,
        isEditing: isEditing,
        dateString: dateString,
        weather: weather,
        mood: mood,
        onDateChanged: onDateChanged ?? (_) {},
        onWeatherChanged: onWeatherChanged ?? (_) {},
        onMoodChanged: onMoodChanged ?? (_) {},
      );
    }

    testWidgets('只读态：日期/天气/心情纯文本，无交互控件', (tester) async {
      await pumpInApp(
        tester,
        buildMetaSelector(
          isEditing: false,
          dateString: '2026-05-01',
          weather: WeatherType.sunny,
          mood: MoodType.calm,
        ),
      );

      expect(find.text('2026-05-01'), findsOneWidget);
      expect(find.text('SUNNY'), findsOneWidget);
      expect(find.text('CALM'), findsOneWidget);
      expect(find.byType(DropdownButton<WeatherType>), findsNothing);
      expect(find.byType(PopupMenuButton<MoodType>), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('编辑态：天气下拉与心情菜单存在，元信息文本保留', (tester) async {
      await pumpInApp(
        tester,
        buildMetaSelector(
          isEditing: true,
          dateString: '2026-05-01',
          weather: WeatherType.rainy,
          mood: MoodType.excited,
        ),
      );

      expect(find.byType(DropdownButton<WeatherType>), findsOneWidget);
      expect(find.byType(PopupMenuButton<MoodType>), findsOneWidget);
      expect(find.text('RAINY'), findsOneWidget);
      expect(find.text('EXCITED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('只读态 360 内容约束：日期/天气/心情均可见且无 overflow', (tester) async {
      useAndroidNarrowScreen(tester);

      await pumpInApp(
        tester,
        buildMetaSelector(
          isEditing: false,
          dateString: '2026-05-01',
          weather: WeatherType.sunny,
          mood: MoodType.calm,
        ),
      );

      expect(find.text('2026-05-01'), findsOneWidget);
      expect(find.text('SUNNY'), findsOneWidget);
      expect(find.text('CALM'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 恢复全局平台覆盖（框架 invariant 先于 addTearDown 校验）
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('编辑态 360 内容约束：元信息可见无 overflow，天气/心情可交互', (tester) async {
      useAndroidNarrowScreen(tester);

      WeatherType? changedWeather;
      MoodType? changedMood;
      await pumpInApp(
        tester,
        buildMetaSelector(
          isEditing: true,
          dateString: '2026-05-01',
          weather: WeatherType.sunny,
          mood: MoodType.calm,
          onWeatherChanged: (v) => changedWeather = v,
          onMoodChanged: (v) => changedMood = v,
        ),
      );

      expect(find.text('2026-05-01'), findsOneWidget);
      expect(find.text('SUNNY'), findsOneWidget);
      expect(find.text('CALM'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 天气下拉可交互
      await tester.tap(find.byType(DropdownButton<WeatherType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RAINY').last);
      await tester.pumpAndSettle();
      expect(changedWeather, WeatherType.rainy);

      // 心情菜单可交互
      await tester.tap(find.byType(PopupMenuButton<MoodType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HAPPY').last);
      await tester.pumpAndSettle();
      expect(changedMood, MoodType.happy);
      expect(tester.takeException(), isNull);

      // 恢复全局平台覆盖（框架 invariant 先于 addTearDown 校验）
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('编辑态切换天气触发 onWeatherChanged', (tester) async {
      WeatherType? changed;
      await pumpInApp(
        tester,
        buildMetaSelector(
          isEditing: true,
          dateString: '2026-05-01',
          weather: WeatherType.rainy,
          mood: MoodType.calm,
          onWeatherChanged: (v) => changed = v,
        ),
      );

      await tester.tap(find.byType(DropdownButton<WeatherType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SNOWY').last);
      await tester.pumpAndSettle();

      expect(changed, WeatherType.snowy);
    });

    testWidgets('编辑态切换心情触发 onMoodChanged', (tester) async {
      MoodType? changed;
      await pumpInApp(
        tester,
        buildMetaSelector(
          isEditing: true,
          dateString: '2026-05-01',
          weather: WeatherType.sunny,
          mood: MoodType.calm,
          onMoodChanged: (v) => changed = v,
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<MoodType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HAPPY').last);
      await tester.pumpAndSettle();

      expect(changed, MoodType.happy);
    });

    testWidgets('编辑态选择日期触发 onDateChanged', (tester) async {
      DateTime? changed;
      await pumpInApp(
        tester,
        buildMetaSelector(
          isEditing: true,
          dateString: '2026-05-01',
          weather: WeatherType.sunny,
          mood: MoodType.calm,
          onDateChanged: (d) => changed = d,
        ),
      );

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
      // 选择后延迟 200ms 自行关闭对话框
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.byType(SkeuomorphicDatePicker), findsNothing);
      expect(changed, DateTime(2026, 5, 15));
      expect(tester.takeException(), isNull);
    });

    testWidgets('日期选择器取消（点取消按钮）不触发 onDateChanged', (tester) async {
      var dateChangedCount = 0;
      await pumpInApp(
        tester,
        buildMetaSelector(
          isEditing: true,
          dateString: '2026-05-01',
          weather: WeatherType.sunny,
          mood: MoodType.calm,
          onDateChanged: (_) => dateChangedCount++,
        ),
      );

      await tester.tap(find.text('2026-05-01'));
      await tester.pumpAndSettle();
      expect(find.byType(SkeuomorphicDatePicker), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.byType(SkeuomorphicDatePicker), findsNothing);
      expect(dateChangedCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dialog 打开期间页面 dispose：已选日期也不触发 onDateChanged', (tester) async {
      var dateChangedCount = 0;
      await pumpInApp(
        tester,
        buildMetaSelector(
          isEditing: true,
          dateString: '2026-05-01',
          weather: WeatherType.sunny,
          mood: MoodType.calm,
          onDateChanged: (_) => dateChangedCount++,
        ),
      );

      await tester.tap(find.text('2026-05-01'));
      await tester.pumpAndSettle();
      expect(find.byType(SkeuomorphicDatePicker), findsOneWidget);

      // 选中日期：onDateSelected 已写入局部变量，200ms 后对话框才关闭
      final day15 = find.descendant(
        of: find.byType(SkeuomorphicDatePicker),
        matching: find.text('15'),
      );
      await tester.ensureVisible(day15);
      await tester.pumpAndSettle();
      await tester.tap(day15);
      await tester.pump(const Duration(milliseconds: 50));

      // 对话框尚未关闭时整棵树被销毁（模拟页面 dispose）
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));

      // context.mounted 保护：await showDialog 返回后不再回调
      expect(dateChangedCount, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('EditorBody', () {
    Widget buildBody({
      required TextEditingController titleController,
      required TextEditingController contentController,
      required TextEditingController previewController,
      required bool isEditing,
      required bool isPreviewMode,
      required FocusNode focusNode,
      required bool hideLines,
      String dateString = '2026-05-01',
      WeatherType weather = WeatherType.sunny,
      MoodType mood = MoodType.calm,
      ValueChanged<DateTime>? onDateChanged,
      ValueChanged<WeatherType>? onWeatherChanged,
      ValueChanged<MoodType>? onMoodChanged,
      VoidCallback? onTapToEdit,
    }) {
      return EditorBody(
        titleController: titleController,
        contentController: contentController,
        previewController: previewController,
        isEditing: isEditing,
        isPreviewMode: isPreviewMode,
        focusNode: focusNode,
        theme: theme,
        textColor: textColor,
        secondaryColor: secondaryColor,
        hideLines: hideLines,
        dateString: dateString,
        weather: weather,
        mood: mood,
        onDateChanged: onDateChanged ?? (_) {},
        onWeatherChanged: onWeatherChanged ?? (_) {},
        onMoodChanged: onMoodChanged ?? (_) {},
        onTapToEdit: onTapToEdit ?? () {},
      );
    }

    testWidgets('编辑态：标题/正文 TextField 绑定传入的 controllers', (tester) async {
      final titleController = TextEditingController(text: '我的标题');
      final contentController = TextEditingController(text: '正文内容');
      final previewController = TextEditingController(text: '预览');
      final focusNode = FocusNode();
      addTearDown(() {
        titleController.dispose();
        contentController.dispose();
        previewController.dispose();
        focusNode.dispose();
      });

      await pumpInApp(
        tester,
        buildBody(
          titleController: titleController,
          contentController: contentController,
          previewController: previewController,
          isEditing: true,
          isPreviewMode: false,
          focusNode: focusNode,
          hideLines: false,
        ),
      );

      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields, hasLength(2));
      expect(fields[0].controller, same(titleController));
      expect(fields[1].controller, same(contentController));
      expect(tester.takeException(), isNull);
    });

    testWidgets('只读态：标题/正文渲染为文本，空标题显示无题', (tester) async {
      final titleController = TextEditingController(text: '我的标题');
      final contentController = TextEditingController(text: '正文内容');
      final previewController = TextEditingController(text: '预览');
      final focusNode = FocusNode();
      addTearDown(() {
        titleController.dispose();
        contentController.dispose();
        previewController.dispose();
        focusNode.dispose();
      });

      await pumpInApp(
        tester,
        buildBody(
          titleController: titleController,
          contentController: contentController,
          previewController: previewController,
          isEditing: false,
          isPreviewMode: false,
          focusNode: focusNode,
          hideLines: false,
        ),
      );

      expect(find.byType(TextField), findsNothing);
      expect(find.text('我的标题'), findsOneWidget);
      expect(find.text('正文内容'), findsOneWidget);

      // 空标题只读态显示「无题」
      final emptyTitle = TextEditingController(text: '');
      addTearDown(emptyTitle.dispose);
      await pumpInApp(
        tester,
        buildBody(
          titleController: emptyTitle,
          contentController: contentController,
          previewController: previewController,
          isEditing: false,
          isPreviewMode: false,
          focusNode: focusNode,
          hideLines: false,
        ),
      );
      expect(find.text('无题'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('preview200：只读预览模式显示截断文本而非完整内容', (tester) async {
      const fullContent = '这是完整正文，长度超过预览截断范围，不应在预览模式渲染';
      const previewText = '这是前 200 字预览';
      final titleController = TextEditingController(text: '标题');
      final contentController = TextEditingController(text: fullContent);
      final previewController = TextEditingController(text: previewText);
      final focusNode = FocusNode();
      addTearDown(() {
        titleController.dispose();
        contentController.dispose();
        previewController.dispose();
        focusNode.dispose();
      });

      await pumpInApp(
        tester,
        buildBody(
          titleController: titleController,
          contentController: contentController,
          previewController: previewController,
          isEditing: false,
          isPreviewMode: true,
          focusNode: focusNode,
          hideLines: false,
        ),
      );

      expect(find.text(previewText), findsOneWidget);
      expect(find.text(fullContent), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('preview200：编辑预览模式正文 TextField 绑定 previewController', (
      tester,
    ) async {
      final titleController = TextEditingController(text: '标题');
      final contentController = TextEditingController(text: '完整内容');
      final previewController = TextEditingController(text: '截断预览');
      final focusNode = FocusNode();
      addTearDown(() {
        titleController.dispose();
        contentController.dispose();
        previewController.dispose();
        focusNode.dispose();
      });

      await pumpInApp(
        tester,
        buildBody(
          titleController: titleController,
          contentController: contentController,
          previewController: previewController,
          isEditing: true,
          isPreviewMode: true,
          focusNode: focusNode,
          hideLines: false,
        ),
      );

      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields, hasLength(2));
      expect(fields[1].controller, same(previewController));
      expect(tester.takeException(), isNull);
    });

    testWidgets('字数统计：非空正文显示 N 字，空正文不渲染', (tester) async {
      final titleController = TextEditingController(text: '标题');
      final contentController = TextEditingController(text: '你好世界');
      final previewController = TextEditingController(text: '');
      final focusNode = FocusNode();
      addTearDown(() {
        titleController.dispose();
        contentController.dispose();
        previewController.dispose();
        focusNode.dispose();
      });

      await pumpInApp(
        tester,
        buildBody(
          titleController: titleController,
          contentController: contentController,
          previewController: previewController,
          isEditing: false,
          isPreviewMode: false,
          focusNode: focusNode,
          hideLines: false,
        ),
      );

      expect(find.text('4 字'), findsOneWidget);

      final emptyContent = TextEditingController(text: '');
      addTearDown(emptyContent.dispose);
      await pumpInApp(
        tester,
        buildBody(
          titleController: titleController,
          contentController: emptyContent,
          previewController: previewController,
          isEditing: false,
          isPreviewMode: false,
          focusNode: focusNode,
          hideLines: false,
        ),
      );
      expect(find.textContaining(' 字'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hideLines：false 使用主题线色，true 隐藏为透明', (tester) async {
      final titleController = TextEditingController(text: '标题');
      final contentController = TextEditingController(text: '正文');
      final previewController = TextEditingController(text: '');
      final focusNode = FocusNode();
      addTearDown(() {
        titleController.dispose();
        contentController.dispose();
        previewController.dispose();
        focusNode.dispose();
      });

      await pumpInApp(
        tester,
        buildBody(
          titleController: titleController,
          contentController: contentController,
          previewController: previewController,
          isEditing: false,
          isPreviewMode: false,
          focusNode: focusNode,
          hideLines: false,
        ),
      );
      final visiblePainter = linedPainterOf(tester);
      expect(
        visiblePainter.lineColor,
        ThemeRegistry.get(theme).editor.lineColor,
      );

      await pumpInApp(
        tester,
        buildBody(
          titleController: titleController,
          contentController: contentController,
          previewController: previewController,
          isEditing: false,
          isPreviewMode: false,
          focusNode: focusNode,
          hideLines: true,
        ),
      );
      final hiddenPainter = linedPainterOf(tester);
      expect(hiddenPainter.lineColor, Colors.transparent);
      expect(tester.takeException(), isNull);
    });

    testWidgets('>3000 字符走性能模式：CustomScrollView + SliverList 结构', (
      tester,
    ) async {
      final titleController = TextEditingController(text: '长文标题');
      final contentController = TextEditingController(
        text: List.generate(80, (i) => '第$i行：${'字' * 40}').join('\n'),
      );
      final previewController = TextEditingController(text: '');
      final focusNode = FocusNode();
      addTearDown(() {
        titleController.dispose();
        contentController.dispose();
        previewController.dispose();
        focusNode.dispose();
      });

      expect(contentController.text.length, greaterThan(3000));

      await pumpInApp(
        tester,
        buildBody(
          titleController: titleController,
          contentController: contentController,
          previewController: previewController,
          isEditing: false,
          isPreviewMode: false,
          focusNode: focusNode,
          hideLines: false,
        ),
      );

      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byType(SliverList), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('性能模式编辑态：正文 TextField 绑定传入的 focusNode', (tester) async {
      final titleController = TextEditingController(text: '长文标题');
      final contentController = TextEditingController(
        text: List.generate(80, (i) => '第$i行：${'字' * 40}').join('\n'),
      );
      final previewController = TextEditingController(text: '');
      final focusNode = FocusNode();
      addTearDown(() {
        titleController.dispose();
        contentController.dispose();
        previewController.dispose();
        focusNode.dispose();
      });

      await pumpInApp(
        tester,
        buildBody(
          titleController: titleController,
          contentController: contentController,
          previewController: previewController,
          isEditing: true,
          isPreviewMode: false,
          focusNode: focusNode,
          hideLines: false,
        ),
      );

      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields, hasLength(2));
      expect(fields[1].focusNode, same(focusNode));
      expect(tester.takeException(), isNull);
    });

    testWidgets('性能模式只读：点击任意行触发 onTapToEdit', (tester) async {
      var tapCount = 0;
      final titleController = TextEditingController(text: '长文标题');
      final contentController = TextEditingController(
        text: List.generate(80, (i) => '第$i行：${'字' * 40}').join('\n'),
      );
      final previewController = TextEditingController(text: '');
      final focusNode = FocusNode();
      addTearDown(() {
        titleController.dispose();
        contentController.dispose();
        previewController.dispose();
        focusNode.dispose();
      });

      await pumpInApp(
        tester,
        buildBody(
          titleController: titleController,
          contentController: contentController,
          previewController: previewController,
          isEditing: false,
          isPreviewMode: false,
          focusNode: focusNode,
          hideLines: false,
          onTapToEdit: () => tapCount++,
        ),
      );

      final firstLine = find
          .descendant(of: find.byType(SliverList), matching: find.byType(Text))
          .first;
      await tester.ensureVisible(firstLine);
      await tester.pumpAndSettle();
      await tester.tap(firstLine);
      await tester.pump();

      expect(tapCount, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Android 360x800：TopBar + MetaSelector + Body 渲染无 overflow', (
      tester,
    ) async {
      // 真实 Android 窄屏约束：EditorMetaSelector 在窄内容区自动切换
      // Wrap 分组换行（lib ba0fa96 修复），360 宽屏下不再横向溢出，
      // 因此 smoke 恢复为 360x800 验证整块装配无异常。
      useAndroidNarrowScreen(tester);

      final titleController = TextEditingController(text: '标题');
      final contentController = TextEditingController(text: '正文内容');
      final previewController = TextEditingController(text: '');
      final focusNode = FocusNode();
      addTearDown(() {
        titleController.dispose();
        contentController.dispose();
        previewController.dispose();
        focusNode.dispose();
      });

      await pumpInApp(
        tester,
        Column(
          children: [
            EditorTopBar(
              theme: theme,
              isEditing: true,
              showDelete: true,
              onBack: () {},
              onSave: () {},
              onDelete: () {},
              onExport: () {},
              onEditToggle: () {},
            ),
            Expanded(
              child: SingleChildScrollView(
                child: buildBody(
                  titleController: titleController,
                  contentController: contentController,
                  previewController: previewController,
                  isEditing: false,
                  isPreviewMode: false,
                  focusNode: focusNode,
                  hideLines: false,
                ),
              ),
            ),
          ],
        ),
      );

      expect(find.text('返回列表'), findsOneWidget);
      expect(find.text('2026-05-01'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 恢复全局平台覆盖（框架 invariant 先于 addTearDown 校验）
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('EditorBrandingFooter', () {
    testWidgets('渲染品牌文案两行', (tester) async {
      await pumpInApp(
        tester,
        const EditorBrandingFooter(secondaryColor: Colors.black54),
      );

      expect(find.text('CREATED WITH'), findsOneWidget);
      expect(find.text('纸语 PaperWhisper'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('LinedPaperPainter', () {
    testWidgets('shouldRepaint：同色同高 false，颜色或行高任一变化 true', (tester) async {
      final base = LinedPaperPainter(lineColor: Colors.black, lineHeight: 32);
      final same = LinedPaperPainter(lineColor: Colors.black, lineHeight: 32);
      final colorChanged = LinedPaperPainter(
        lineColor: Colors.red,
        lineHeight: 32,
      );
      final heightChanged = LinedPaperPainter(
        lineColor: Colors.black,
        lineHeight: 40,
      );

      // 契约：同色同高度不重绘；颜色或 lineHeight 任一变化必须重绘
      expect(base.shouldRepaint(same), isFalse);
      expect(base.shouldRepaint(colorChanged), isTrue);
      expect(base.shouldRepaint(heightChanged), isTrue);
    });

    testWidgets('paint：在给定尺寸下绘制不抛异常', (tester) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = LinedPaperPainter(
        lineColor: Colors.black,
        lineHeight: 32,
      );

      // 100 高 / 32 行高：画线 y = 32, 64, 96, 128（<= 100 + 32），不抛异常
      painter.paint(canvas, const Size(100, 100));

      // 零尺寸不抛异常
      painter.paint(canvas, Size.zero);
    });
  });

  group('EditorExportSurface', () {
    List<GlobalKey> buildKeys(int count) =>
        List.generate(count, (_) => GlobalKey());

    Widget buildExportSurface({
      required List<GlobalKey> repaintKeys,
      required DiaryExportChunkPlan? plan,
      required String title,
      required String dateString,
      required WeatherType weather,
      required MoodType mood,
      required bool hideLines,
    }) {
      return EditorExportSurface(
        repaintKeys: repaintKeys,
        plan: plan,
        theme: theme,
        textColor: textColor,
        secondaryColor: secondaryColor,
        title: title,
        dateString: dateString,
        weather: weather,
        mood: mood,
        hideLines: hideLines,
      );
    }

    // 限定在 ExportSurface 子树内查找，避免 MaterialApp/Scaffold 内部
    // 自带的 RepaintBoundary 干扰计数。
    Finder exportBoundaries() => find.descendant(
      of: find.byType(EditorExportSurface),
      matching: find.byType(RepaintBoundary),
    );

    testWidgets('plan 为 null：不产生任何 RepaintBoundary', (tester) async {
      await pumpInApp(
        tester,
        buildExportSurface(
          repaintKeys: buildKeys(4),
          plan: null,
          title: '标题',
          dateString: '2026-05-01',
          weather: WeatherType.sunny,
          mood: MoodType.calm,
          hideLines: false,
        ),
      );

      expect(exportBoundaries(), findsNothing);
      expect(find.byType(EditorExportSurface), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('header + N 正文 + footer 数量与 GlobalKey 索引完全对应', (tester) async {
      final keys = buildKeys(4);
      const plan = DiaryExportChunkPlan(
        totalChunks: 4,
        bodyChunkTexts: ['正文块一', '正文块二'],
      );
      await pumpInApp(
        tester,
        buildExportSurface(
          repaintKeys: keys,
          plan: plan,
          title: '导出标题',
          dateString: '2026-05-01',
          weather: WeatherType.sunny,
          mood: MoodType.calm,
          hideLines: false,
        ),
      );

      final boundaries = tester
          .widgetList<RepaintBoundary>(exportBoundaries())
          .toList();
      // 1 Header + 2 正文 + 1 Footer = 4，与传入的 4 个 key 一一对应
      expect(boundaries, hasLength(4));
      for (var i = 0; i < keys.length; i++) {
        expect(boundaries[i].key, same(keys[i]));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('metadata/正文/footer 文本均可见', (tester) async {
      const plan = DiaryExportChunkPlan(
        totalChunks: 3,
        bodyChunkTexts: ['正文块一', '正文块二'],
      );
      await pumpInApp(
        tester,
        buildExportSurface(
          repaintKeys: buildKeys(4),
          plan: plan,
          title: '我的导出标题',
          dateString: '2026-05-01',
          weather: WeatherType.sunny,
          mood: MoodType.calm,
          hideLines: false,
        ),
      );

      // header：标题与日期/天气/心情元信息
      expect(find.text('我的导出标题'), findsOneWidget);
      expect(find.text('2026-05-01'), findsOneWidget);
      expect(find.text('SUNNY'), findsOneWidget);
      expect(find.text('CALM'), findsOneWidget);
      // 正文分块文本
      expect(find.text('正文块一'), findsOneWidget);
      expect(find.text('正文块二'), findsOneWidget);
      // footer 品牌文案
      expect(find.text('CREATED WITH'), findsOneWidget);
      expect(find.text('纸语 PaperWhisper'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hideLines 透传：true 正文线透明，false 使用主题线色', (tester) async {
      const plan = DiaryExportChunkPlan(totalChunks: 3, bodyChunkTexts: ['正文']);

      LinedPaperPainter bodyPainterOf(WidgetTester tester) => tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(EditorExportSurface),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((c) => c.foregroundPainter)
          .whereType<LinedPaperPainter>()
          .single;

      await pumpInApp(
        tester,
        buildExportSurface(
          repaintKeys: buildKeys(3),
          plan: plan,
          title: '标题',
          dateString: '2026-05-01',
          weather: WeatherType.sunny,
          mood: MoodType.calm,
          hideLines: true,
        ),
      );
      expect(bodyPainterOf(tester).lineColor, Colors.transparent);

      await pumpInApp(
        tester,
        buildExportSurface(
          repaintKeys: buildKeys(3),
          plan: plan,
          title: '标题',
          dateString: '2026-05-01',
          weather: WeatherType.sunny,
          mood: MoodType.calm,
          hideLines: false,
        ),
      );
      expect(
        bodyPainterOf(tester).lineColor,
        ThemeRegistry.get(theme).editor.lineColor,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('700 设计宽度：ExportSurface 渲染无 overflow', (tester) async {
      // 导出表面按 700 宽画布设计：Header + 正文 + Footer 的 meta Row 在
      // 窄于 ~446px 的视口下会溢出（lib 行为，见 EditorBody 窄屏注），
      // 因此 smoke 采用设计宽度验证整块渲染无异常。
      tester.view.physicalSize = const Size(700, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const plan = DiaryExportChunkPlan(
        totalChunks: 4,
        bodyChunkTexts: ['正文块一', '正文块二'],
      );
      await pumpInApp(
        tester,
        SingleChildScrollView(
          child: buildExportSurface(
            repaintKeys: buildKeys(4),
            plan: plan,
            title: '标题',
            dateString: '2026-05-01',
            weather: WeatherType.sunny,
            mood: MoodType.calm,
            hideLines: false,
          ),
        ),
      );

      expect(find.text('标题'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ExportRibbonPainter', () {
    testWidgets('shouldRepaint：同色 false，变色 true', (tester) async {
      final base = ExportRibbonPainter(color: Colors.red);
      final same = ExportRibbonPainter(color: Colors.red);
      final different = ExportRibbonPainter(color: Colors.blue);

      expect(base.shouldRepaint(same), isFalse);
      expect(base.shouldRepaint(different), isTrue);
    });

    testWidgets('paint：在给定尺寸下绘制不抛异常', (tester) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = ExportRibbonPainter(color: Colors.red);

      // 与 ExportSurface 实际使用尺寸一致
      painter.paint(canvas, const Size(50, 90));
      // 零尺寸不抛异常
      painter.paint(canvas, Size.zero);
    });
  });
}
