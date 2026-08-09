import 'package:permission_handler/permission_handler.dart';

import '../../permissions/application/permission_coordinator.dart';

/// 设置页权限种类。
///
/// 用枚举隔离 permission_handler 类型：controller 与页面只接触
/// [SettingsPermissionKind]，插件权限映射收敛在网关适配器。
enum SettingsPermissionKind { storage, photos, notification }

/// 设置页权限数据网关（controller 唯一数据来源 seam，测试注入替身）。
///
/// 权限判定算法（grantedCount / isAllGranted / summary）仍在
/// [PermissionSnapshot]，本接口不复制算法，只做查询与请求透传。
abstract interface class SettingsPermissionGateway {
  /// 三权限状态汇总（storage / photos / notification）。
  Future<PermissionSnapshot> checkAll();

  /// 请求指定种类权限，返回 typed outcome。
  Future<PermissionRequestOutcome> request(SettingsPermissionKind kind);
}

/// 生产适配器：委托 [PermissionCoordinator]，负责 kind → 插件权限映射。
class SettingsPermissionGatewayAdapter implements SettingsPermissionGateway {
  SettingsPermissionGatewayAdapter(this._coordinator);

  final PermissionCoordinator _coordinator;

  static Permission _toPermission(SettingsPermissionKind kind) {
    switch (kind) {
      case SettingsPermissionKind.storage:
        return Permission.manageExternalStorage;
      case SettingsPermissionKind.photos:
        return Permission.photos;
      case SettingsPermissionKind.notification:
        return Permission.notification;
    }
  }

  @override
  Future<PermissionSnapshot> checkAll() => _coordinator.checkAll();

  @override
  Future<PermissionRequestOutcome> request(SettingsPermissionKind kind) =>
      _coordinator.requestPermission(_toPermission(kind));
}

/// 设置页权限控制器（context-free）。
///
/// 职责边界：
/// - 持 typed snapshot 与 loading；load 查询三权限汇总；
/// - request(kind) 返回现有 [PermissionRequestOutcome]；
/// - 不持 BuildContext / Widget / Dialog，不调用 openAppSettings；
///   说明弹窗、鸿蒙跳转、Toast 全部留在页面；
/// - dispose 后任何公开方法抛 [StateError]，不再变更状态（异步进行中
///   dispose：Future 以 StateError 结束，finally 不再写 loading）。
class SettingsPermissionController {
  SettingsPermissionController({SettingsPermissionGateway? gateway})
    : _gateway =
          gateway ?? SettingsPermissionGatewayAdapter(PermissionCoordinator());

  final SettingsPermissionGateway _gateway;

  PermissionSnapshot? _snapshot;
  bool _loading = false;
  bool _disposed = false;

  /// 最近一次 load 的快照；未加载时为 null。
  PermissionSnapshot? get snapshot => _snapshot;

  /// 查询进行中标记（页面据此禁用入口）。
  bool get loading => _loading;

  void _ensureUsable() {
    if (_disposed) {
      throw StateError('SettingsPermissionController 已 dispose');
    }
  }

  /// 查询三权限状态并缓存快照，返回 typed snapshot。
  Future<PermissionSnapshot> load() async {
    _ensureUsable();
    _loading = true;
    try {
      final snap = await _gateway.checkAll();
      _ensureUsable();
      _snapshot = snap;
      return snap;
    } finally {
      // dispose 后不再写状态：异步中途 dispose 时 Future 已以 StateError
      // 结束，loading 冻结在 dispose 时刻，不复活。
      if (!_disposed) {
        _loading = false;
      }
    }
  }

  /// 请求指定权限并返回 typed outcome（granted / denied / permanentlyDenied）。
  Future<PermissionRequestOutcome> request(SettingsPermissionKind kind) async {
    _ensureUsable();
    final outcome = await _gateway.request(kind);
    _ensureUsable();
    return outcome;
  }

  /// 释放：之后所有公开方法抛 [StateError]，不产生任何状态变更。
  void dispose() => _disposed = true;
}
