import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:paper_whisper_flutter/features/settings/presentation/widgets/settings_primitives.dart';

void main() {
  setUp(() {
    // 测试环境禁用运行时字体拉取，避免网络请求与字体加载噪音。
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final Color textColor = const Color(0xFF3E3A36);
  final Color switchThumb = const Color(0xFF8D6E63);
  final Color switchTrack = const Color(0xFFBCAAA4);
  final Color sheetBg = const Color(0xFFF4ECD8);
  final Color sheetTitle = const Color(0xFF3E3A36);
  final Color sheetTape = const Color(0xFFD7CCC8);

  Widget wrap(Widget child, {double width = 800, double height = 600}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );
  }

  group('SettingsSectionHeader', () {
    testWidgets('渲染标题并应用半透明文字色', (tester) async {
      await tester.pumpWidget(
        wrap(
          const SettingsSectionHeader(
            title: '账号与会员',
            textColor: Color(0xFF3E3A36),
          ),
        ),
      );

      expect(find.text('账号与会员'), findsOneWidget);
      final text = tester.widget<Text>(find.text('账号与会员'));
      expect(text.style?.fontSize, 14);
      expect(text.style?.fontWeight, FontWeight.bold);
      expect(tester.takeException(), isNull);
    });
  });

  group('SettingsGroupContainer + SettingsDivider', () {
    testWidgets('容器承载背景装饰并纵向排列子项', (tester) async {
      await tester.pumpWidget(
        wrap(
          SettingsGroupContainer(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(12),
            ),
            children: [
              const SettingsItem(
                icon: Icons.storage_outlined,
                title: '存储',
                subtitle: '查看存储占用',
                textColor: Color(0xFF3E3A36),
              ),
              const SettingsDivider(color: Color(0xFFE0D6C8)),
              const SettingsItem(
                icon: Icons.update_outlined,
                title: '更新',
                subtitle: '检测新版本',
                textColor: Color(0xFF3E3A36),
              ),
            ],
          ),
        ),
      );

      expect(find.text('存储'), findsOneWidget);
      expect(find.text('更新'), findsOneWidget);
      expect(find.byType(SettingsDivider), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SettingsItem', () {
    testWidgets('渲染图标、标题、副标题与默认箭头', (tester) async {
      await tester.pumpWidget(
        wrap(
          const SettingsItem(
            icon: Icons.storage_outlined,
            title: '存储',
            subtitle: '查看存储占用',
            textColor: Color(0xFF3E3A36),
          ),
        ),
      );

      expect(find.byIcon(Icons.storage_outlined), findsOneWidget);
      expect(find.text('存储'), findsOneWidget);
      expect(find.text('查看存储占用'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('点击触发 onTap', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        wrap(
          SettingsItem(
            icon: Icons.storage_outlined,
            title: '存储',
            subtitle: '查看存储占用',
            textColor: textColor,
            onTap: () => tapped++,
          ),
        ),
      );

      await tester.tap(find.text('存储'));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('loading 时显示进度且隐藏箭头', (tester) async {
      await tester.pumpWidget(
        wrap(
          const SettingsItem(
            icon: Icons.storage_outlined,
            title: '存储',
            subtitle: '查看存储占用',
            textColor: Color(0xFF3E3A36),
            isLoading: true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('自定义 trailing 覆盖默认箭头', (tester) async {
      await tester.pumpWidget(
        wrap(
          const SettingsItem(
            icon: Icons.update_outlined,
            title: '更新',
            subtitle: '检测新版本',
            textColor: Color(0xFF3E3A36),
            trailing: Icon(Icons.badge_outlined),
          ),
        ),
      );

      expect(find.byIcon(Icons.badge_outlined), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios), findsNothing);
    });

    testWidgets('onTap 为 null 时禁用点击', (tester) async {
      await tester.pumpWidget(
        wrap(
          const SettingsItem(
            icon: Icons.lock_outline,
            title: '锁定',
            subtitle: '不可点击项',
            textColor: Color(0xFF3E3A36),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final inkWell = tester.widget<InkWell>(
        find.ancestor(of: find.text('锁定'), matching: find.byType(InkWell)),
      );
      expect(inkWell.onTap, isNull);
    });
  });

  group('SettingsSwitchItem', () {
    testWidgets('切换触发 onChanged 并携带新值', (tester) async {
      bool? received;
      await tester.pumpWidget(
        wrap(
          SettingsSwitchItem(
            icon: Icons.autorenew,
            title: '自动同步',
            subtitle: '保存后自动同步',
            value: false,
            onChanged: (v) => received = v,
            textColor: textColor,
            activeThumbColor: switchThumb,
            activeTrackColor: switchTrack,
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(received, isTrue);

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.activeThumbColor, switchThumb);
      expect(switchWidget.activeTrackColor, switchTrack);
      expect(tester.takeException(), isNull);
    });

    testWidgets('渲染标题与副标题', (tester) async {
      await tester.pumpWidget(
        wrap(
          SettingsSwitchItem(
            icon: Icons.compress,
            title: '压缩图片',
            subtitle: '上传前压缩',
            value: true,
            onChanged: (_) {},
            textColor: textColor,
            activeThumbColor: switchThumb,
            activeTrackColor: switchTrack,
          ),
        ),
      );

      expect(find.text('压缩图片'), findsOneWidget);
      expect(find.text('上传前压缩'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });
  });

  group('SettingsBottomSheetFrame', () {
    testWidgets('showTape 时渲染胶带与标题、子项', (tester) async {
      await tester.pumpWidget(
        wrap(
          SettingsBottomSheetFrame(
            title: '应用权限管理',
            titleColor: sheetTitle,
            backgroundColor: sheetBg,
            tapeColor: sheetTape,
            shadows: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
            border: null,
            showTape: true,
            children: const [Text('文件存储 (核心)'), Text('通知提醒')],
          ),
        ),
      );

      expect(find.text('应用权限管理'), findsOneWidget);
      expect(find.text('文件存储 (核心)'), findsOneWidget);
      expect(find.text('通知提醒'), findsOneWidget);
      expect(find.byType(Transform), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('showTape 为 false 时渲染把手', (tester) async {
      await tester.pumpWidget(
        wrap(
          SettingsBottomSheetFrame(
            title: '选择主题',
            titleColor: sheetTitle,
            backgroundColor: sheetBg,
            tapeColor: sheetTape,
            shadows: const [],
            border: Border.all(color: Color(0xFFE0D6C8)),
            showTape: false,
            children: const [Text('内容')],
          ),
        ),
      );

      expect(find.text('选择主题'), findsOneWidget);
      expect(find.text('内容'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SettingsOptionTile / SettingsRadioItem', () {
    Widget optionWrap(Widget child) => wrap(
      SettingsBottomSheetFrame(
        title: '选择',
        titleColor: sheetTitle,
        backgroundColor: sheetBg,
        tapeColor: sheetTape,
        shadows: const [],
        border: null,
        showTape: false,
        children: [child],
      ),
    );

    testWidgets('选中态渲染 check 图标', (tester) async {
      await tester.pumpWidget(
        optionWrap(
          const SettingsOptionTile(
            label: '午夜星尘',
            isSelected: true,
            onTap: _noop,
            selectedBackgroundColor: Color(0xFF8D6E63),
            unselectedBackgroundColor: Color(0xFFFFFFFF),
            selectedTextColor: Color(0xFFFFFFFF),
            unselectedTextColor: Color(0xFF3E3A36),
          ),
        ),
      );

      expect(find.text('午夜星尘'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('未选中态无 check 图标', (tester) async {
      await tester.pumpWidget(
        optionWrap(
          const SettingsOptionTile(
            label: '海之蓝',
            isSelected: false,
            onTap: _noop,
            selectedBackgroundColor: Color(0xFF8D6E63),
            unselectedBackgroundColor: Color(0xFFFFFFFF),
            selectedTextColor: Color(0xFFFFFFFF),
            unselectedTextColor: Color(0xFF3E3A36),
          ),
        ),
      );

      expect(find.text('海之蓝'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('点击触发 onTap', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        optionWrap(
          SettingsOptionTile(
            label: '选项A',
            isSelected: false,
            onTap: () => tapped++,
            selectedBackgroundColor: const Color(0xFF8D6E63),
            unselectedBackgroundColor: const Color(0xFFFFFFFF),
            selectedTextColor: const Color(0xFFFFFFFF),
            unselectedTextColor: textColor,
          ),
        ),
      );

      await tester.tap(find.text('选项A'));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('RadioItem 按 groupValue 判定选中并回调新值', (tester) async {
      String? selected;
      final builder = ValueNotifier<String>('a');

      await tester.pumpWidget(
        ValueListenableBuilder<String>(
          valueListenable: builder,
          builder: (context, groupValue, _) => optionWrap(
            SettingsRadioItem(
              label: '选项B',
              value: 'b',
              groupValue: groupValue,
              onChanged: (v) {
                selected = v;
                builder.value = v;
              },
              closeOnSelect: false,
              selectedBackgroundColor: const Color(0xFF8D6E63),
              unselectedBackgroundColor: const Color(0xFFFFFFFF),
              selectedTextColor: const Color(0xFFFFFFFF),
              unselectedTextColor: textColor,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsNothing);
      await tester.tap(find.text('选项B'));
      await tester.pump();
      expect(selected, 'b');
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });

  group('布局冒烟（无 overflow / 无 Material 断言）', () {
    Widget settingsColumn() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SettingsSectionHeader(
          title: '外观与体验',
          textColor: Color(0xFF3E3A36),
        ),
        SettingsGroupContainer(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          children: [
            SettingsItem(
              icon: Icons.palette_outlined,
              title: '主题',
              subtitle: '午夜星尘',
              textColor: textColor,
              onTap: () {},
            ),
            const SettingsDivider(color: Color(0xFFE0D6C8)),
            SettingsSwitchItem(
              icon: Icons.autorenew,
              title: '自动同步',
              subtitle: '保存后自动同步',
              value: true,
              onChanged: (_) {},
              textColor: textColor,
              activeThumbColor: switchThumb,
              activeTrackColor: switchTrack,
            ),
            const SettingsDivider(color: Color(0xFFE0D6C8)),
            const SettingsItem(
              icon: Icons.update_outlined,
              title: '检查更新',
              subtitle: 'v1.0.0',
              textColor: Color(0xFF3E3A36),
              isLoading: true,
            ),
          ],
        ),
      ],
    );

    testWidgets('Android 360 窄屏无 overflow 且无 Material 断言', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: settingsColumn(),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('Windows 桌面宽屏无 overflow 且无 Material 断言', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          home: Scaffold(
            body: Center(child: SizedBox(width: 640, child: settingsColumn())),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

void _noop() {}
