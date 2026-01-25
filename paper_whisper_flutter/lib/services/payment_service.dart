import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'trial_service.dart';

class PaymentService extends ChangeNotifier {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  late SharedPreferences _prefs;
  bool _isPro = false;
  bool get isPro => _isPro;

  /// 是否有权限使用会员功能：已购买或 7 天试用期内
  bool get canUseProFeatures => _isPro || TrialService().isInTrial;

  // TODO: Replace with your actual Cloudflare Worker URL
  static const String _kWorkerUrl = "https://pay.lingshichat.top";
  
  static const String _kLicenseKey = 'pw_pro_license_v1';
  static const String _kTokenKey = 'pw_pro_token_info';

  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    await _checkProStatus();
  }

  /// 检查本地 Pro 状态
  Future<void> _checkProStatus() async {
    try {
      final storedHash = _prefs.getString(_kLicenseKey);
      if (storedHash == null) {
        _isPro = false;
        return;
      }

      // 验证 Hash (简单的防篡改，防止直接修改 XML)
      // Hash = SHA256( "paperwhisper_pro_salt_" + DeviceInfo )
      // 由于获取 DeviceInfo 是异步且可能变动的，为了简化且减少依赖，
      // 我们这里可以使用 PackageInfo 的 buildSignature 或者更简单的固定盐值。
      // 对于无后端应用，完全防止破解是不可能的，这里主要防君子。
      
      // 这里的逻辑是：verifyOrder 成功后，会写入一个特定的 Hash 值。
      // 启动时检查这个 Hash 是否符合预期。
      
      final expectedHash = await _generateLocalLicenseHash();
      if (storedHash == expectedHash) {
        _isPro = true;
      } else {
        _isPro = false;
      }
    } catch (e) {
      debugPrint("Pro status check failed: $e");
      _isPro = false;
    }
    notifyListeners();
  }

  /// 验证订单 (调用 CF Worker)
  /// Returns: String (Success Message) or throws Exception
  Future<VerificationResult> verifyOrder(String orderId) async {
    if (orderId.trim().isEmpty) throw Exception("请输入订单号");

    try {
      final response = await http.post(
        Uri.parse(_kWorkerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'order_id': orderId.trim()}),
      );

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      
      if (response.statusCode == 200 && body['success'] == true) {
        // 验证成功
        final data = body['data'];
        final token = data['token'];
        final activations = data['activations'];
        
        // 1. 生成并保存本地 License
        final licenseHash = await _generateLocalLicenseHash();
        await _prefs.setString(_kLicenseKey, licenseHash);
        
        // 2. 保存服务端 Token (作为凭证备查)
        await _prefs.setString(_kTokenKey, jsonEncode(data));
        
        // 3. 更新状态
        _isPro = true;
        notifyListeners();
        
        return VerificationResult(
          success: true,
          message: "验证成功！\n这是第 $activations 次激活 (共5次)",
          isFirstTime: activations == 1
        );
      } else {
        // 验证失败
        final msg = body['message'] ?? "验证失败，请稍后重试";
        throw Exception(msg);
      }
    } catch (e) {
      throw Exception("网络请求失败: $e");
    }
  }

  // 生成本地校验 Hash
  Future<String> _generateLocalLicenseHash() async {
    // 使用简单的固定盐值 + 包名，确保不同 App 之间不通用
    // 如果需要更强绑定，可以引入 device_info_plus 获取 android_id
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final packageName = packageInfo.packageName;
    const salt = "sk_paper_whisper_pro_2026";
    
    final content = "$packageName|$salt";
    return sha256.convert(utf8.encode(content)).toString();
  }

  // 调试用：清除 Pro 状态
  Future<void> debugReset() async {
    await _prefs.remove(_kLicenseKey);
    await _prefs.remove(_kTokenKey);
    _isPro = false;
    notifyListeners();
  }
}

class VerificationResult {
  final bool success;
  final String message;
  final bool isFirstTime;

  VerificationResult({
    required this.success, 
    required this.message,
    this.isFirstTime = false
  });
}
