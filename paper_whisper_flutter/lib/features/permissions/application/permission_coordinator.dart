import 'package:permission_handler/permission_handler.dart';

import '../../../utils/platform_utils.dart';

/// 权限状态快照（typed）。
class PermissionSnapshot {
  const PermissionSnapshot({
    required this.storage,
    required this.photos,
    required this.notification,
  });

  /// manageExternalStorage 状态。
  final PermissionStatus storage;

  /// photos 状态。
  final PermissionStatus photos;

  /// notification 状态。
  final PermissionStatus notification;

  /// 已获取计数（storage / photos 含 limited / notification），
  /// 逐字保持 settings `_checkAllPermissions` 的计数语义。
  int get grantedCount {
    var count = 0;
    if (storage.isGranted) count++;
    if (photos.isGranted || photos.isLimited) count++;
    if (notification.isGranted) count++;
    return count;
  }

  /// 核心权限是否全部就绪（storage + notification，settings 语义）。
  bool get isAllGranted => storage.isGranted && notification.isGranted;

  /// 汇总文案：`权限状态: N / 3 已获取`。
  String get summary => '权限状态: $grantedCount / 3 已获取';
}

/// 权限请求结果（typed）。
enum PermissionRequestOutcome {
  granted,

  /// 用户拒绝（可再次请求）。
  denied,

  /// 用户永久拒绝（页面提示跳系统设置）。
  permanentlyDenied,
}

/// 权限协调器：封装 permission_handler 与 PlatformUtils 平台判定。
///
/// 职责边界：
/// - 只做权限状态查询与请求，返回 typed snapshot / outcome；
/// - 不持有 BuildContext、不构建 Dialog / Toast / 跳转；
/// - 说明 Dialog、鸿蒙跳转决策、openAppSettings 留在页面；
/// - 平台与权限调用全部通过可选 seam 注入，测试可逐分支替换。
///
/// 迁移来源：
/// - `settings_page._checkAllPermissions` 的三权限状态汇总与
///   `_buildPermissionRow` 的请求分支（含鸿蒙判定）；
/// - `diary_list_page` 的存储权限检查 / 请求 / 返回重查分支。
class PermissionCoordinator {
  PermissionCoordinator({
    Future<PermissionStatus> Function(Permission permission)? statusOf,
    Future<PermissionStatus> Function(Permission permission)? request,
    Future<bool> Function()? isHarmonyOS,
  }) : _statusOf = statusOf ?? _defaultStatusOf,
       _request = request ?? _defaultRequest,
       _isHarmonyOS = isHarmonyOS ?? _defaultIsHarmonyOS;

  final Future<PermissionStatus> Function(Permission permission) _statusOf;
  final Future<PermissionStatus> Function(Permission permission) _request;
  final Future<bool> Function() _isHarmonyOS;

  static Future<PermissionStatus> _defaultStatusOf(Permission permission) =>
      permission.status;

  static Future<PermissionStatus> _defaultRequest(Permission permission) =>
      permission.request();

  static Future<bool> _defaultIsHarmonyOS() => PlatformUtils.isHarmonyOS();

  /// 三权限状态快照（storage / photos / notification）。
  Future<PermissionSnapshot> checkAll() async {
    final storage = await _statusOf(Permission.manageExternalStorage);
    final photos = await _statusOf(Permission.photos);
    final notification = await _statusOf(Permission.notification);
    return PermissionSnapshot(
      storage: storage,
      photos: photos,
      notification: notification,
    );
  }

  /// 存储权限是否已授予（manageExternalStorage）。
  Future<bool> isStorageGranted() async =>
      (await _statusOf(Permission.manageExternalStorage)).isGranted;

  /// 请求指定权限并映射为 typed outcome。
  Future<PermissionRequestOutcome> requestPermission(
    Permission permission,
  ) async {
    final status = await _request(permission);
    if (status.isGranted) return PermissionRequestOutcome.granted;
    if (status.isPermanentlyDenied) {
      return PermissionRequestOutcome.permanentlyDenied;
    }
    return PermissionRequestOutcome.denied;
  }

  /// 鸿蒙系统判定（委托 PlatformUtils）。
  Future<bool> isHarmonyOS() => _isHarmonyOS();
}
