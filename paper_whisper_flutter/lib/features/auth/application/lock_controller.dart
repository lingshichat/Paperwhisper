import 'package:paper_whisper_flutter/features/auth/data/auth_service.dart';

/// 认证域的锁屏模式。
///
/// Presentation 层经 widgets/lock_screen.dart 继续 re-export，行为与文案不变。
enum LockScreenMode {
  /// 普通解锁。
  unlock,

  /// 设置新 PIN（第一步）。
  setup,

  /// 确认新 PIN（第二步）。
  confirm,

  /// 修改前验证旧 PIN。
  verify,
}

/// 按键结果：本次输入是否已凑满 4 位、需要页面触发 [LockController.submit]。
enum PinKeyResult {
  /// 未凑满，继续输入。
  moreInput,

  /// 已凑满 4 位，页面应触发 submit。
  readyToSubmit,
}

/// submit 的 typed 结果：页面据此决定 Toast / 错误动画 / onUnlocked。
sealed class LockSubmitResult {}

/// unlock / verify 校验通过（controller 已调用 [LockAuthGateway.unlockApp]）。
final class LockUnlocked extends LockSubmitResult {}

/// unlock / verify 校验失败，输入已清空（页面做错误动画）。
final class LockInvalid extends LockSubmitResult {}

/// setup 第一步完成，已进入 confirm 模式（输入已清空）。
final class LockAwaitConfirmation extends LockSubmitResult {}

/// confirm 两次一致，已 setPin + unlockApp（页面提示成功并触发 onUnlocked）。
final class LockSetupCompleted extends LockSubmitResult {}

/// confirm 两次不一致，已重置回 setup 模式（输入与暂存均已清空）。
final class LockMismatch extends LockSubmitResult {}

/// 生物识别 typed 结果。
enum LockBiometricResult {
  /// 认证通过（controller 已调用 unlockApp），页面应触发 onUnlocked。
  authenticated,

  /// 失败或取消，停留在当前界面。
  failed,
}

/// 锁屏数据网关（controller 唯一数据来源 seam，测试注入替身）。
///
/// 只透传 [AuthService] 的查询与动作，不复制任何算法。
abstract interface class LockAuthGateway {
  /// 生物识别开关是否开启。
  Future<bool> isBiometricEnabled();

  /// 设备是否支持生物识别。
  Future<bool> canCheckBiometrics();

  /// 校验 PIN 是否与存储的哈希一致。
  Future<bool> verifyPin(String pin);

  /// 保存新 PIN。
  Future<void> setPin(String pin);

  /// 触发系统生物识别，返回是否通过。
  Future<bool> authenticateBiometric();

  /// 解锁（清空锁定标记）。
  void unlockApp();

  /// 锁屏可见性标记（防重复锁屏，原 `AuthService.isLockScreenVisible`）。
  void setLockScreenVisible(bool visible);
}

/// 生产适配器：委托 [AuthService] 单例。
class LockAuthGatewayAdapter implements LockAuthGateway {
  LockAuthGatewayAdapter(this._authService);

  final AuthService _authService;

  @override
  Future<bool> isBiometricEnabled() => _authService.isBiometricEnabled();

  @override
  Future<bool> canCheckBiometrics() => _authService.canCheckBiometrics();

  @override
  Future<bool> verifyPin(String pin) => _authService.verifyPin(pin);

  @override
  Future<void> setPin(String pin) => _authService.setPin(pin);

  @override
  Future<bool> authenticateBiometric() => _authService.authenticateBiometric();

  @override
  void unlockApp() => _authService.unlockApp();

  @override
  void setLockScreenVisible(bool visible) =>
      _authService.isLockScreenVisible = visible;
}

/// 锁屏 PIN 状态机控制器（context-free）。
///
/// 职责边界：
/// - 持 mode / inputPin / tempPinForSetup / pinLength=4 与生物识别状态；
/// - [initialize] 负责 visible=true，并在 unlock 模式下查询
///   `biometricEnabled && canCheckBiometrics`；
/// - [appendDigit] / [delete] 返回 typed 是否需 submit；[submit] 按
///   unlock / verify / setup / confirm 返回 sealed intent，并保持旧逻辑的
///   `verifyPin → unlockApp`、`setPin → unlockApp` 调用顺序；
/// - [authenticateBiometric] typed；成功时调用 unlockApp；
/// - 不持 BuildContext / Widget / Animation / Haptics / Toast：延迟、错误
///   动画、提示与 onUnlocked 全部留在页面（后续接线）；
/// - dispose 后任何公开方法抛 [StateError]，并把 visible 置回 false。
class LockController {
  LockController({
    LockAuthGateway? gateway,
    LockScreenMode mode = LockScreenMode.unlock,
  }) : _gateway = gateway ?? LockAuthGatewayAdapter(AuthService()),
       _mode = mode;

  final LockAuthGateway _gateway;

  /// PIN 位数（原 `_pinLength = 4`）。
  static const int _pinLengthValue = 4;

  LockScreenMode _mode;
  String _inputPin = '';
  String? _tempPinForSetup;

  bool _biometricAvailable = false;
  bool _useBiometric = false;
  bool _disposed = false;

  LockScreenMode get mode => _mode;

  /// 当前已输入 PIN。
  String get inputPin => _inputPin;

  /// setup 第一步暂存的 PIN（confirm 阶段比对用）。
  String? get tempPinForSetup => _tempPinForSetup;

  /// PIN 位数（固定 4）。
  int get pinLength => _pinLengthValue;

  /// 生物识别是否可用（仅 unlock 模式经 [initialize] 查询）。
  bool get biometricAvailable => _biometricAvailable;

  /// 当前是否展示生物识别入口。
  bool get useBiometric => _useBiometric;

  void _ensureUsable() {
    if (_disposed) {
      throw StateError('LockController 已 dispose');
    }
  }

  /// 初始化：置 visible=true；unlock 模式下查询生物识别可用性并默认启用。
  Future<void> initialize() async {
    _ensureUsable();
    _gateway.setLockScreenVisible(true);
    if (_mode == LockScreenMode.unlock) {
      final bioEnabled = await _gateway.isBiometricEnabled();
      final canBio = await _gateway.canCheckBiometrics();
      _ensureUsable();
      _biometricAvailable = bioEnabled && canBio;
      _useBiometric = _biometricAvailable;
    }
  }

  /// 追加一位（或一段）输入；凑满 [pinLength] 返回 [PinKeyResult.readyToSubmit]。
  PinKeyResult appendDigit(String value) {
    _ensureUsable();
    if (_inputPin.length < _pinLengthValue) {
      _inputPin += value;
      if (_inputPin.length == _pinLengthValue) {
        return PinKeyResult.readyToSubmit;
      }
    }
    return PinKeyResult.moreInput;
  }

  /// 删除最后一位（空输入为 no-op）；删除永不触发 submit。
  PinKeyResult delete() {
    _ensureUsable();
    if (_inputPin.isNotEmpty) {
      _inputPin = _inputPin.substring(0, _inputPin.length - 1);
    }
    return PinKeyResult.moreInput;
  }

  /// 提交当前输入，按模式返回 sealed intent。
  ///
  /// 顺序与旧逻辑一致：unlock/verify 先 `verifyPin` 后 `unlockApp`；
  /// confirm 一致时先 `setPin` 后 `unlockApp`；失败清空输入。
  Future<LockSubmitResult> submit() async {
    _ensureUsable();
    switch (_mode) {
      case LockScreenMode.unlock:
      case LockScreenMode.verify:
        final isValid = await _gateway.verifyPin(_inputPin);
        _ensureUsable();
        if (isValid) {
          _gateway.unlockApp();
          return LockUnlocked();
        }
        _inputPin = '';
        return LockInvalid();
      case LockScreenMode.setup:
        _tempPinForSetup = _inputPin;
        _inputPin = '';
        _mode = LockScreenMode.confirm;
        return LockAwaitConfirmation();
      case LockScreenMode.confirm:
        if (_inputPin == _tempPinForSetup) {
          await _gateway.setPin(_inputPin);
          _ensureUsable();
          _gateway.unlockApp();
          return LockSetupCompleted();
        }
        _inputPin = '';
        _tempPinForSetup = null;
        _mode = LockScreenMode.setup;
        return LockMismatch();
    }
  }

  /// 触发生物识别；通过时调用 unlockApp 并返回 authenticated。
  Future<LockBiometricResult> authenticateBiometric() async {
    _ensureUsable();
    final success = await _gateway.authenticateBiometric();
    _ensureUsable();
    if (success) {
      _gateway.unlockApp();
      return LockBiometricResult.authenticated;
    }
    return LockBiometricResult.failed;
  }

  /// 切换生物识别入口展示（页面仅在 [biometricAvailable] 时允许开启）。
  void setUseBiometric(bool value) {
    _ensureUsable();
    _useBiometric = value;
  }

  /// 释放：visible 置回 false，此后所有公开方法抛 [StateError]。
  void dispose() {
    _disposed = true;
    _gateway.setLockScreenVisible(false);
  }
}
