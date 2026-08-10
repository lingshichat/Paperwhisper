import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/config/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/pages/intro_page.dart';
import 'package:paper_whisper_flutter/pages/splash_page.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/services/auth_service.dart';
import 'package:paper_whisper_flutter/widgets/lock_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Splash 锁屏导航回归（route context 生命周期）。
///
/// 旧实现 `AppRoutes.pageFade(_buildLockScreenWrapper(context, ...))` 在
/// 调用时捕获 Splash 的 context；pushReplacement 后 Splash 被销毁，解锁
/// 回调经该 deactivated context 导航会抛
/// 「Looking up a deactivated widget's ancestor is unsafe」。
///
/// 修复后 LockScreen 在 route 的 pageBuilder 阶段经惰性 builder 构造，
/// 拿到 route 自身有效 context；本测试复现 locked → 触发 onUnlocked →
/// 导航到 startup 目标页，并断言无异常。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ThemeRegistry.init();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('locked：解锁回调经 route context 导航到目标页，无 deactivated context 异常', (
    tester,
  ) async {
    // 已同意隐私协议 + 已设置 PIN hash（AuthService.isLockEnabledSync 判定）
    SharedPreferences.setMockInitialValues({
      'privacy_agreed': true,
      'auth_pin_hash': 'deadbeef',
    });
    final prefs = await SharedPreferences.getInstance();
    AuthService().init(prefs);
    AuthService().lockApp();
    addTearDown(AuthService().unlockApp);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => SettingsProvider())],
        child: MaterialApp(
          home: SplashPage(showIntro: true, startupPage: 'writer'),
        ),
      ),
    );
    // 首帧后 postFrameCallback 触发 _initAndNavigate → pushReplacement 锁屏
    await tester.pumpAndSettle();

    expect(find.byType(LockScreen), findsOneWidget);

    // 触发解锁（等价 LockScreen._finish 的 onUnlocked 回调路径）
    tester.widget<LockScreen>(find.byType(LockScreen)).onUnlocked();
    await tester.pumpAndSettle();

    // 解锁后应导航到 startup 目标（showIntro=true → IntroPage），
    // 锁屏 route 被替换销毁；全程不得有 deactivated context 异常。
    expect(find.byType(LockScreen), findsNothing);
    expect(find.byType(IntroPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未锁定：直接导航到 startup 目标页（对照路径不受影响）', (tester) async {
    SharedPreferences.setMockInitialValues({'privacy_agreed': true});
    final prefs = await SharedPreferences.getInstance();
    AuthService().init(prefs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => SettingsProvider())],
        child: MaterialApp(
          home: SplashPage(showIntro: true, startupPage: 'writer'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LockScreen), findsNothing);
    expect(find.byType(IntroPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
