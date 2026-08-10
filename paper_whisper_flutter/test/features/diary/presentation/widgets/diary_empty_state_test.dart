import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/diary/presentation/widgets/diary_empty_state.dart';
import 'package:paper_whisper_flutter/features/diary/presentation/widgets/dashed_line_painter.dart';

/// DiaryEmptyState 组件测试：搜索无结果 / 普通空态两分支的文案、回调、
/// 蜘蛛网与虚线 painter，以及 Windows / Android 360 视口无溢出。
void main() {
  const searchTextColor = Color(0xFF666666);
  const iconColor = Color(0xFF8D6E63);
  const textColor = Color(0xFF5D4037);
  const linkColor = Color(0xFF795548);

  Widget buildEmptyState({String query = '', VoidCallback? onCreate}) {
    return MaterialApp(
      home: Scaffold(
        body: DiaryEmptyState(
          query: query,
          searchTextColor: searchTextColor,
          iconColor: iconColor,
          textColor: textColor,
          linkColor: linkColor,
          onCreate: onCreate ?? () {},
        ),
      ),
    );
  }

  group('DiaryEmptyState 搜索无结果', () {
    testWidgets('展示 search_off 图标与含关键词文案，不渲染普通空态', (tester) async {
      await tester.pumpWidget(buildEmptyState(query: '不存在的关键词'));

      expect(find.byIcon(Icons.search_off), findsOneWidget);
      expect(find.text('没有找到关于"不存在的关键词"的篇章...'), findsOneWidget);
      expect(find.text('这里似乎落了一层灰，等待你来翻阅'), findsNothing);
      expect(find.text('去擦拭灰尘 (写一篇) →'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('DiaryEmptyState 普通空态', () {
    testWidgets('展示蜘蛛网与虚线 painter、主文案和链接文案', (tester) async {
      await tester.pumpWidget(buildEmptyState());

      expect(find.text('这里似乎落了一层灰，等待你来翻阅'), findsOneWidget);
      expect(find.text('去擦拭灰尘 (写一篇) →'), findsOneWidget);

      // 蜘蛛网 painter：颜色与 iconColor prop 一致
      final spider = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is SpiderWebIconPainter,
        ),
      );
      expect((spider.painter! as SpiderWebIconPainter).color, iconColor);

      // 虚线 painter：颜色为 linkColor 的 60% 透明度
      final dashed = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is DashedLinePainter,
        ),
      );
      expect(
        (dashed.painter! as DashedLinePainter).color,
        linkColor.withValues(alpha: 0.6),
      );

      expect(find.byIcon(Icons.search_off), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('点击「去擦拭灰尘」触发 onCreate 回调', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(buildEmptyState(onCreate: () => tapped++));

      await tester.tap(find.text('去擦拭灰尘 (写一篇) →'));
      expect(tapped, 1);
      expect(tester.takeException(), isNull);
    });

    test('SpiderWebIconPainter.shouldRepaint 依据颜色变化', () {
      final a = SpiderWebIconPainter(color: const Color(0xFF000000));
      final b = SpiderWebIconPainter(color: const Color(0xFFFFFFFF));
      expect(a.shouldRepaint(b), isTrue);
      expect(a.shouldRepaint(a), isFalse);
    });
  });

  group('DiaryEmptyState 双平台渲染', () {
    Future<void> pumpOnPlatform(
      WidgetTester tester, {
      required TargetPlatform platform,
      required Size physicalSize,
      required double devicePixelRatio,
      String query = '',
    }) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.physicalSize = physicalSize;
      tester.view.devicePixelRatio = devicePixelRatio;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(body: buildEmptyState(query: query)),
        ),
      );
    }

    testWidgets('Windows 1280x720 普通空态无溢出', (tester) async {
      await pumpOnPlatform(
        tester,
        platform: TargetPlatform.windows,
        physicalSize: const Size(1280, 720),
        devicePixelRatio: 1.0,
      );

      expect(find.text('这里似乎落了一层灰，等待你来翻阅'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Android 360x800 普通空态无溢出', (tester) async {
      await pumpOnPlatform(
        tester,
        platform: TargetPlatform.android,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
      );

      expect(find.text('这里似乎落了一层灰，等待你来翻阅'), findsOneWidget);
      expect(find.text('去擦拭灰尘 (写一篇) →'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Android 360x800 搜索无结果无溢出', (tester) async {
      await pumpOnPlatform(
        tester,
        platform: TargetPlatform.android,
        physicalSize: const Size(1080, 2400),
        devicePixelRatio: 3.0,
        query: '测试关键词',
      );

      expect(find.text('没有找到关于"测试关键词"的篇章...'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
