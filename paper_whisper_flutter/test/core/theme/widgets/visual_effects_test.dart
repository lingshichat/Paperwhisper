import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/core/theme/widgets/visual_effects.dart';

void main() {
  testWidgets('starry sky reuses one painter across animation frames', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: const SizedBox.expand(child: StarrySkyWidget()),
      ),
    );

    final starrySky = find.byType(StarrySkyWidget);
    final customPaint = find.descendant(
      of: starrySky,
      matching: find.byType(CustomPaint),
    );
    final repaintBoundary = find.descendant(
      of: starrySky,
      matching: find.byType(RepaintBoundary),
    );

    expect(customPaint, findsOneWidget);
    expect(repaintBoundary, findsOneWidget);
    expect(
      find.descendant(of: starrySky, matching: find.byType(AnimatedBuilder)),
      findsNothing,
    );

    final firstPainter =
        tester.widget<CustomPaint>(customPaint).painter! as StarPainter;
    expect(firstPainter.stars, hasLength(100));
    expect(firstPainter.hangingStars, hasLength(8));

    await tester.pump(const Duration(milliseconds: 16));

    final secondPainter =
        tester.widget<CustomPaint>(customPaint).painter! as StarPainter;
    expect(identical(secondPainter, firstPainter), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('starry sky renders without errors on $platform', (
      tester,
    ) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      if (platform == TargetPlatform.windows) {
        tester.view.physicalSize = const Size(1280, 720);
        tester.view.devicePixelRatio = 1;
      } else {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3;
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: const SizedBox.expand(child: StarrySkyWidget()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
