import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// 平台检测工具类
/// 用于检测特定平台特性，如鸿蒙系统
class PlatformUtils {
  static const MethodChannel _channel = MethodChannel('paper_whisper/platform');

  /// 缓存检测结果，避免重复调用原生代码
  static bool? _isHarmonyOSCached;

  /// 是否为桌面端 (Windows, macOS, Linux)
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// 检测当前设备是否为鸿蒙系统 (HarmonyOS)
  ///
  /// 鸿蒙系统上 permission_handler 的特殊权限请求可能无法正常工作，
  /// 需要使用 openAppSettings() 手动跳转设置页。
  static Future<bool> isHarmonyOS() async {
    // 非 Android 直接返回 false
    if (!Platform.isAndroid) return false;

    // 使用缓存
    if (_isHarmonyOSCached != null) return _isHarmonyOSCached!;

    try {
      final result = await _channel.invokeMethod<bool>('isHarmonyOS');
      _isHarmonyOSCached = result ?? false;
      debugPrint('🔍 PlatformUtils: isHarmonyOS = $_isHarmonyOSCached');
      return _isHarmonyOSCached!;
    } catch (e) {
      debugPrint('⚠️ PlatformUtils: 检测鸿蒙系统失败: $e');
      // 检测失败时假设不是鸿蒙，使用标准流程
      _isHarmonyOSCached = false;
      return false;
    }
  }

  /// 清除缓存（仅用于测试）
  @visibleForTesting
  static void clearCache() {
    _isHarmonyOSCached = null;
  }
}
