import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:paper_whisper_flutter/features/settings/presentation/widgets/settings_choice_sheet.dart';

void main() {
  setUp(() {
    // 测试环境禁用运行时字体拉取，避免网络请求与字体加载噪音。
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const style = SettingsChoiceSheetStyle(
    backgroundColor: Color(0xFFF4ECD8),
    titleColor: Color(0xFF3E3A36),
    tapeColor: Color(0xFFD7CCC8),
    shadows: [BoxShadow(color: Colors.black26, blurRadius: 12)],
    border: null,
    showTape: true,
    selectedBackgroundColor: Color(0xFF8D6E63),
    unselectedBackgroundColor: Color(0xFFFFFFFF),
    selectedTextColor: Color(0xFFFFFFFF),
    unselectedTextColor: Color(0xFF3E3A36),
  );

  /// 弹层宿主：模拟 showModalBottomSheet，返回后可用 find 断言 sheet 是否关闭。
  Widget host(Widget sheet) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => sheet,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
  }

  group('SettingsChoiceSheet', () {
    testWidgets('按 options 顺序渲染全部选项且选中项带 check', (tester) async {
      await tester.pumpWidget(
        host(
          const SettingsChoiceSheet<String>(
            title: '选择主题',
            options: [
              SettingsChoiceOption(label: '复古纸张', value: 'default'),
              SettingsChoiceOption(label: '午夜星尘', value: 'midnight'),
              SettingsChoiceOption(label: '言叶之庭', value: 'garden_of_words'),
            ],
            selected: 'midnight',
            onSelected: _noop,
            style: style,
          ),
        ),
      );

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      // 顺序与文案逐字保持。
      expect(find.text('选择主题'), findsOneWidget);
      final optionLabels = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      expect(
        optionLabels.indexOf('复古纸张'),
        lessThan(optionLabels.indexOf('午夜星尘')),
      );
      expect(
        optionLabels.indexOf('午夜星尘'),
        lessThan(optionLabels.indexOf('言叶之庭')),
      );

      // 仅选中项渲染 check 图标。
      expect(find.byIcon(Icons.check), findsOneWidget);
      final checkParent = find.ancestor(
        of: find.byIcon(Icons.check),
        matching: find.byType(Container),
      );
      expect(
        find.descendant(of: checkParent, matching: find.text('午夜星尘')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('选择触发 onSelected 并携带 typed value', (tester) async {
      String? selected;
      await tester.pumpWidget(
        host(
          SettingsChoiceSheet<String>(
            title: '选择启动页',
            options: const [
              SettingsChoiceOption(label: '专注书写', value: 'writer'),
              SettingsChoiceOption(label: '随心记', value: 'moments'),
            ],
            selected: 'writer',
            onSelected: (v) => selected = v,
            closeOnSelect: false,
            style: style,
          ),
        ),
      );

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('随心记'));
      await tester.pump();
      expect(selected, 'moments');
      expect(tester.takeException(), isNull);
    });

    testWidgets('closeOnSelect=true 时选择后自动关闭', (tester) async {
      await tester.pumpWidget(
        host(
          const SettingsChoiceSheet<String>(
            title: '选择启动页',
            options: [
              SettingsChoiceOption(label: '专注书写', value: 'writer'),
              SettingsChoiceOption(label: '随心记', value: 'moments'),
            ],
            selected: 'writer',
            onSelected: _noop,
            style: style,
          ),
        ),
      );

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.text('选择启动页'), findsOneWidget);

      await tester.tap(find.text('随心记'));
      await tester.pumpAndSettle();

      // 选择后弹层关闭（与原启动页选择行为一致）。
      expect(find.text('选择启动页'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('closeOnSelect=false 时选择后保持打开', (tester) async {
      await tester.pumpWidget(
        host(
          const SettingsChoiceSheet<String>(
            title: '选择主题',
            options: [
              SettingsChoiceOption(label: '复古纸张', value: 'default'),
              SettingsChoiceOption(label: '午夜星尘', value: 'midnight'),
            ],
            selected: 'default',
            onSelected: _noop,
            closeOnSelect: false,
            style: style,
          ),
        ),
      );

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('午夜星尘'));
      await tester.pumpAndSettle();

      // 主题面板保持打开（实时预览语义，与原行为一致）。
      expect(find.text('选择主题'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('int typed value 也能正确判定选中', (tester) async {
      int? selected;
      await tester.pumpWidget(
        host(
          SettingsChoiceSheet<int>(
            title: '选择数量',
            options: const [
              SettingsChoiceOption(label: '一', value: 1),
              SettingsChoiceOption(label: '二', value: 2),
            ],
            selected: 1,
            onSelected: (v) => selected = v,
            style: style,
          ),
        ),
      );

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(find.text('二'));
      await tester.pumpAndSettle();
      expect(selected, 2);
      expect(find.text('选择数量'), findsNothing); // 默认 closeOnSelect=true
      expect(tester.takeException(), isNull);
    });
  });
}

void _noop(String _) {}
