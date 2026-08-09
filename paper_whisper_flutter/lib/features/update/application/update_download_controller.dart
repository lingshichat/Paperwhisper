import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../models/update_info.dart';
import '../../../services/update_service.dart';

/// 下载阶段。
enum UpdateDownloadPhase { idle, downloading, downloaded, error }

/// 下载状态快照（不可变，UI 直接消费）。
///
/// - idle：初始状态，显示「立即更新」+「备用下载」；
/// - downloading：下载中，携带进度（received/total）；
/// - downloaded：下载完成，携带本地路径，安装结果文案写入 [installMessage]；
/// - error：下载失败，携带用户可读 [error] 文案。
class UpdateDownloadState {
  const UpdateDownloadState({
    this.phase = UpdateDownloadPhase.idle,
    this.received = 0,
    this.total = 0,
    this.path,
    this.error,
    this.installMessage,
  });

  final UpdateDownloadPhase phase;
  final int received;
  final int total;

  /// 下载完成后的本地文件路径。
  final String? path;

  /// 下载失败时的用户可读文案。
  final String? error;

  /// 安装结果文案（launched 时为空，其余状态携带原因）。
  final String? installMessage;

  /// 下载进度（0~1）；total 未知时为 0。
  double get progress => total > 0 ? received / total : 0;

  bool get isIdle => phase == UpdateDownloadPhase.idle;
  bool get isDownloading => phase == UpdateDownloadPhase.downloading;
  bool get isDownloaded => phase == UpdateDownloadPhase.downloaded;
  bool get isError => phase == UpdateDownloadPhase.error;

  UpdateDownloadState copyWith({
    UpdateDownloadPhase? phase,
    int? received,
    int? total,
    String? path,
    String? error,
    String? installMessage,
  }) {
    return UpdateDownloadState(
      phase: phase ?? this.phase,
      received: received ?? this.received,
      total: total ?? this.total,
      path: path ?? this.path,
      error: error ?? this.error,
      installMessage: installMessage ?? this.installMessage,
    );
  }
}

/// 下载数据网关（controller 唯一的数据来源 seam，测试可注入替身）。
///
/// 默认实现适配 [UpdateService]（单例私有构造，无法子类化，因此以接口
/// 形式注入）。
abstract interface class UpdateDownloadGateway {
  /// 当前平台标识（android / windows / ios / macos / unknown）。
  String get currentPlatform;

  /// 下载更新包：进度经 [onProgress] 上报，[cancelToken] 支持中途取消。
  Future<String> downloadUpdate({
    required String url,
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  });

  /// 安装已下载的更新包。
  Future<UpdateInstallResult> installUpdate(String filePath);

  /// 打开浏览器下载链接（备用/主链接）。
  Future<bool> openDownloadUrl(UpdateInfo updateInfo, {bool useBackup = false});
}

/// [UpdateService] 的下载网关适配器（production 默认实现）。
class UpdateServiceDownloadGateway implements UpdateDownloadGateway {
  UpdateServiceDownloadGateway(this._service);

  final UpdateService _service;

  @override
  String get currentPlatform => _service.currentPlatform;

  @override
  Future<String> downloadUpdate({
    required String url,
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) {
    return _service.downloadUpdate(
      url: url,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  @override
  Future<UpdateInstallResult> installUpdate(String filePath) =>
      _service.installUpdate(filePath);

  @override
  Future<bool> openDownloadUrl(
    UpdateInfo updateInfo, {
    bool useBackup = false,
  }) {
    return _service.openDownloadUrl(updateInfo, useBackup: useBackup);
  }
}

/// 更新下载控制器（context-free）。
///
/// 职责边界：
/// - 注入 [UpdateDownloadGateway]，持有 CancelToken 生命周期与下载状态机；
/// - 不持有 BuildContext / Dialog / Toast，UI 通过 [state] 快照 + Listenable
///   消费；
/// - [start] 按当前平台 URL 决策；缺 URL 直接进入 error 态；
/// - 用户取消（[cancel]）由 Dio 的 cancel 回调将状态回置 idle；
/// - [dispose] 取消进行中的下载，且之后不再 notify（防 ChangeNotifier 断言）。
///
/// 错误文案逐字保留原 `UpdateDialog._formatDioError` 与通用分支。
class UpdateDownloadController extends ChangeNotifier {
  UpdateDownloadController({UpdateDownloadGateway? gateway})
    : _gateway = gateway ?? UpdateServiceDownloadGateway(UpdateService());

  final UpdateDownloadGateway _gateway;
  UpdateDownloadState _state = const UpdateDownloadState();
  CancelToken? _cancelToken;
  bool _disposed = false;

  /// 当前状态快照。
  UpdateDownloadState get state => _state;

  /// 当前平台标识（透传 gateway，供页面计算备用链接可用性）。
  String get currentPlatform => _gateway.currentPlatform;

  void _update(UpdateDownloadState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  /// 开始下载 [info] 当前平台对应的更新包。
  Future<void> start(UpdateInfo info) async {
    final platform = _gateway.currentPlatform;
    final url = info.getDownloadUrl(platform);
    if (url == null || url.isEmpty) {
      _update(
        const UpdateDownloadState(
          phase: UpdateDownloadPhase.error,
          error: '未找到当前平台的下载链接',
        ),
      );
      return;
    }

    final token = CancelToken();
    _cancelToken = token;
    _update(const UpdateDownloadState(phase: UpdateDownloadPhase.downloading));

    try {
      final path = await _gateway.downloadUpdate(
        url: url,
        onProgress: (received, total) {
          _update(
            UpdateDownloadState(
              phase: UpdateDownloadPhase.downloading,
              received: received,
              total: total,
            ),
          );
        },
        cancelToken: token,
      );
      _update(
        UpdateDownloadState(phase: UpdateDownloadPhase.downloaded, path: path),
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        // 用户主动取消：回到初始状态
        _update(const UpdateDownloadState());
      } else {
        _update(
          UpdateDownloadState(
            phase: UpdateDownloadPhase.error,
            error: _formatDioError(e),
          ),
        );
      }
    } catch (e) {
      _update(
        UpdateDownloadState(
          phase: UpdateDownloadPhase.error,
          error: '下载失败: $e',
        ),
      );
    } finally {
      if (identical(_cancelToken, token)) {
        _cancelToken = null;
      }
    }
  }

  /// 取消下载：取消 CancelToken，状态回 idle 由 Dio 的 cancel 回调驱动。
  void cancel() {
    _cancelToken?.cancel('用户取消下载');
  }

  /// 安装已下载的更新包；typed 结果映射为 [UpdateDownloadState.installMessage]。
  Future<void> install() async {
    final path = _state.path;
    if (path == null) return;
    _update(_state.copyWith(installMessage: null));

    try {
      final result = await _gateway.installUpdate(path);
      switch (result.status) {
        case UpdateInstallStatus.launched:
          _update(_state.copyWith(installMessage: null));
          break;
        case UpdateInstallStatus.permissionDenied:
        case UpdateInstallStatus.unsupportedPlatform:
        case UpdateInstallStatus.failed:
          _update(
            _state.copyWith(installMessage: result.message ?? '安装失败，请稍后重试'),
          );
          break;
      }
    } catch (_) {
      _update(_state.copyWith(installMessage: '安装失败，请稍后重试'));
    }
  }

  /// 备用下载：跳转浏览器（保持现有行为）。
  Future<bool> fallback(UpdateInfo info, {bool useBackup = false}) {
    return _gateway.openDownloadUrl(info, useBackup: useBackup);
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelToken?.cancel('对话框已关闭');
    _cancelToken = null;
    super.dispose();
  }

  /// 格式化 Dio 异常为用户友好的提示信息（逐字保留原实现）。
  String _formatDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '网络超时，请检查网络连接后重试';
      case DioExceptionType.connectionError:
        return '网络连接失败，请检查网络设置';
      case DioExceptionType.badResponse:
        return '服务器异常 (${e.response?.statusCode})';
      default:
        // 检查是否为存储空间不足
        if (e.error is FileSystemException) {
          return '存储空间不足，请清理后重试';
        }
        return '下载失败: ${e.message ?? '未知错误'}';
    }
  }
}
