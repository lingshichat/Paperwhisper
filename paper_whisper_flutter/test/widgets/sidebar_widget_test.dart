import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/app/shell/data/hitokoto_service.dart';
import 'package:paper_whisper_flutter/app/shell/sidebar_widget.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/settings/application/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ThemeRegistry.init);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Drawer 不启用整栏 blur，固定侧栏保留 blur', (tester) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final settings = SettingsProvider();
    await settings.setTheme(AppTheme.themeSeaFlower);
    addTearDown(settings.dispose);

    Widget app(Widget sidebar) {
      return ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          theme: AppTheme.getThemeData(AppTheme.themeSeaFlower),
          home: Scaffold(body: sidebar),
        ),
      );
    }

    await tester.pumpWidget(
      app(
        const Drawer(
          child: SidebarWidget(activeSection: SidebarSection.writer),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FutureBuilder<HitokotoLine?>), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);

    // 首次抽屉动画期间不应再有延迟 180ms 的 blur 状态切换。
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.pumpWidget(
      app(const SidebarWidget(activeSection: SidebarSection.writer)),
    );
    await tester.pump();

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
