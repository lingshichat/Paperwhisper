import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/auth/application/lock_controller.dart';
import 'package:paper_whisper_flutter/features/auth/presentation/widgets/lock_screen.dart';
import 'package:paper_whisper_flutter/features/settings/application/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 注入替身：不触碰 AuthService / local_auth / SharedPreferences（无 plugin / IO）。
class _FakeLockGateway implements LockAuthGateway {
  bool visible = false;
  bool biometricEnabled = false;
  bool canCheck = false;
  String? storedPin;
  bool? authenticateResult;
  final setPinCalls = <String>[];
  int unlockCalls = 0;

  @override
  void setLockScreenVisible(bool value) => visible = value;

  @override
  Future<bool> isBiometricEnabled() async => biometricEnabled;

  @override
  Future<bool> canCheckBiometrics() async => canCheck;

  @override
  Future<bool> verifyPin(String pin) async => pin == storedPin;

  @override
  Future<void> setPin(String pin) async {
    setPinCalls.add(pin);
    storedPin = pin;
  }

  @override
  Future<bool> authenticateBiometric() async => authenticateResult ?? false;

  @override
  void unlockApp() => unlockCalls++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ThemeRegistry.init();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // 统一装配：SettingsProvider（LockScreen build 依赖）+
  // MaterialApp（ScaffoldMessenger 供 SkeuomorphicToast）。
  Future<_PumpResult> pumpLockScreen(
    WidgetTester tester, {
    LockScreenMode mode = LockScreenMode.unlock,
    VoidCallback? onUnlocked,
    _FakeLockGateway? gateway,
  }) async {
    final fake = gateway ?? _FakeLockGateway();
    final controller = LockController(gateway: fake, mode: mode);
    var unlocked = false;
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(),
        child: MaterialApp(
          theme: AppTheme.getThemeData(AppTheme.themeDefault),
          home: LockScreen(
            controller: controller,
            mode: mode,
            onUnlocked: () {
              unlocked = true;
              onUnlocked?.call();
            },
          ),
        ),
      ),
    );
    // 处理 initialize() 的异步查询
    await tester.pump();
    expect(tester.takeException(), isNull);
    return _PumpResult(fake, () => unlocked);
  }

  // 依次点击 PIN 数字键（SkeuomorphicKey 以文本标签渲染）。
  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
  }

  testWidgets('解锁：正确 PIN 触发 onUnlocked，controller 已 unlockApp', (tester) async {
    final result = await pumpLockScreen(
      tester,
      gateway: _FakeLockGateway()..storedPin = '1234',
    );

    await enterPin(tester, '1234');
    // 200ms submit 延迟
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(result.unlocked, isTrue);
    expect(result.gateway.unlockCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('解锁：错误 PIN 不触发 onUnlocked，无异常', (tester) async {
    final result = await pumpLockScreen(
      tester,
      gateway: _FakeLockGateway()..storedPin = '9999',
    );

    await enterPin(tester, '0000');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(result.unlocked, isFalse);
    expect(result.gateway.unlockCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('设置：setup→confirm 一致，成功提示并触发 onUnlocked', (tester) async {
    final result = await pumpLockScreen(tester, mode: LockScreenMode.setup);

    expect(find.text('请设置新密码'), findsOneWidget);

    await enterPin(tester, '1234');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    // 已进入 confirm 阶段
    expect(find.text('请再次确认密码'), findsOneWidget);
    expect(result.gateway.storedPin, isNull);

    await enterPin(tester, '1234');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(result.gateway.storedPin, '1234');
    expect(result.gateway.unlockCalls, 1);
    expect(find.text('密码设置成功'), findsOneWidget);
    expect(result.unlocked, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('设置：两次不一致，提示并重置回 setup，不触发 onUnlocked', (tester) async {
    final result = await pumpLockScreen(tester, mode: LockScreenMode.setup);

    await enterPin(tester, '1234');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.text('请再次确认密码'), findsOneWidget);

    await enterPin(tester, '0000');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(find.text('两次输入不一致'), findsOneWidget);
    // controller 已重置回 setup
    expect(find.text('请设置新密码'), findsOneWidget);
    expect(result.gateway.setPinCalls, isEmpty);
    expect(result.gateway.unlockCalls, 0);
    expect(result.unlocked, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('生物识别：可用时展示入口并自动触发，认证通过即解锁', (tester) async {
    final result = await pumpLockScreen(
      tester,
      gateway: _FakeLockGateway()
        ..biometricEnabled = true
        ..canCheck = true
        ..authenticateResult = true,
    );

    // 生物识别界面（入口动画 + 验证身份文案）
    expect(find.text('验证身份'), findsWidgets);

    // 原 500ms 自动触发 + trigger 内 500ms 延迟
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(result.unlocked, isTrue);
    expect(result.gateway.unlockCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('生物识别：自动触发失败留在界面，可切换到密码键盘', (tester) async {
    final result = await pumpLockScreen(
      tester,
      gateway: _FakeLockGateway()
        ..biometricEnabled = true
        ..canCheck = true
        ..authenticateResult = false,
    );

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    // 认证失败：不解锁、不崩溃
    expect(result.unlocked, isFalse);
    expect(result.gateway.unlockCalls, 0);
    expect(tester.takeException(), isNull);

    // 点击「使用密码」切回键盘
    await tester.tap(find.text('使用密码'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('请输入密码'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('释放：pending submit 期间 dispose 抛 StateError 静默，不崩溃不触发回调', (
    tester,
  ) async {
    final fake = _FakeLockGateway()..storedPin = '1234';
    final controller = LockController(gateway: fake);
    var unlocked = false;

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(),
        child: MaterialApp(
          theme: AppTheme.getThemeData(AppTheme.themeDefault),
          home: LockScreen(
            controller: controller,
            onUnlocked: () => unlocked = true,
          ),
        ),
      ),
    );
    await tester.pump();

    await enterPin(tester, '1234');
    await tester.pump(const Duration(milliseconds: 50));

    // 页面仍在，控制器先于 submit 完成被释放 → submit 抛 StateError 应被静默
    controller.dispose();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(unlocked, isFalse);
    expect(fake.unlockCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('渲染：Windows 桌面与 Android 360×800 均无溢出', (tester) async {
    // Windows 桌面
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await pumpLockScreen(
      tester,
      gateway: _FakeLockGateway()..storedPin = '1234',
    );
    expect(tester.takeException(), isNull);

    // Android 360×800 窄屏
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    await pumpLockScreen(
      tester,
      gateway: _FakeLockGateway()..storedPin = '1234',
    );
    expect(tester.takeException(), isNull);

    // flutter_test 在测试体结束时校验平台 override 必须已复位，
    // addTearDown 在其后才执行，因此测试体末尾显式复位一次。
    debugDefaultTargetPlatformOverride = null;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// pumpLockScreen 的返回包装：暴露 gateway 与 unlocked 状态。
class _PumpResult {
  _PumpResult(this.gateway, this.unlockedGetter);

  final _FakeLockGateway gateway;
  final bool Function() unlockedGetter;

  bool get unlocked => unlockedGetter();
}
