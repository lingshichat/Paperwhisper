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

  // Subscription Expiry
  DateTime? _subscriptionExpiry;
  DateTime? get subscriptionExpiry => _subscriptionExpiry;

  /// 是否有权限使用会员功能：已购买(买断) OR 订阅生效中 OR 7 天试用期内
  bool get canUseProFeatures {
    if (_isPro) return true; // Lifetime
    if (isSubscriptionActive) return true; // Subscription
    return TrialService().isInTrial; // Trial
  }

  bool get isSubscriptionActive {
    if (_subscriptionExpiry == null) return false;
    return _subscriptionExpiry!.isAfter(DateTime.now());
  }

  // TODO: Replace with your actual Cloudflare Worker URL
  static const String _kWorkerUrl = "https://pay.lingshichat.top";
  
  static const String _kLicenseKey = 'pw_pro_license_v1';
  static const String _kTokenKey = 'pw_pro_token_info';
  static const String _kSubExpiryKey = 'pw_subscription_expire_at';

  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    await _checkProStatus();
  }

  /// 检查本地 Pro 状态 (Buyout & Subscription)
  Future<void> _checkProStatus() async {
    try {
      // 1. Check Lifetime License
      final storedHash = _prefs.getString(_kLicenseKey);
      if (storedHash != null) {
        final expectedHash = await _generateLocalLicenseHash();
        if (storedHash == expectedHash) {
          _isPro = true;
        } else {
          _isPro = false;
        }
      } else {
        _isPro = false; // keys: lifetime key not found
      }

      // 2. Check Subscription Expiry
      final expiryStr = _prefs.getString(_kSubExpiryKey);
      if (expiryStr != null) {
        _subscriptionExpiry = DateTime.tryParse(expiryStr);
      } else {
        _subscriptionExpiry = null;
      }

    } catch (e) {
      debugPrint("Pro status check failed: $e");
      _isPro = false;
      _subscriptionExpiry = null;
    }
    notifyListeners();
  }

  /// 验证订单 (通用入口: 买断 / 订阅)
  /// 如果是订阅订单，逻辑会自动处理有效期
  Future<VerificationResult> verifyOrder(String orderId) async {
    final cleanId = orderId.trim();
    if (cleanId.isEmpty) throw Exception("请输入订单号或兑换码");

    // 0. Check for Internal Redeem Codes first
    final redeemResult = await _checkRedeemCode(cleanId);
    if (redeemResult != null) return redeemResult;

    // 1. Verify via Afdian API
    try {
      final response = await http.post(
        Uri.parse(_kWorkerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'order_id': cleanId}),
      );

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      
      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'];
        final activations = data['activations'];
        
        DateTime? newExpiry;
        bool isLifetime = false;

        // --- API 2.0 Logic ---
        // Plan (Subscription): has plan_id, product_id is empty
        // Product (Buyout): has product_id, plan_id is empty
        final String? planId = data['plan_id']?.toString();
        final String? productId = data['product_id']?.toString();
        
        // Logic: specific Plan ID can be checked here if needed
        // For now, any Product is considered "Lifetime" (unless it's a monthly product?)
        // To be safe: We assume user sells "Lifetime" as a Product.
        if (productId != null && productId.isNotEmpty) {
           isLifetime = true;
        } else if (planId != null && planId.isNotEmpty) {
           isLifetime = false; // It's a subscription
        } else {
           // Fallback: Check SKU (legacy)
           if (data['sku_id'] == 'sku_feature_lifetime') isLifetime = true;
        }
        
        // Handle Expiration (Official Field: expire_time)
        if (data['expire_time'] != null) {
           final exp = data['expire_time'];
           if (exp is int) {
             newExpiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
           } else if (exp is String) {
             // Fallback if backend sends string
             final ts = int.tryParse(exp);
             if (ts != null) newExpiry = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
           }
        }
        
        // MVP Fallback for Subscription
        if (!isLifetime && newExpiry == null) {
           // If backend hasn't upgraded to return expire_time yet
           newExpiry = DateTime.now().add(const Duration(days: 31));
        }
        
        if (isLifetime) {
          final licenseHash = await _generateLocalLicenseHash();
          await _prefs.setString(_kLicenseKey, licenseHash);
          _isPro = true;
        } else {
          // Subscription must have an expiry
           if (newExpiry == null) newExpiry = DateTime.now().add(const Duration(days: 31)); // Extra safety
           
          _subscriptionExpiry = newExpiry;
          await _prefs.setString(_kSubExpiryKey, newExpiry.toIso8601String());
        }

        await _prefs.setString(_kTokenKey, jsonEncode(data));
        notifyListeners();
        
        return VerificationResult(
          success: true,
          message: isLifetime 
              ? "功能会员激活成功！\n这是第 $activations 次激活" 
              : "订阅激活成功！\n有效期至 ${newExpiry!.year}-${newExpiry.month}-${newExpiry.day}",
          isFirstTime: activations == 1,
          expireAt: newExpiry
        );
      } else {
        final msg = body['message'] ?? "验证失败，请核对单号";
        throw Exception(msg);
      }
    } catch (e) {
      throw Exception("验证请求失败: $e");
    }
  }

  /// 检查内部兑换码 (Local Redeem Codes)
  /// 仅用于活动赠送，非公开销售
  Future<VerificationResult?> _checkRedeemCode(String code) async {
    // Format: PW-7DAY-ABCD
    if (!code.startsWith("PW-")) return null;

    // TODO: Connect to a remote config or more complex logic
    // MVP: Hardcoded list for specific campaign
    // 为了防止反编译直接看到码，实际应该走 Hash 校验或者联网 check
    // 这里为了演示 "User wants to set a batch"，我们先做一个简单的本地映射 mock
    
    // Demo Codes
    const Map<String, int> validCodes = {
      'PW-WELCOM-2026': 7,    // 7 Days
      'PW-GIFT-NMKW': 30,     // 30 Days
      'PW-VIP-8888': 365,     // 1 Year
    };

    if (validCodes.containsKey(code)) {
      final days = validCodes[code]!;
      final now = DateTime.now();
      
      // Extend if already active?
      // Simple logic: Overwrite or Extend. Let's Extend.
      DateTime base = now;
      if (_subscriptionExpiry != null && _subscriptionExpiry!.isAfter(now)) {
        base = _subscriptionExpiry!;
      }
      
      final newExpiry = base.add(Duration(days: days));
      _subscriptionExpiry = newExpiry;
      await _prefs.setString(_kSubExpiryKey, newExpiry.toIso8601String());
      notifyListeners();
      
      return VerificationResult(
        success: true,
        message: "福利兑换成功！\n增加 $days 天时长",
        expireAt: newExpiry
      );
    }
    
    return null; // Not a valid internal code, proceed to API
  }

  /// 诚信模式激活 (Honesty Mode Activation)
  /// 用户点击 "我已支付" 后直接调用，基于信任原则
  Future<void> activateHonestyMode() async {
    // 1. Generate Local License
    final licenseHash = await _generateLocalLicenseHash();
    await _prefs.setString(_kLicenseKey, licenseHash);
    
    // 2. Clear subscription expiry to avoid confusion (Lifetime overrides sub)
    await _prefs.remove(_kSubExpiryKey);
    _subscriptionExpiry = null;

    // 3. Update State
    _isPro = true;
    notifyListeners();
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

  Future<void> debugReset() async {
    await _prefs.remove(_kLicenseKey);
    await _prefs.remove(_kTokenKey);
    await _prefs.remove(_kSubExpiryKey);
    _isPro = false;
    _subscriptionExpiry = null;
    notifyListeners();
  }

  void refreshState() {
    notifyListeners();
  }
}

class VerificationResult {
  final bool success;
  final String message;
  final bool isFirstTime;
  final DateTime? expireAt;

  VerificationResult({
    required this.success, 
    required this.message,
    this.isFirstTime = false,
    this.expireAt,
  });
}
