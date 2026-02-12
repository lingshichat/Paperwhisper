
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  late SharedPreferences _prefs;
  
  // Keys for SharedPreferences
  static const String _keyPinHash = 'auth_pin_hash';
  static const String _keyBiometricEnabled = 'auth_biometric_enabled';
  
  // In-memory state
  bool _isLocked = false;
  bool get isLocked => _isLocked;
  
  // Prevent duplicate lock screens (especially during bio auth on Android which triggers lifecycle changes)
  bool isLockScreenVisible = false;

  /// Call this before using AuthService (e.g. in main.dart)
  void init(SharedPreferences prefs) {
    _prefs = prefs;
  }

  void lockApp() {
    if (isLockEnabledSync()) {
      _isLocked = true;
    }
  }

  void unlockApp() {
    _isLocked = false;
  }

  // --- Configuration Check ---

  Future<bool> isLockEnabled() async {
    // Rely on cached _prefs if possible, fallback to instance
    // But since we require init, just use _prefs
    return _prefs.containsKey(_keyPinHash);
  }
  
  bool isLockEnabledSync() {
    return _prefs.containsKey(_keyPinHash);
  }

  Future<bool> isBiometricEnabled() async {
    return _prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      print('DEBUG: AuthService canCheck: $canCheck, supported: $supported');
      return canCheck && supported;
    } on PlatformException catch (e) {
      print('DEBUG: AuthService check error: $e');
      return false;
    }
  }

  // --- Management Actions ---

  /// Sets a new 4-digit PIN. Stores SHA-256 hash.
  Future<void> setPin(String pin) async {
    final hash = sha256.convert(utf8.encode(pin)).toString();
    await _prefs.setString(_keyPinHash, hash);
  }

  /// Verifies the entered PIN against stored hash.
  Future<bool> verifyPin(String pin) async {
    final storedHash = _prefs.getString(_keyPinHash);
    if (storedHash == null) return false;
    
    final inputHash = sha256.convert(utf8.encode(pin)).toString();
    return inputHash == storedHash;
  }

  /// Toggles biometric unlock.
  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool(_keyBiometricEnabled, enabled);
  }

  /// Clears all security settings (Disable Lock).
  Future<void> clearLock() async {
    await _prefs.remove(_keyPinHash);
    await _prefs.remove(_keyBiometricEnabled);
    _isLocked = false;
  }

  // --- Authentication Actions ---

  /// Trigger system biometric prompt.
  /// Returns state: authenticated (true) or failed/canceled (false).
  Future<bool> authenticateBiometric() async {
    try {
      final available = await canCheckBiometrics();
      if (!available) {
        print('DEBUG: Biometrics not available');
        return false;
      }
      
      print('DEBUG: invoking _localAuth.authenticate');

      // Windows 上允许 PIN 认证（Windows Hello），移动端仅生物识别
      final bool bioOnly = !Platform.isWindows;

      return await _localAuth.authenticate(
        localizedReason: '请验证身份以解锁日记',
        biometricOnly: bioOnly,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      // local_auth v3.0：使用 LocalAuthException 代替 PlatformException
      print('DEBUG: Auth error: $e');
      return false;
    } on PlatformException catch (e) {
      // 兼容旧版本可能的异常
      print('DEBUG: Platform error: $e');
      return false;
    } catch (e) {
      // 兜底：捕获所有其他未知异常，防止崩溃
      print('DEBUG: Unexpected auth error: $e');
      return false;
    }
  }
}
