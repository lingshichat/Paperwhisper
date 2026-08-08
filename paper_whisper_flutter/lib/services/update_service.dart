import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import '../models/update_info.dart';

/// 安装结果状态
enum UpdateInstallStatus {
  launched,
  permissionDenied,
  unsupportedPlatform,
  failed,
}

/// 安装更新结果
class UpdateInstallResult {
  final UpdateInstallStatus status;
  final String? message;

  const UpdateInstallResult(this.status, {this.message});
}

/// 更新检测服务
/// 负责检查远程版本、比较版本号、打开下载链接
class UpdateService {
  // 单例实例
  static final UpdateService _instance = UpdateService._internal();

  // 工厂构造函数返回单例
  factory UpdateService() => _instance;

  // 私有构造函数
  UpdateService._internal();

  // 远程版本配置 URL
  static const String _versionUrl =
      'https://pwdl.lingshichat.cn/version.json';

  // 请求超时时间
  static const Duration _timeout = Duration(seconds: 10);

  // 下载超时配置
  static const Duration _downloadConnectTimeout = Duration(seconds: 15);
  static const Duration _downloadSendTimeout = Duration(seconds: 30);
  static const Duration _downloadReceiveTimeout = Duration(minutes: 5);

  // Android 安装失败提示
  static const String _androidPermissionDeniedMessage =
      '安装权限被拒绝，请在系统设置中允许“纸语”安装未知应用后重试';
  static const String _androidNoAppMessage = '系统未找到可用的安装程序，请检查安装设置后重试';
  static const String _installerMissingMessage = '安装包不存在，请重新下载';

  final Dio _downloadClient = Dio(
    BaseOptions(
      connectTimeout: _downloadConnectTimeout,
      sendTimeout: _downloadSendTimeout,
      receiveTimeout: _downloadReceiveTimeout,
    ),
  );

  /// 检查更新
  /// 返回 UpdateInfo 如果有新版本，返回 null 表示已是最新
  /// 网络错误时抛出异常
  Future<UpdateInfo?> checkForUpdate() async {
    // 1. 获取远程版本信息
    final response = await http.get(Uri.parse(_versionUrl)).timeout(_timeout);

    if (response.statusCode == 404) {
      debugPrint('版本文件不存在 (404)，跳过更新检查');
      return null;
    }

    if (response.statusCode != 200) {
      throw Exception('请求失败: ${response.statusCode}');
    }

    final Map<String, dynamic> json = jsonDecode(response.body);
    final updateInfo = UpdateInfo.fromJson(json);

    // 2. 获取当前应用版本
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    // 3. 比较版本
    if (_isNewerVersion(updateInfo.latestVersion, currentVersion)) {
      return updateInfo;
    }

    return null; // 已是最新版本
  }

  /// 比较版本号
  /// 返回 true 如果 remoteVersion > currentVersion
  bool _isNewerVersion(String remoteVersion, String currentVersion) {
    try {
      final remote = _parseVersion(remoteVersion);
      final current = _parseVersion(currentVersion);

      // 依次比较 major, minor, patch
      for (int i = 0; i < 3; i++) {
        if (remote[i] > current[i]) return true;
        if (remote[i] < current[i]) return false;
      }
      return false; // 版本相同
    } catch (e) {
      debugPrint('版本解析错误: $e');
      return false;
    }
  }

  /// 解析版本号字符串为 [major, minor, patch]
  List<int> _parseVersion(String version) {
    // 移除可能的 'v' 前缀和 '+buildNumber' 后缀
    version = version.replaceAll(RegExp(r'^v'), '');
    version = version.split('+').first;

    final parts = version.split('.');
    return [
      parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
    ];
  }

  /// 获取当前平台标识
  String get currentPlatform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    return 'unknown';
  }

  /// 打开下载链接
  Future<bool> openDownloadUrl(
    UpdateInfo updateInfo, {
    bool useBackup = false,
  }) async {
    final platform = currentPlatform;
    String? url;

    if (useBackup && updateInfo.hasBackupUrl(platform)) {
      url = updateInfo.getBackupUrl(platform);
    } else {
      url = updateInfo.getDownloadUrl(platform);
    }

    if (url == null || url.isEmpty) {
      debugPrint('没有找到 $platform 平台的${useBackup ? "备用" : ""}下载链接');
      return false;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('打开链接失败: $e');
      return false;
    }
  }

  /// 获取本地版本信息 (from assets/version.json)
  Future<UpdateInfo?> getLocalUpdateInfo() async {
    try {
      final jsonString = await rootBundle.loadString('assets/version.json');
      final json = jsonDecode(jsonString);
      return UpdateInfo.fromJson(json);
    } catch (e) {
      debugPrint('Failed to load local version info: $e');
      return null;
    }
  }

  /// 获取当前应用版本
  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// 下载更新包到本地临时目录
  /// [url] 下载地址
  /// [onProgress] 进度回调 (received, total)
  /// [cancelToken] 取消令牌，用于中途取消下载
  /// 返回下载后的本地文件路径
  Future<String> downloadUpdate({
    required String url,
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    // 从 URL 中提取文件名，保留原始后缀
    final uri = Uri.parse(url);
    final fileName =
        uri.pathSegments.isNotEmpty
            ? uri.pathSegments.last
            : (Platform.isAndroid ? 'update.apk' : 'update.exe');

    // 获取临时目录并构建保存路径
    final tempDir = await getTemporaryDirectory();
    final savePath = p.join(tempDir.path, fileName);

    // 如果之前有残留的临时文件，先清理
    final file = File(savePath);
    await _deleteFileIfExists(file);

    try {
      await _downloadClient.download(
        url,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          onProgress(received, total);
        },
      );
      return savePath;
    } on DioException catch (_) {
      // 下载失败后统一清理残留的临时文件
      await _deleteFileIfExists(file);
      rethrow;
    } catch (_) {
      await _deleteFileIfExists(file);
      rethrow;
    }
  }

  /// 安装已下载的更新包
  /// [filePath] 本地文件路径
  /// Android: open_filex 打开 APK，触发系统安装流程
  /// Windows: Process.start 运行 EXE 安装程序，然后退出当前应用
  Future<UpdateInstallResult> installUpdate(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return const UpdateInstallResult(
        UpdateInstallStatus.failed,
        message: _installerMissingMessage,
      );
    }

    if (Platform.isAndroid) {
      final result = await OpenFilex.open(filePath);
      debugPrint('安装 APK 结果: ${result.type}');
      return _mapAndroidInstallResult(result);
    }

    if (Platform.isWindows) {
      try {
        await Process.start(filePath, [], mode: ProcessStartMode.detached);
        exit(0);
      } on ProcessException {
        debugPrint('启动 Windows 安装程序失败');
        return const UpdateInstallResult(
          UpdateInstallStatus.failed,
          message: '无法启动安装程序，请检查文件权限后重试',
        );
      } catch (_) {
        debugPrint('启动 Windows 安装程序失败');
        return const UpdateInstallResult(
          UpdateInstallStatus.failed,
          message: '无法启动安装程序，请稍后重试',
        );
      }
    }

    debugPrint('不支持的平台: ${Platform.operatingSystem}');
    return const UpdateInstallResult(
      UpdateInstallStatus.unsupportedPlatform,
      message: '当前平台不支持应用内安装，请使用浏览器下载',
    );
  }

  /// 清理临时下载文件
  Future<void> _deleteFileIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      debugPrint('清理临时文件失败');
    }
  }

  /// 映射 Android 安装结果为业务状态
  UpdateInstallResult _mapAndroidInstallResult(OpenResult result) {
    switch (result.type) {
      case ResultType.done:
        return const UpdateInstallResult(UpdateInstallStatus.launched);
      case ResultType.permissionDenied:
        return const UpdateInstallResult(
          UpdateInstallStatus.permissionDenied,
          message: _androidPermissionDeniedMessage,
        );
      case ResultType.fileNotFound:
        return const UpdateInstallResult(
          UpdateInstallStatus.failed,
          message: _installerMissingMessage,
        );
      case ResultType.noAppToOpen:
        return const UpdateInstallResult(
          UpdateInstallStatus.failed,
          message: _androidNoAppMessage,
        );
      case ResultType.error:
        return UpdateInstallResult(
          UpdateInstallStatus.failed,
          message: result.message.isNotEmpty ? '无法启动安装程序，请稍后重试' : '安装失败，请稍后重试',
        );
    }
  }
}
