import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart'; // Add this for rootBundle
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/update_info.dart';

/// 更新检测服务
/// 负责检查远程版本、比较版本号、打开下载链接
class UpdateService {
  // 远程版本配置 URL
  static const String _versionUrl = 'https://paperwhisper.s3.bitiful.net/version.json';
  
  // 请求超时时间
  static const Duration _timeout = Duration(seconds: 10);

  /// 检查更新
  /// 返回 UpdateInfo 如果有新版本，返回 null 表示已是最新
  /// 网络错误时抛出异常
  Future<UpdateInfo?> checkForUpdate() async {
    // 1. 获取远程版本信息
    final response = await http
        .get(Uri.parse(_versionUrl))
        .timeout(_timeout);

    if (response.statusCode == 404) {
      print('版本文件不存在 (404)，跳过更新检查');
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
      print('版本解析错误: $e');
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
  Future<bool> openDownloadUrl(UpdateInfo updateInfo, {bool useBackup = false}) async {
    final platform = currentPlatform;
    String? url;

    if (useBackup && updateInfo.hasBackupUrl(platform)) {
      url = updateInfo.getBackupUrl(platform);
    } else {
      url = updateInfo.getDownloadUrl(platform);
    }

    if (url == null || url.isEmpty) {
      print('没有找到 $platform 平台的${useBackup ? "备用" : ""}下载链接');
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
      print('打开链接失败: $e');
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
      print('Failed to load local version info: $e');
      return null;
    }
  }

  /// 获取当前应用版本
  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }
}
