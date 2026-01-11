import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:path/path.dart' as path;

class WebDavSyncService {
  webdav.Client? _client;
  String? _serverUrl;
  String? _username;
  String? _password;

  // 默认云端存储路径
  static const String remoteBasePath = '/PaperWhisper/diary_data/';

  bool get isConnected => _client != null;

  /// 初始化连接
  Future<bool> connect(String serverUrl, String username, String password) async {
    try {
      // 确保 URL 以 / 结尾
      if (!serverUrl.endsWith('/')) {
        serverUrl += '/';
      }

      _client = webdav.newClient(
        serverUrl,
        user: username,
        password: password,
        debug: kDebugMode,
      );

      // 设置连接信息备用
      _serverUrl = serverUrl;
      _username = username;
      _password = password;

      // 简单的 Ping 测试
      await _client!.ping();
      debugPrint('WebDAV connected to $serverUrl');
      return true;
    } catch (e) {
      debugPrint('WebDAV connection failed: $e');
      _client = null;
      return false;
    }
  }

  /// 测试连接有效性 (包含路径检查)
  Future<bool> testConnection() async {
    if (_client == null) return false;
    try {
      await _client!.ping();
      
      // 检查或创建基础目录
      try {
        await _client!.readDir(remoteBasePath);
      } catch (e) {
        // 如果目录不存在，尝试逐级创建
        // 简化处理：尝试直接创建全路径 (mkcol recursive not standard, so step by step)
        // 坚果云等通常支持 mkdir -p 行为或者我们需要手动 split
        // 这里假设 /PaperWhisper/ 可能不存在
        try {
          await _client!.mkdir('/PaperWhisper');
        } catch (_) {} 
        try {
          await _client!.mkdir('/PaperWhisper/diary_data');
        } catch (_) {}
      }
      return true;
    } catch (e) {
      debugPrint('WebDAV test connection failed: $e');
      return false;
    }
  }

  /// 获取云端文件列表
  Future<List<webdav.File>> listRemoteFiles() async {
    if (_client == null) return [];
    try {
      // 确保目录存在
      await testConnection(); 
      return await _client!.readDir(remoteBasePath);
    } catch (e) {
      debugPrint('WebDAV list files failed: $e');
      return [];
    }
  }

  /// 上传文件
  Future<void> uploadFile(String localPath, String filename) async {
    if (_client == null) return;
    try {
      String remotePath = remoteBasePath + filename;
      await _client!.writeFromFile(localPath, remotePath);
      debugPrint('Uploaded: $filename');
    } catch (e) {
      debugPrint('WebDAV upload failed: $e');
      rethrow;
    }
  }

  /// 下载文件
  Future<void> downloadFile(String filename, String localPath) async {
    if (_client == null) return;
    try {
      String remotePath = remoteBasePath + filename;
      await _client!.read2File(remotePath, localPath);
      debugPrint('Downloaded: $filename');
    } catch (e) {
      debugPrint('WebDAV download failed: $e');
      rethrow;
    }
  }
}
