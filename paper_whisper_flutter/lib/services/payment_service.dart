import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

class PaymentService extends ChangeNotifier {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  late SharedPreferences _prefs;
  
  // 仅用于 UI 展示 "已赞助" 勋章，不影响功能使用
  bool _isSponsor = false; 
  bool get isSponsor => _isSponsor;

  // 核心功能锁：对所有人永久开放
  bool get canUseProFeatures => true; 

  static const String _kSponsorKey = 'pw_user_is_sponsored_v2';
  
  // 支付宝收款码 URL (解析自二维码)
  static const String _alipayQrCode = 'https://qr.alipay.com/fkx187002hv2e7taukh965a'; 

  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    _isSponsor = _prefs.getBool(_kSponsorKey) ?? false;
    notifyListeners();
  }

  /// 标记为已打赏 (用户点击"我已支持"后调用)
  Future<void> markAsSponsor() async {
    _isSponsor = true;
    await _prefs.setBool(_kSponsorKey, true);
    notifyListeners();
  }

  /// 支付宝：一键跳转
  Future<void> donateViaAlipay() async {
    final Uri alipayScheme = Uri.parse(
      'alipays://platformapi/startapp?saId=10000007&clientVersion=3.7.0.0718&qrcode=${Uri.encodeComponent(_alipayQrCode)}'
    );

    try {
      if (await canLaunchUrl(alipayScheme)) {
        await launchUrl(alipayScheme, mode: LaunchMode.externalApplication);
      } else {
        throw Exception("未检测到支付宝客户端");
      }
    } catch (e) {
      debugPrint("Alipay launch failed: $e");
      // Fallback: 尝试打开网页版或提示
      throw Exception("无法跳转支付宝，请尝试截图扫码");
    }
  }

  /// 微信：保存图片 + 唤起微信
  Future<String> donateViaWeChat() async {
    // 1. 请求权限 (Android 10+ 不需要 WRITE_STORAGE，但为了兼容旧版本还是申请一下)
    // Gal 库内部会自动处理部分权限，但在某些设备上显式请求更稳妥
    if (Platform.isAndroid) {
       await Permission.storage.request(); 
       // For Android 13+ photos permission
       await Permission.photos.request();
    }

    try {
      // 2. 读取资源文件
      final ByteData bytes = await rootBundle.load('assets/images/donate_wechat.png');
      final Uint8List list = bytes.buffer.asUint8List();

      // 3. 保存到相册 (使用 gal 库)
      // Gal.putImageBytes 直接保存到相册，不需要手动管理路径
      await Gal.putImageBytes(list, name: "paper_whisper_donate_wechat");

      // 4. 尝试唤起微信
      final Uri wechatScheme = Uri.parse('weixin://');
      if (await canLaunchUrl(wechatScheme)) {
        await launchUrl(wechatScheme, mode: LaunchMode.externalApplication);
      }
      
      return "二维码已保存至相册，正在前往微信...";
    } catch (e) {
      debugPrint("WeChat donation failed: $e");
      // 如果 Gal 抛出特定异常，可以在这里处理
      if (e.toString().contains("ACCESS_DENIED")) {
         throw Exception("请授予相册访问权限以保存二维码");
      }
      throw Exception("操作失败: $e");
    }
  }

  void debugReset() async {
    await _prefs.remove(_kSponsorKey);
    _isSponsor = false;
    notifyListeners();
  }
}

