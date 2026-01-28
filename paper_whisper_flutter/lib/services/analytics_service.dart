import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AnalyticsService {
  // TODO: 收到域名后，请替换此处 [YOUR_DOMAIN_HERE] 为真实的 API 域名
  static const String _baseUrl = 'https://pb.lingshichat.top/api/collections/app_events/records';
  
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  String? _deviceId;
  Map<String, dynamic> _deviceMetadata = {};
  bool _initialized = false;

  /// 初始化服务：加载 Device ID 和设备信息
  Future<void> init() async {
    if (_initialized) return;

    try {
      // 1. 获取或生成 Device ID
      final prefs = await SharedPreferences.getInstance();
      _deviceId = prefs.getString('device_id');
      
      if (_deviceId == null) {
        _deviceId = const Uuid().v4();
        await prefs.setString('device_id', _deviceId!);
        if (kDebugMode) {
          debugPrint('Analytics: Generated new Device ID: $_deviceId');
        }
      } else {
        if (kDebugMode) {
          debugPrint('Analytics: Loaded existing Device ID: $_deviceId');
        }
      }

      // 2. 获取元数据
      await _loadMetadata();
      
      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Analytics: Init failed: $e');
      }
    }
  }

  Future<void> _loadMetadata() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo = DeviceInfoPlugin();
      
      String osInfo = 'Unknown';
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        osInfo = 'Android ${androidInfo.version.release} (${androidInfo.model})';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        osInfo = 'iOS ${iosInfo.systemVersion} (${iosInfo.utsname.machine})';
      } else if (Platform.isWindows) {
         final windowsInfo = await deviceInfo.windowsInfo;
         osInfo = 'Windows ${windowsInfo.majorVersion}.${windowsInfo.minorVersion}';
      }

      _deviceMetadata = {
        'platform': osInfo,
        'app_version': packageInfo.version,
        'build_number': packageInfo.buildNumber,
      };
    } catch (e) {
      if (kDebugMode) {
         debugPrint('Analytics: Failed to load metadata: $e');
      }
    }
  }

  /// 发送埋点事件 (Fire-and-forget)
  void trackEvent(String eventName, {Map<String, dynamic>? metadata}) {
    if (!_initialized || _deviceId == null) {
      // 尝试隐式初始化，但本次发送可能会因缺少 ID 而失败或推迟
      // 为了保证不阻塞，这里不 await init()
      init().then((_) {
         // 如果是初始化后第一次，可以在这里补发，但为了简化逻辑，
         // 且基于"失败不重试"原则，这里仅做初始化尝试。
      });
      
      // 如果没有 device_id，本次无法发送
      if (_deviceId == null) return;
    }

    // 组合最终的 metadata
    final fullMetadata = {
      ...?metadata,
      ..._deviceMetadata,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final body = {
      'device_id': _deviceId,
      'event_name': eventName,
      'metadata': fullMetadata,
    };

    // 异步发送，不等待结果
    _sendRequest(body);
  }

  Future<void> _sendRequest(Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (kDebugMode) {
           debugPrint('Analytics: Sent event ${body['event_name']}');
        }
      } else {
        if (kDebugMode) {
          debugPrint('Analytics: Failed to send event. Status: ${response.statusCode}, Body: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Analytics: Error sending event: $e');
      }
    }
  }
}
