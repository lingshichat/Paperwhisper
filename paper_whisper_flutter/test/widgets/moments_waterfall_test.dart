import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment.dart';
import 'package:paper_whisper_flutter/features/moments/presentation/widgets/moment_card.dart';
import 'package:paper_whisper_flutter/features/moments/presentation/widgets/moments_waterfall.dart';
import 'package:paper_whisper_flutter/features/settings/application/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ThemeRegistry.init);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  List<Moment> moments(int count) {
    final start = DateTime(2026, 8, 23, 9);
    return List<Moment>.generate(
      count,
      (index) => Moment(
        uuid: 'moment-$index',
        content: '随心记 $index',
        images: const [],
        createdAt: start.add(Duration(minutes: index)),
      ),
    );
  }

  Future<void> pumpWaterfall(
    WidgetTester tester, {
    required double width,
    required List<Moment> moments,
  }) async {
    tester.view.physicalSize = Size(width, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(),
        child: MaterialApp(
          theme: AppTheme.getThemeData(AppTheme.themeDefault),
          home: Scaffold(
            body: MomentsWaterfall(
              moments: moments,
              baseDir: null,
              onDelete: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('首屏按需构建且滚动可达最早记录', (tester) async {
    final data = moments(40);
    await pumpWaterfall(tester, width: 900, moments: data);

    expect(find.byType(MasonryGridView), findsOneWidget);
    expect(find.text('随心记 39'), findsOneWidget);
    expect(find.byType(MomentCard).evaluate().length, lessThan(data.length));
    expect(
      find.ancestor(
        of: find.byType(MasonryGridView),
        matching: find.byType(BackdropGroup),
      ),
      findsOneWidget,
    );

    for (var i = 0; i < 30 && find.text('随心记 0').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(MasonryGridView), const Offset(0, -500));
      await tester.pump();
    }

    expect(find.text('随心记 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('保持 1/2/3 列阈值与 24px 间距', (tester) async {
    final data = moments(6);

    for (final expectation in <(double, int)>[(700, 1), (900, 2), (1300, 3)]) {
      await pumpWaterfall(tester, width: expectation.$1, moments: data);

      final grid = tester.widget<MasonryGridView>(find.byType(MasonryGridView));
      final delegate =
          grid.gridDelegate as SliverSimpleGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, expectation.$2);
      expect(grid.mainAxisSpacing, 24);
      expect(grid.crossAxisSpacing, 24);
      expect(grid.padding, const EdgeInsets.fromLTRB(40, 20, 40, 100));
    }
  });
}
