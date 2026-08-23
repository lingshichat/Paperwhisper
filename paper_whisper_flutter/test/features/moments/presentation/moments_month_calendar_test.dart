import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/moments/application/moment_index.dart';
import 'package:paper_whisper_flutter/features/moments/presentation/widgets/moments_month_calendar.dart';

void main() {
  setUpAll(ThemeRegistry.init);

  Future<void> pumpCalendar(
    WidgetTester tester, {
    required DateTime selectedDate,
    required bool Function(DateTime date) hasContentOnDate,
    ValueChanged<DateTime>? onDateSelected,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getThemeData(AppTheme.themeDefault),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(360, 800)),
          child: Scaffold(
            body: Column(
              children: [
                MomentsMonthCalendar(
                  selectedDate: selectedDate,
                  startDate: startDate ?? DateTime(2021, 3, 10),
                  endDate: endDate ?? DateTime(2031, 3, 10),
                  hasContentOnDate: hasContentOnDate,
                  onDateSelected: onDateSelected ?? (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('占用标记 Key：有记录出现、无记录找不到', (tester) async {
    await pumpCalendar(
      tester,
      selectedDate: DateTime(2026, 3, 10),
      hasContentOnDate: (d) => MomentIndex.dayKey(d) == '2026-3-12',
    );

    expect(
      find.byKey(const ValueKey('moments_cal_mark_2026-3-12')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('moments_cal_mark_2026-3-11')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('点选日期格子触发 onDateSelected', (tester) async {
    DateTime? selected;
    await pumpCalendar(
      tester,
      selectedDate: DateTime(2026, 3, 10),
      hasContentOnDate: (d) => MomentIndex.dayKey(d) == '2026-3-12',
      onDateSelected: (d) => selected = d,
    );

    await tester.tap(find.byKey(const ValueKey('moments_cal_2026-3-12')));
    await tester.pump();

    expect(selected, DateTime(2026, 3, 12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('360×800 无溢出，面板高度 ≤296，头栏高度 ==40', (tester) async {
    await pumpCalendar(
      tester,
      selectedDate: DateTime(2026, 3, 10),
      hasContentOnDate: (d) => MomentIndex.dayKey(d) == '2026-3-12',
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(MomentsMonthCalendar)).height,
      lessThanOrEqualTo(296),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('moments_cal_header'))).height,
      40,
    );
  });

  testWidgets('月份标题相对面板几何中心居中，不受左右按钮影响', (tester) async {
    await pumpCalendar(
      tester,
      selectedDate: DateTime(2026, 3, 10),
      hasContentOnDate: (_) => false,
    );

    final calendar = tester.getRect(find.byType(MomentsMonthCalendar));
    final title = tester.getCenter(
      find.byKey(const ValueKey('moments_cal_month_title_2026_3')),
    );
    expect(title.dx, closeTo(calendar.center.dx, 1.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('横向滑动切到下一月，标题与格子一起滑入', (tester) async {
    await pumpCalendar(
      tester,
      selectedDate: DateTime(2026, 3, 10),
      hasContentOnDate: (_) => false,
    );

    await tester.fling(
      find.byKey(const ValueKey('moments_cal_pager')),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    final calendar = tester.getRect(find.byType(MomentsMonthCalendar));
    final aprilTitle = tester.getCenter(
      find.byKey(const ValueKey('moments_cal_month_title_2026_4')),
    );
    expect(calendar.contains(aprilTitle), isTrue);
    expect(aprilTitle.dx, closeTo(calendar.center.dx, 1.0));
    expect(
      calendar.contains(
        tester.getCenter(find.byKey(const ValueKey('moments_cal_2026-4-1'))),
      ),
      isTrue,
    );

    final pager = tester.widget<PageView>(
      find.byKey(const ValueKey('moments_cal_pager')),
    );
    final startMonth = DateTime(2021, 3);
    final april = DateTime(2026, 4);
    expect(
      pager.controller!.page!.round(),
      (april.year - startMonth.year) * 12 + (april.month - startMonth.month),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('点右箭头带动画切到下一月', (tester) async {
    await pumpCalendar(
      tester,
      selectedDate: DateTime(2026, 3, 10),
      hasContentOnDate: (_) => false,
    );

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final calendar = tester.getRect(find.byType(MomentsMonthCalendar));
    final aprilTitle = tester.getCenter(
      find.byKey(const ValueKey('moments_cal_month_title_2026_4')),
    );
    expect(calendar.contains(aprilTitle), isTrue);
    expect(tester.takeException(), isNull);
  });
}
