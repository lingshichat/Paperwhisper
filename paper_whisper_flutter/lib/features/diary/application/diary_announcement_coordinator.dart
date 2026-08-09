import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/update_info.dart';
import '../../../services/update_service.dart';
import '../../update/application/update_check_coordinator.dart';

/// 版本变更公告检查结果（sealed typed outcome，context-free）。
sealed class DiaryAnnouncementOutcome {
  const DiaryAnnouncementOutcome();
}

/// 版本变更：页面应调用 [DiaryAnnouncementCoordinator.resolve] 完成
/// key 写入与本地公告加载；期间页面先做 mounted 检查。
class DiaryAnnouncementPending extends DiaryAnnouncementOutcome {
  const DiaryAnnouncementPending(this.currentVersion);

  final String currentVersion;
}

/// 版本变更且本地公告存在：页面在 postFrame 展示公告弹窗。
class DiaryAnnouncementShow extends DiaryAnnouncementOutcome {
  const DiaryAnnouncementShow(this.info);

  final UpdateInfo info;
}

/// 版本一致或本地公告缺失：不展示。
class DiaryAnnouncementNone extends DiaryAnnouncementOutcome {
  const DiaryAnnouncementNone();
}

/// 检查失败（版本读取 / 公告加载异常）：页面不改 UI。
class DiaryAnnouncementFailure extends DiaryAnnouncementOutcome {
  const DiaryAnnouncementFailure({this.error});

  final Object? error;
}

/// 版本变更公告数据网关（协调器唯一的数据来源 seam，测试可注入替身）。
///
/// 默认实现适配：
/// - SharedPreferences key `last_run_version`（上次运行版本记录）；
/// - [UpdateCheckCoordinator.getCurrentVersion]（当前应用版本）；
/// - [UpdateService.getLocalUpdateInfo]（本地公告，assets/version.json）。
abstract interface class DiaryAnnouncementGateway {
  /// 读取上次运行版本（无记录返回 null）。
  Future<String?> getLastRunVersion();

  /// 记录本次运行版本。
  Future<void> setLastRunVersion(String version);

  /// 获取当前应用版本。
  Future<String> getCurrentVersion();

  /// 加载本地公告（加载失败返回 null，与原 UpdateService 语义一致）。
  Future<UpdateInfo?> getLocalUpdateInfo();
}

/// SharedPreferences + UpdateCheckCoordinator + UpdateService 的网关适配器
/// （production 默认实现）。
class DiaryAnnouncementServiceGateway implements DiaryAnnouncementGateway {
  DiaryAnnouncementServiceGateway({
    UpdateCheckCoordinator? updateCheck,
    UpdateService? updateService,
  }) : _updateCheck = updateCheck ?? UpdateCheckCoordinator(),
       _updateService = updateService ?? UpdateService();

  final UpdateCheckCoordinator _updateCheck;
  final UpdateService _updateService;

  @override
  Future<String?> getLastRunVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_run_version');
  }

  @override
  Future<void> setLastRunVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_run_version', version);
  }

  @override
  Future<String> getCurrentVersion() => _updateCheck.getCurrentVersion();

  @override
  Future<UpdateInfo?> getLocalUpdateInfo() =>
      _updateService.getLocalUpdateInfo();
}

/// 版本变更公告协调器（context-free，两阶段 typed 协议）。
///
/// 还原 `diary_list_page._checkAndShowAnnouncement` 的时序与边界：
///
/// 阶段一 [prepare]：只按原序读取 `当前版本 → 上次运行版本`。
/// - 版本相同 → [DiaryAnnouncementNone]（绝不写 key、不加载本地公告）；
/// - 版本不同 → [DiaryAnnouncementPending(currentVersion)]（**不写 key**）；
/// - 读取异常 → [DiaryAnnouncementFailure]。
///
/// 阶段二 [resolve]：由页面在 mounted 检查后仅对 Pending 调用。
/// - 严格先记录 `last_run_version`，再加载本地公告；
/// - 本地公告 null → [DiaryAnnouncementNone]（key 已写、仅不展示）；
/// - 本地公告存在 → [DiaryAnnouncementShow]；
/// - 记录 / 加载异常 → [DiaryAnnouncementFailure]。
///
/// 这样保证「版本读取完成后页面仍 mounted 才写 key」的旧版语义，
/// 同时保留「写 key → 加载公告」顺序与 null 仍记录的行为。
class DiaryAnnouncementCoordinator {
  DiaryAnnouncementCoordinator({DiaryAnnouncementGateway? gateway})
    : _gateway = gateway ?? DiaryAnnouncementServiceGateway();

  final DiaryAnnouncementGateway _gateway;

  /// 阶段一：只读版本，不做任何写操作。
  Future<DiaryAnnouncementOutcome> prepare() async {
    try {
      final currentVersion = await _gateway.getCurrentVersion();
      final lastVersion = await _gateway.getLastRunVersion();
      if (lastVersion == currentVersion) {
        return const DiaryAnnouncementNone();
      }
      return DiaryAnnouncementPending(currentVersion);
    } catch (e) {
      return DiaryAnnouncementFailure(error: e);
    }
  }

  /// 阶段二：先写 key，再加载本地公告（仅由页面在 mounted 后对
  /// [DiaryAnnouncementPending] 调用）。
  Future<DiaryAnnouncementOutcome> resolve(
    DiaryAnnouncementPending pending,
  ) async {
    try {
      await _gateway.setLastRunVersion(pending.currentVersion);
      final localInfo = await _gateway.getLocalUpdateInfo();
      if (localInfo == null) {
        return const DiaryAnnouncementNone();
      }
      return DiaryAnnouncementShow(localInfo);
    } catch (e) {
      return DiaryAnnouncementFailure(error: e);
    }
  }
}
