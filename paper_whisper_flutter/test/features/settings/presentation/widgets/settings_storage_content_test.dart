import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:paper_whisper_flutter/features/settings/presentation/widgets/settings_storage_content.dart';

void main() {
  setUp(() {
    // 测试环境禁用运行时字体拉取，避免网络请求与字体加载噪音。
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const textColor = Color(0xFF3E3A36);
  const infoBg = Color(0xFFF9F5EC);
  const infoBorder = Color(0xFFE0D5C3);
  const infoDivider = Color(0xFFD7CCC8);

  Widget wrap(Widget child, {double width = 800, double height = 600}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );
  }

  Widget buildContent({
    String internalStats = 'Doc: 1.2 MB / Support: 345 KB',
    bool hasInternalClutter = false,
    VoidCallback? onCleanOrphanImages,
    VoidCallback? onCleanTemporaryCache,
    VoidCallback? onCleanInternalClutter,
    VoidCallback? onCleanFontCache,
  }) {
    return SettingsStorageContent(
      internalStats: internalStats,
      hasInternalClutter: hasInternalClutter,
      textColor: textColor,
      infoBackgroundColor: infoBg,
      infoBorderColor: infoBorder,
      infoDividerColor: infoDivider,
      onCleanOrphanImages: onCleanOrphanImages ?? () {},
      onCleanTemporaryCache: onCleanTemporaryCache ?? () {},
      onCleanInternalClutter: onCleanInternalClutter ?? () {},
      onCleanFontCache: onCleanFontCache ?? () {},
    );
  }

  group('SettingsStorageContent', () {
    testWidgets('渲染清理操作与运行数据 overview，文本顺序与原文案一致', (tester) async {
      await tester.pumpWidget(wrap(buildContent()));

      final expectedTexts = [
        '清理无用图片 (深度清理)',
        '扫描并删除未被任何随心记引用的冗余图片',
        '立即清理缓存',
        '清理产生的临时文件 (不影响数据)',
        '系统运行数据 (App必须)',
        '包含字体缓存 (Support) 及 App 资源文件 (Doc)。\n此部分数据维持 App 正常运行，无需清理。',
        '占用空间: Doc: 1.2 MB / Support: 345 KB',
        '>> 强制清除字体缓存 (修复显示异常)',
      ];
      for (final text in expectedTexts) {
        expect(find.text(text), findsOneWidget, reason: '缺少文本: $text');
      }

      // 文本出现顺序与预期一致（按 y 坐标升序）。
      final widgets = expectedTexts
          .map((t) => tester.getTopLeft(find.text(t)).dy)
          .toList();
      final sorted = [...widgets]..sort();
      expect(widgets, sorted);

      // 无残留数据时不显示残留清理入口。
      expect(find.text('>> 发现残留数据，点击清理'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('发现残留数据时显示残留清理入口', (tester) async {
      await tester.pumpWidget(wrap(buildContent(hasInternalClutter: true)));
      expect(find.text('>> 发现残留数据，点击清理'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Support 占用为 0 B 时不显示字体缓存入口', (tester) async {
      await tester.pumpWidget(
        wrap(buildContent(internalStats: 'Doc: 1.2 MB / Support: 0 B')),
      );
      expect(find.text('>> 强制清除字体缓存 (修复显示异常)'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('四个清理回调均被触发', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        wrap(
          buildContent(
            hasInternalClutter: true,
            internalStats: 'Doc: 1.2 MB / Support: 345 KB',
            onCleanOrphanImages: () => calls.add('orphan'),
            onCleanTemporaryCache: () => calls.add('cache'),
            onCleanInternalClutter: () => calls.add('clutter'),
            onCleanFontCache: () => calls.add('font'),
          ),
        ),
      );

      await tester.tap(find.text('清理无用图片 (深度清理)'));
      await tester.pump();
      await tester.tap(find.text('立即清理缓存'));
      await tester.pump();
      await tester.tap(find.text('>> 发现残留数据，点击清理'));
      await tester.pump();
      await tester.tap(find.text('>> 强制清除字体缓存 (修复显示异常)'));
      await tester.pump();

      expect(calls, ['orphan', 'cache', 'clutter', 'font']);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '操作行样式契约：默认 contentPadding、leading 原色、title 无额外 weight/size、subtitle 12 alpha0.6',
      (tester) async {
        await tester.pumpWidget(wrap(buildContent()));

        // 两操作行均为 ListTile，contentPadding 未显式设置（原默认）。
        final tiles = tester
            .widgetList<ListTile>(find.byType(ListTile))
            .toList();
        expect(tiles, hasLength(2));
        for (final tile in tiles) {
          expect(
            tile.contentPadding,
            isNull,
            reason: '操作行应保留 ListTile 默认 contentPadding',
          );
        }

        // leading 图标原色（无 alpha）。
        final deleteIcon = tester.widget<Icon>(find.byIcon(Icons.delete_sweep));
        expect(deleteIcon.color, textColor);
        final cleanIcon = tester.widget<Icon>(
          find.byIcon(Icons.cleaning_services),
        );
        expect(cleanIcon.color, textColor);

        // title 原 font：无额外 weight/size（仅颜色）。
        for (final t in ['清理无用图片 (深度清理)', '立即清理缓存']) {
          final titleText = tester.widget<Text>(find.text(t));
          expect(titleText.style?.fontWeight, isNull);
          expect(titleText.style?.fontSize, isNull);
          expect(titleText.style?.color, textColor);
        }

        // subtitle 12 alpha0.6。
        for (final s in ['扫描并删除未被任何随心记引用的冗余图片', '清理产生的临时文件 (不影响数据)']) {
          final subText = tester.widget<Text>(find.text(s));
          expect(subText.style?.fontSize, 12);
          expect(subText.style?.color, textColor.withValues(alpha: 0.6));
        }
      },
    );

    testWidgets('两操作行间分隔线保留原默认高度；运行数据卡内分隔线仍为 height1', (tester) async {
      await tester.pumpWidget(wrap(buildContent()));

      // 行间分隔线：原 `Divider(color: ...)` 未设 height（默认 16）。
      final rowDivider = tester.widget<Divider>(
        find.byWidgetPredicate(
          (w) => w is Divider && w.color == textColor.withValues(alpha: 0.1),
        ),
      );
      expect(
        rowDivider.height,
        isNull,
        reason: '行间分隔线应保留原默认高度，不用 SettingsDivider height1',
      );
      expect(rowDivider.thickness, isNull);

      // 运行数据卡内分隔线仍为 height 1。
      final infoDividerWidget = tester.widget<Divider>(
        find.byWidgetPredicate((w) => w is Divider && w.color == infoDivider),
      );
      expect(infoDividerWidget.height, 1);
    });

    testWidgets('置于带背景 DecoratedBox 内不触发 ListTile 断言（透明 Material 包裹）', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFFF9F5EC)),
              child: buildContent(),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Windows 与 Android 360 宽度下无 overflow', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: buildContent(
                    hasInternalClutter: true,
                    internalStats: 'Doc: 1.2 MB / Support: 345 KB',
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });
}
