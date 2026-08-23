import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/diary/data/diary_entry.dart';
import 'package:paper_whisper_flutter/features/diary/presentation/widgets/diary_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ThemeRegistry.init);

  DiaryEntry entry(int index) {
    return DiaryEntry(
      filename: '2026-08-0${index + 1}_$index.txt',
      dateString: '2026-08-0${index + 1}',
      title: '日记 $index',
      content: '用于验证卡片滤镜渲染边界。',
    );
  }

  Future<void> pumpCards(
    WidgetTester tester, {
    required String theme,
    required BackdropKey backdropKey,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getThemeData(theme),
        home: Scaffold(
          body: BackdropGroup(
            backdropKey: backdropKey,
            child: Column(
              children: [
                DiaryCard(entry: entry(0), theme: theme),
                DiaryCard(entry: entry(1), theme: theme),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('非玻璃主题不创建 BackdropFilter', (tester) async {
    await pumpCards(
      tester,
      theme: AppTheme.themeDefault,
      backdropKey: BackdropKey(),
    );

    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('同一列表内玻璃卡片共享 BackdropKey', (tester) async {
    final backdropKey = BackdropKey();
    await pumpCards(
      tester,
      theme: AppTheme.themeSeaFlower,
      backdropKey: backdropKey,
    );

    final filters = tester
        .renderObjectList<RenderBackdropFilter>(find.byType(BackdropFilter))
        .toList();
    expect(filters, hasLength(2));
    expect(
      filters.every((filter) => filter.backdropKey == backdropKey),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
