import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/app/navigation/route_transitions.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/settings/application/settings_provider.dart';
import 'package:provider/provider.dart';

/// 6 种 Route 类（含 FadeSlide 变体）的关键语义刻画：
/// duration / reverseDuration / opaque / barrier / pageBuilder 目标 Widget，
/// 以及 forward + reverse 动画构建无异常。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ThemeRegistry.init);

  const target = Text('target');

  group('六种 Route 类关键属性', () {
    test('SlidePageRoute: 700ms/600ms, opaque', () {
      final route = SlidePageRoute<void>(page: target);
      expect(route.transitionDuration, const Duration(milliseconds: 700));
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 600),
      );
      expect(route.opaque, isTrue);
      expect(route.barrierColor, isNull);
    });

    test('FadeSlidePageRoute: 600ms/500ms, opaque', () {
      final route = FadeSlidePageRoute<void>(page: target);
      expect(route.transitionDuration, const Duration(milliseconds: 600));
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 500),
      );
      expect(route.opaque, isTrue);
      expect(route.barrierColor, isNull);
    });

    test('UnfoldPageRoute: 800ms/700ms 默认, 性能模式 550ms/500ms, opaque=false', () {
      final normal = UnfoldPageRoute<void>(page: target);
      expect(normal.transitionDuration, const Duration(milliseconds: 800));
      expect(
        normal.reverseTransitionDuration,
        const Duration(milliseconds: 700),
      );
      expect(normal.opaque, isFalse);
      expect(normal.barrierColor, Colors.transparent);

      final performance = UnfoldPageRoute<void>(
        page: target,
        usePerformanceMode: true,
      );
      expect(performance.transitionDuration, const Duration(milliseconds: 550));
      expect(
        performance.reverseTransitionDuration,
        const Duration(milliseconds: 500),
      );
    });

    test('SmoothCoverPageRoute: 700ms/600ms, opaque', () {
      final route = SmoothCoverPageRoute<void>(page: target);
      expect(route.transitionDuration, const Duration(milliseconds: 700));
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 600),
      );
      expect(route.opaque, isTrue);
      expect(route.barrierColor, isNull);
    });

    test('BookFlipPageRoute: 500ms/450ms, opaque', () {
      final route = BookFlipPageRoute<void>(page: target);
      expect(route.transitionDuration, const Duration(milliseconds: 500));
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 450),
      );
      expect(route.opaque, isTrue);
      expect(route.barrierColor, isNull);
    });

    test('LetterFoldPageRoute: 1600ms/1400ms, opaque=false, barrier 透明', () {
      final route = LetterFoldPageRoute<void>(page: target);
      expect(route.transitionDuration, const Duration(milliseconds: 1600));
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 1400),
      );
      expect(route.opaque, isFalse);
      expect(route.barrierColor, Colors.transparent);
    });
  });

  group('六种 Route 类 forward + reverse 构建', () {
    for (final spec in <(String, PageRouteBuilder<void> Function())>[
      ('SlidePageRoute', () => SlidePageRoute<void>(page: target)),
      ('FadeSlidePageRoute', () => FadeSlidePageRoute<void>(page: target)),
      (
        'UnfoldPageRoute',
        () => UnfoldPageRoute<void>(
          page: target,
          sourceRect: const Rect.fromLTWH(0, 0, 100, 80),
        ),
      ),
      ('SmoothCoverPageRoute', () => SmoothCoverPageRoute<void>(page: target)),
      ('BookFlipPageRoute', () => BookFlipPageRoute<void>(page: target)),
      ('LetterFoldPageRoute', () => LetterFoldPageRoute<void>(page: target)),
    ]) {
      testWidgets('${spec.$1} pageBuilder 透传 page，前进/返回动画无异常', (tester) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(spec.$2()),
                      child: const Text('go'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        // pageBuilder 直接返回传入的 page（不参与 build，仅透传）
        final context = tester.element(find.byType(MaterialApp));
        final route = spec.$2();
        final built = route.pageBuilder(
          context,
          kAlwaysCompleteAnimation,
          kAlwaysCompleteAnimation,
        );
        expect(built, same(target));

        // forward
        await tester.tap(find.text('go'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(find.text('target'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // reverse
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(find.text('target'), findsNothing);
      });
    }
  });
}
