import '../../../models/update_info.dart';
import '../../../services/update_service.dart';

/// 更新检查结果（sealed typed outcome，context-free）。
sealed class UpdateCheckOutcome {
  const UpdateCheckOutcome();
}

/// 发现新版本：携带更新信息与当前版本（页面负责 UpdateDialog 展示）。
class UpdateCheckAvailable extends UpdateCheckOutcome {
  const UpdateCheckAvailable({
    required this.info,
    required this.currentVersion,
  });

  final UpdateInfo info;
  final String currentVersion;
}

/// 已是最新版本。
class UpdateCheckUpToDate extends UpdateCheckOutcome {
  const UpdateCheckUpToDate();
}

/// 检查失败（网络/解析异常）。页面按入口语义静默（自动）或提示（手动）。
class UpdateCheckFailure extends UpdateCheckOutcome {
  const UpdateCheckFailure({this.error});

  final Object? error;
}

/// 会话级去重跳过（仅自动检查）。
class UpdateCheckSkipped extends UpdateCheckOutcome {
  const UpdateCheckSkipped();
}

/// 更新检查数据网关（协调器唯一的数据来源 seam，测试可注入替身）。
///
/// 默认实现适配 [UpdateService]（单例私有构造，无法子类化，因此以
/// 接口形式注入）。
abstract interface class UpdateCheckGateway {
  /// 查远程版本：返回非 null 表示有新版本。
  Future<UpdateInfo?> checkForUpdate();

  /// 获取当前应用版本。
  Future<String> getCurrentVersion();
}

/// [UpdateService] 的网关适配器（production 默认实现）。
class UpdateServiceGateway implements UpdateCheckGateway {
  UpdateServiceGateway(this._service);

  final UpdateService _service;

  @override
  Future<UpdateInfo?> checkForUpdate() => _service.checkForUpdate();

  @override
  Future<String> getCurrentVersion() => _service.getCurrentVersion();
}

/// 更新检查协调器（context-free）。
///
/// 职责边界：
/// - 注入 [UpdateCheckGateway]、延迟 seam 与会话级去重容器；
/// - 不持有 BuildContext / UpdateDialog / Toast；
/// - 自动检查（[checkAuto]）按 purpose 会话级去重：检查开始即置位
///   防止延迟期间重复触发，**失败时回滚**，不会因一次网络异常永久
///   锁死后续检查；手动检查（[checkManual]）不受去重限制。
///
/// 去重语义说明（逐入口保留原时序与展示）：
/// - 原 `moments_page._checkUpdate` 用 static flag 全局去重且检查开始
///   即置位（失败也永久跳过）。本协调器保留「进程级共享 + 开始置位」
///   语义，但失败回滚，消除「网络异常一次即永久不再检查」的缺陷；
/// - 各自动入口（moments / splash / diary-list）使用独立 purpose key，
///   互不遮蔽对方的可靠更新提示（「不能漏更新」）；
/// - diary-list 原为每次进入页面都检查；收敛为进程内一次（每次启动
///   新进程仍会检查），避免主页频繁网络请求，行为差异在注释中记录。
class UpdateCheckCoordinator {
  UpdateCheckCoordinator({
    UpdateCheckGateway? gateway,
    Future<void> Function(Duration delay)? delay,
    Set<String>? sessionCheckedPurposes,
  }) : _gateway = gateway ?? UpdateServiceGateway(UpdateService()),
       _delay = delay ?? _defaultDelay,
       _sessionCheckedPurposes =
           sessionCheckedPurposes ?? _globalSessionChecked;

  /// 进程级去重集合（默认共享，保留原 moments static flag 的全局语义）。
  static final Set<String> _globalSessionChecked = <String>{};

  final UpdateCheckGateway _gateway;
  final Future<void> Function(Duration delay) _delay;
  final Set<String> _sessionCheckedPurposes;

  static Future<void> _defaultDelay(Duration delay) =>
      Future<void>.delayed(delay);

  /// 自动检查（带会话级去重）。
  ///
  /// [purpose] 去重键（如 'moments' / 'splash' / 'diary-list'）；
  /// [delay] 检查前延迟（原各入口时序：moments 2s、splash 1s）。
  Future<UpdateCheckOutcome> checkAuto({
    required String purpose,
    Duration delay = Duration.zero,
  }) async {
    if (_sessionCheckedPurposes.contains(purpose)) {
      return const UpdateCheckSkipped();
    }
    // 开始即置位：防止并发进入或延迟期间的重复检查。
    _sessionCheckedPurposes.add(purpose);
    try {
      if (delay > Duration.zero) {
        await _delay(delay);
      }
      final info = await _gateway.checkForUpdate();
      if (info == null) return const UpdateCheckUpToDate();
      final currentVersion = await _gateway.getCurrentVersion();
      return UpdateCheckAvailable(info: info, currentVersion: currentVersion);
    } catch (e) {
      // 失败回滚：不因一次失败永久锁死后续自动检查。
      _sessionCheckedPurposes.remove(purpose);
      return UpdateCheckFailure(error: e);
    }
  }

  /// 获取当前应用版本（gateway 透传；供设置页副标题展示）。
  Future<String> getCurrentVersion() => _gateway.getCurrentVersion();

  /// 手动检查（不受去重限制，settings 手动入口使用）。
  ///
  /// [knownCurrentVersion]：调用方已读取的当前版本（如设置页先取版本
  /// 用于副标题展示），available 时复用，避免重复查询 gateway。
  Future<UpdateCheckOutcome> checkManual({String? knownCurrentVersion}) async {
    try {
      final info = await _gateway.checkForUpdate();
      if (info == null) return const UpdateCheckUpToDate();
      final currentVersion =
          knownCurrentVersion ?? await _gateway.getCurrentVersion();
      return UpdateCheckAvailable(info: info, currentVersion: currentVersion);
    } catch (e) {
      return UpdateCheckFailure(error: e);
    }
  }
}
