import '../../../models/update_info.dart';
import '../../update/application/update_check_coordinator.dart';

/// 设置页更新检查结果（typed，含并发 busy 态）。
///
/// 由现有 [UpdateCheckOutcome] 映射而来；[SettingsUpdateBusy] 表达
/// 「已有检查进行中」（页面现禁用语义的 typed 化）。
sealed class SettingsUpdateCheckOutcome {
  const SettingsUpdateCheckOutcome();
}

/// 发现新版本：携带更新信息与当前版本（页面负责 UpdateDialog 展示）。
class SettingsUpdateAvailable extends SettingsUpdateCheckOutcome {
  const SettingsUpdateAvailable({
    required this.info,
    required this.currentVersion,
  });

  final UpdateInfo info;
  final String currentVersion;
}

/// 已是最新版本。
class SettingsUpdateUpToDate extends SettingsUpdateCheckOutcome {
  const SettingsUpdateUpToDate();
}

/// 检查失败（版本获取 / 网络 / 解析异常）。页面提示「检测更新失败」。
class SettingsUpdateFailure extends SettingsUpdateCheckOutcome {
  const SettingsUpdateFailure({this.error});

  final Object? error;
}

/// 已有检查进行中：页面保持禁用语义（等价于 `_isCheckingUpdate` 为 true 时不响应）。
class SettingsUpdateBusy extends SettingsUpdateCheckOutcome {
  const SettingsUpdateBusy();
}

/// 设置页更新控制器（context-free）。
///
/// 职责边界：
/// - 依赖 [UpdateCheckCoordinator] 实例（其 gateway seam 可注入替身），
///   不直接持有 UpdateService；
/// - 持 checking / currentVersion；manualCheck 与 settings `_checkForUpdate`
///   同序：先取当前版本（失败转 typed failure），再手动检查；finally 复位
///   checking，保证异常路径不卡死禁用态；
/// - 并发调用返回 [SettingsUpdateBusy] typed 结果；
/// - 不持 BuildContext / UpdateDialog / Toast，展示留在页面；
/// - dispose 后任何公开方法抛 [StateError]，不再变更状态（异步进行中
///   dispose：Future 以 StateError 结束，finally 不再写 checking）。
class SettingsUpdateController {
  SettingsUpdateController({UpdateCheckCoordinator? coordinator})
    : _coordinator = coordinator ?? UpdateCheckCoordinator();

  final UpdateCheckCoordinator _coordinator;

  bool _checking = false;
  String? _currentVersion;
  bool _disposed = false;

  /// 检查进行中（页面据此禁用入口）。
  bool get checking => _checking;

  /// 最近一次成功获取的当前版本（设置项副标题展示）。
  String? get currentVersion => _currentVersion;

  void _ensureUsable() {
    if (_disposed) {
      throw StateError('SettingsUpdateController 已 dispose');
    }
  }

  /// 手动检查：返回 typed outcome；任何异常（含版本获取失败）转
  /// [SettingsUpdateFailure]，finally 复位 checking。
  Future<SettingsUpdateCheckOutcome> manualCheck() async {
    _ensureUsable();
    if (_checking) return const SettingsUpdateBusy();
    _checking = true;
    try {
      // 与页面同序：先取当前版本（失败直接转 typed failure）。
      final currentVersion = await _coordinator.getCurrentVersion();
      _ensureUsable();
      _currentVersion = currentVersion;

      final outcome = await _coordinator.checkManual();
      _ensureUsable();
      return _map(outcome);
    } catch (e) {
      _ensureUsable();
      return SettingsUpdateFailure(error: e);
    } finally {
      // dispose 后不再写状态：异步中途 dispose 时 Future 已以 StateError
      // 结束，checking 冻结在 dispose 时刻，不复活。
      if (!_disposed) {
        _checking = false;
      }
    }
  }

  SettingsUpdateCheckOutcome _map(UpdateCheckOutcome outcome) {
    switch (outcome) {
      case UpdateCheckAvailable(:final info, :final currentVersion):
        return SettingsUpdateAvailable(
          info: info,
          currentVersion: currentVersion,
        );
      case UpdateCheckUpToDate():
        return const SettingsUpdateUpToDate();
      case UpdateCheckFailure(:final error):
        return SettingsUpdateFailure(error: error);
      case UpdateCheckSkipped():
        // 手动检查不会产生 skipped，防御性映射为已是最新。
        return const SettingsUpdateUpToDate();
    }
  }

  /// 释放：之后所有公开方法抛 [StateError]，不产生任何状态变更。
  void dispose() => _disposed = true;
}
