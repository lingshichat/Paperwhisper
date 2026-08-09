import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/security/application/lock_controller.dart';

/// 注入替身：不触碰 AuthService / local_auth / SharedPreferences（无 plugin / IO）。
class _FakeLockGateway implements LockAuthGateway {
  bool visible = false;
  bool biometricEnabled = false;
  bool canCheck = false;
  String? storedPin;
  bool? authenticateResult;
  bool throwOnVerify = false;
  bool throwOnSetPin = false;
  bool throwOnAuthenticate = false;
  Completer<void>? verifyGate;
  final verifyCalls = <String>[];
  final setPinCalls = <String>[];
  int unlockCalls = 0;
  int biometricEnabledCalls = 0;
  int canCheckCalls = 0;

  @override
  void setLockScreenVisible(bool value) => visible = value;

  @override
  Future<bool> isBiometricEnabled() async {
    biometricEnabledCalls++;
    return biometricEnabled;
  }

  @override
  Future<bool> canCheckBiometrics() async {
    canCheckCalls++;
    return canCheck;
  }

  @override
  Future<bool> verifyPin(String pin) async {
    if (verifyGate != null) await verifyGate!.future;
    if (throwOnVerify) throw Exception('verify boom');
    verifyCalls.add(pin);
    return pin == storedPin;
  }

  @override
  Future<void> setPin(String pin) async {
    if (throwOnSetPin) throw Exception('setPin boom');
    setPinCalls.add(pin);
    storedPin = pin;
  }

  @override
  Future<bool> authenticateBiometric() async {
    if (throwOnAuthenticate) throw Exception('bio boom');
    return authenticateResult ?? false;
  }

  @override
  void unlockApp() => unlockCalls++;
}

LockController _controller(
  _FakeLockGateway gateway, {
  LockScreenMode mode = LockScreenMode.unlock,
}) => LockController(gateway: gateway, mode: mode);

void main() {
  group('LockController 按键输入：4 位限制与删除', () {
    test('appendDigit 逐位追加，第 4 位返回 readyToSubmit，其余 moreInput', () {
      final gateway = _FakeLockGateway();
      final controller = _controller(gateway);

      expect(controller.pinLength, 4);
      expect(controller.inputPin, '');

      expect(controller.appendDigit('1'), PinKeyResult.moreInput);
      expect(controller.appendDigit('2'), PinKeyResult.moreInput);
      expect(controller.appendDigit('3'), PinKeyResult.moreInput);
      expect(controller.inputPin, '123');

      expect(controller.appendDigit('4'), PinKeyResult.readyToSubmit);
      expect(controller.inputPin, '1234');
    });

    test('满 4 位后继续输入无效（不追加、不触发 submit）', () {
      final gateway = _FakeLockGateway();
      final controller = _controller(gateway);
      controller.appendDigit('1');
      controller.appendDigit('2');
      controller.appendDigit('3');
      controller.appendDigit('4');

      expect(controller.appendDigit('5'), PinKeyResult.moreInput);
      expect(controller.inputPin, '1234');
    });

    test('delete 移除最后一位；空输入为 no-op', () {
      final gateway = _FakeLockGateway();
      final controller = _controller(gateway);

      expect(controller.delete(), PinKeyResult.moreInput);
      expect(controller.inputPin, '');

      controller.appendDigit('1');
      controller.appendDigit('2');
      controller.delete();
      expect(controller.inputPin, '1');

      controller.delete();
      expect(controller.inputPin, '');
      // 删空后再删仍是 no-op
      expect(controller.delete(), PinKeyResult.moreInput);
      expect(controller.inputPin, '');
    });
  });

  group('LockController unlock 模式', () {
    test('正确 PIN：先 verifyPin 后 unlockApp，返回 LockUnlocked', () async {
      final gateway = _FakeLockGateway()..storedPin = '1234';
      final controller = _controller(gateway);
      '1234'.split('').forEach(controller.appendDigit);

      final result = await controller.submit();

      expect(result, isA<LockUnlocked>());
      expect(gateway.verifyCalls, ['1234']);
      expect(gateway.unlockCalls, 1);
      expect(controller.inputPin, '1234'); // 成功不清空（页面随后 onUnlocked）
    });

    test('错误 PIN：返回 LockInvalid 并清空输入，不调用 unlockApp', () async {
      final gateway = _FakeLockGateway()..storedPin = '9999';
      final controller = _controller(gateway);
      '0000'.split('').forEach(controller.appendDigit);

      final result = await controller.submit();

      expect(result, isA<LockInvalid>());
      expect(gateway.verifyCalls, ['0000']);
      expect(gateway.unlockCalls, 0);
      expect(controller.inputPin, '');
    });
  });

  group('LockController verify 模式', () {
    test('旧 PIN 正确：返回 LockUnlocked 并 unlockApp', () async {
      final gateway = _FakeLockGateway()..storedPin = '2468';
      final controller = _controller(gateway, mode: LockScreenMode.verify);
      '2468'.split('').forEach(controller.appendDigit);

      final result = await controller.submit();

      expect(result, isA<LockUnlocked>());
      expect(gateway.verifyCalls, ['2468']);
      expect(gateway.unlockCalls, 1);
    });

    test('旧 PIN 错误：返回 LockInvalid 并清空，不调用 unlockApp', () async {
      final gateway = _FakeLockGateway()..storedPin = '2468';
      final controller = _controller(gateway, mode: LockScreenMode.verify);
      '1357'.split('').forEach(controller.appendDigit);

      final result = await controller.submit();

      expect(result, isA<LockInvalid>());
      expect(controller.inputPin, '');
      expect(gateway.unlockCalls, 0);
    });
  });

  group('LockController setup 模式', () {
    test('第一步：暂存 PIN、清空输入、切 confirm，返回 LockAwaitConfirmation', () async {
      final gateway = _FakeLockGateway();
      final controller = _controller(gateway, mode: LockScreenMode.setup);
      '1234'.split('').forEach(controller.appendDigit);

      final result = await controller.submit();

      expect(result, isA<LockAwaitConfirmation>());
      expect(controller.mode, LockScreenMode.confirm);
      expect(controller.tempPinForSetup, '1234');
      expect(controller.inputPin, '');
      expect(gateway.verifyCalls, isEmpty);
      expect(gateway.setPinCalls, isEmpty);
      expect(gateway.unlockCalls, 0);
    });
  });

  group('LockController confirm 模式', () {
    test('两次一致：先 setPin 后 unlockApp，返回 LockSetupCompleted', () async {
      final gateway = _FakeLockGateway();
      final controller = _controller(gateway, mode: LockScreenMode.setup);
      '1234'.split('').forEach(controller.appendDigit);
      await controller.submit(); // setup → confirm

      '1234'.split('').forEach(controller.appendDigit);
      final result = await controller.submit();

      expect(result, isA<LockSetupCompleted>());
      expect(gateway.setPinCalls, ['1234']);
      expect(gateway.unlockCalls, 1);
      expect(gateway.storedPin, '1234');
    });

    test('两次不一致：重置回 setup、清空暂存与输入，返回 LockMismatch', () async {
      final gateway = _FakeLockGateway();
      final controller = _controller(gateway, mode: LockScreenMode.setup);
      '1234'.split('').forEach(controller.appendDigit);
      await controller.submit(); // setup → confirm

      '0000'.split('').forEach(controller.appendDigit);
      final result = await controller.submit();

      expect(result, isA<LockMismatch>());
      expect(controller.mode, LockScreenMode.setup);
      expect(controller.tempPinForSetup, isNull);
      expect(controller.inputPin, '');
      expect(gateway.setPinCalls, isEmpty);
      expect(gateway.unlockCalls, 0);
    });

    test('不匹配重置后重新 setup→confirm 一致：完整流程成功', () async {
      final gateway = _FakeLockGateway();
      final controller = _controller(gateway, mode: LockScreenMode.setup);

      '1111'.split('').forEach(controller.appendDigit);
      await controller.submit(); // setup → confirm
      '2222'.split('').forEach(controller.appendDigit);
      await controller.submit(); // 不一致 → 重置回 setup

      '5678'.split('').forEach(controller.appendDigit);
      await controller.submit(); // setup → confirm
      '5678'.split('').forEach(controller.appendDigit);
      final result = await controller.submit();

      expect(result, isA<LockSetupCompleted>());
      expect(gateway.setPinCalls, ['5678']);
      expect(gateway.unlockCalls, 1);
    });
  });

  group('LockController initialize：visible 与生物识别', () {
    test('unlock 模式且生物识别开启且设备支持：available=true，useBiometric=true', () async {
      final gateway = _FakeLockGateway()
        ..biometricEnabled = true
        ..canCheck = true;
      final controller = _controller(gateway);

      await controller.initialize();

      expect(gateway.visible, isTrue);
      expect(controller.biometricAvailable, isTrue);
      expect(controller.useBiometric, isTrue);
    });

    test('unlock 模式但生物识别未开启或设备不支持：available=false', () async {
      final gateway = _FakeLockGateway()
        ..biometricEnabled = false
        ..canCheck = true;
      final controller = _controller(gateway);
      await controller.initialize();
      expect(controller.biometricAvailable, isFalse);
      expect(controller.useBiometric, isFalse);

      final gateway2 = _FakeLockGateway()
        ..biometricEnabled = true
        ..canCheck = false;
      final controller2 = _controller(gateway2);
      await controller2.initialize();
      expect(controller2.biometricAvailable, isFalse);
      expect(controller2.useBiometric, isFalse);
    });

    test('非 unlock 模式不查询生物识别，但 visible 仍置 true', () async {
      final gateway = _FakeLockGateway();
      final controller = _controller(gateway, mode: LockScreenMode.setup);

      await controller.initialize();

      expect(gateway.visible, isTrue);
      expect(gateway.biometricEnabledCalls, 0);
      expect(gateway.canCheckCalls, 0);
      expect(controller.biometricAvailable, isFalse);
      expect(controller.useBiometric, isFalse);
    });
  });

  group('LockController 生物识别', () {
    test('认证通过：调用 unlockApp，返回 authenticated', () async {
      final gateway = _FakeLockGateway()..authenticateResult = true;
      final controller = _controller(gateway);

      final result = await controller.authenticateBiometric();

      expect(result, LockBiometricResult.authenticated);
      expect(gateway.unlockCalls, 1);
    });

    test('认证失败/取消：不调用 unlockApp，返回 failed', () async {
      final gateway = _FakeLockGateway()..authenticateResult = false;
      final controller = _controller(gateway);

      final result = await controller.authenticateBiometric();

      expect(result, LockBiometricResult.failed);
      expect(gateway.unlockCalls, 0);
    });
  });

  group('LockController setUseBiometric', () {
    test('设置 true/false 反映到 getter', () {
      final gateway = _FakeLockGateway();
      final controller = _controller(gateway);

      controller.setUseBiometric(true);
      expect(controller.useBiometric, isTrue);

      controller.setUseBiometric(false);
      expect(controller.useBiometric, isFalse);
    });
  });

  group('LockController visible ownership', () {
    test('initialize 置 visible=true，dispose 置回 false', () async {
      final gateway = _FakeLockGateway();
      final controller = _controller(gateway);

      expect(gateway.visible, isFalse);
      await controller.initialize();
      expect(gateway.visible, isTrue);

      controller.dispose();
      expect(gateway.visible, isFalse);
    });
  });

  group('LockController 异常与 dispose', () {
    test('verifyPin 抛异常：submit 传播异常且不改状态', () async {
      final gateway = _FakeLockGateway()..throwOnVerify = true;
      final controller = _controller(gateway);
      '1234'.split('').forEach(controller.appendDigit);

      await expectLater(controller.submit(), throwsException);
      expect(controller.inputPin, '1234'); // 异常路径不清空
      expect(gateway.unlockCalls, 0);
    });

    test('setPin 抛异常：confirm 一致时 submit 传播异常', () async {
      final gateway = _FakeLockGateway()..throwOnSetPin = true;
      final controller = _controller(gateway, mode: LockScreenMode.setup);
      '1234'.split('').forEach(controller.appendDigit);
      await controller.submit();
      '1234'.split('').forEach(controller.appendDigit);

      await expectLater(controller.submit(), throwsException);
      expect(gateway.unlockCalls, 0);
    });

    test('authenticateBiometric 抛异常：传播异常', () async {
      final gateway = _FakeLockGateway()..throwOnAuthenticate = true;
      final controller = _controller(gateway);

      await expectLater(controller.authenticateBiometric(), throwsException);
      expect(gateway.unlockCalls, 0);
    });

    test('dispose 后所有公开方法抛 StateError，不再变更状态', () async {
      final gateway = _FakeLockGateway();
      final controller = _controller(gateway);
      await controller.initialize();
      controller.dispose();

      expect(() => controller.appendDigit('1'), throwsStateError);
      expect(() => controller.delete(), throwsStateError);
      expect(() => controller.setUseBiometric(true), throwsStateError);
      await expectLater(controller.submit(), throwsStateError);
      await expectLater(controller.initialize(), throwsStateError);
      await expectLater(controller.authenticateBiometric(), throwsStateError);
      // 状态冻结：不再产生任何认证副作用
      expect(gateway.verifyCalls, isEmpty);
      expect(gateway.setPinCalls, isEmpty);
      expect(gateway.unlockCalls, 0);
      expect(controller.inputPin, '');
    });

    test('异步进行中 dispose：Future 以 StateError 结束，visible 冻结', () async {
      final gateway = _FakeLockGateway()..verifyGate = Completer<void>();
      final controller = _controller(gateway);
      '1234'.split('').forEach(controller.appendDigit);

      final future = controller.submit();
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      gateway.verifyGate!.complete();

      await expectLater(future, throwsStateError);
      expect(gateway.visible, isFalse);
      expect(gateway.unlockCalls, 0);
    });
  });
}
