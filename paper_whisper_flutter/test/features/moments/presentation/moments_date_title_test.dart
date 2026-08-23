import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/moments/presentation/widgets/moments_date_title.dart';

void main() {
  testWidgets('顶栏日期文字居中，箭头不参与居中', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: MomentsDateTitle(
              selectedDate: DateTime(2026, 3, 10),
              textColor: Colors.white,
              iconColor: Colors.white,
              expanded: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final dateX = tester.getCenter(find.text('2026年3月')).dx;
    final subtitleX = tester.getCenter(find.text('随心记')).dx;
    expect(dateX, closeTo(subtitleX, 1.0));
    expect(find.byIcon(Icons.image), findsNothing);
  });
}
