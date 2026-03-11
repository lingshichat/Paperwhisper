import 'package:shared_preferences/shared_preferences.dart';

/// 管理 7 天尊享试用：默认关闭，仅当用户在赞助页点击「开启」时写入 trial_start。
/// 与 PaymentService.canUseProFeatures 配合：试用期内享受会员权益。
class TrialService {
  static final TrialService _instance = TrialService._internal();
  factory TrialService() => _instance;
  TrialService._internal();

  static const String _kInstallTime = 'pw_install_time';

  late SharedPreferences _prefs;
  DateTime? _installTime;

  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    final t = _prefs.getInt(_kInstallTime);
    _installTime = (t != null && t != 0)
        ? DateTime.fromMillisecondsSinceEpoch(t)
        : null;
  }

  /// 用户是否曾开启过试用（含已结束）
  bool get hasTrialBeenStarted => _installTime != null;

  /// 在赞助页用户点击「开启 7 天试用」时调用
  Future<void> startTrial() async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await _prefs.setInt(_kInstallTime, t);
    _installTime = DateTime.fromMillisecondsSinceEpoch(t);
  }

  /// 是否在 7 天试用期内
  bool get isInTrial {
    if (_installTime == null) return false;
    return DateTime.now().isBefore(_installTime!.add(const Duration(days: 7)));
  }

  /// 试用剩余天数 (1–7)，试用结束后为 0
  int get trialDaysLeft {
    if (!isInTrial || _installTime == null) return 0;
    final d = DateTime.now().difference(_installTime!).inDays;
    return 7 - d > 0 ? 7 - d : 1; // 最后一天仍显示 1
  }
}
