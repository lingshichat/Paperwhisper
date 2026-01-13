import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:path/path.dart' as path;

class WebDavSyncService {
  webdav.Client? _client;
  String? _serverUrl;
  String? _username;
  String? _password;

  // 基础路径常量
  static const String rootPath = '/PaperWhisper/';
  static const String diaryBasePath = '/PaperWhisper/diary_data/';
  static const String trashBasePath = '/PaperWhisper/trash/'; // New Trash Path
  static const String momentsBasePath = '/PaperWhisper/moments_data/';
  static const String momentsImagesPath = '/PaperWhisper/moments_data/images/';

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

  /// 递归确保目录存在
  Future<void> ensureDirectoryExists(String remotePath) async {
    if (_client == null) return;
    
    // 移除末尾斜杠以便统一处理
    if (remotePath.endsWith('/')) {
      remotePath = remotePath.substring(0, remotePath.length - 1);
    }
    
    // 如果是根目录，忽略
    if (remotePath.isEmpty) return;

    // 尝试直接读取，如果成功则目录存在
    try {
       await _client!.readDir(remotePath + '/');
       return; 
    } catch (_) {
       // 目录不存在，需要创建
    }
    
    // 递归检查父目录
    // 使用 posix context 处理 WebDAV 路径 (总是 / 分隔)
    String parent = path.posix.dirname(remotePath);
    
    // 避免死循环
    if (parent != remotePath && parent != '/' && parent != '.') {
       await ensureDirectoryExists(parent);
    }
    
    // 创建当前目录
    try {
      await _client!.mkdir(remotePath);
      debugPrint('Created remote directory: $remotePath');
    } catch (e) {
      // 忽略创建错误（可能是并发导致已存在）
    }
  }

  /// 测试连接有效性 (包含基础目录检查)
  Future<bool> testConnection() async {
    if (_client == null) return false;
    try {
      await _client!.ping();
      // 预先创建常用目录
      await ensureDirectoryExists(diaryBasePath);
      // 不要在这里强制创建 moments，按需创建
      return true;
    } catch (e) {
      debugPrint('WebDAV test connection failed: $e');
      return false;
    }
  }

  /// 获取云端文件列表
  /// [remotePath] 必须以 / 结尾，例如 '/PaperWhisper/diary_data/'
  Future<List<webdav.File>> listRemoteFiles({String remotePath = diaryBasePath}) async {
    if (_client == null) return [];
    try {
      // 确保目录存在
      await ensureDirectoryExists(remotePath); 
      return await _client!.readDir(remotePath);
    } catch (e) {
      debugPrint('WebDAV list files failed for $remotePath: $e');
      // 严重错误：如果列举失败，必须抛出异常，绝对不能返回空列表！
      // 返回空列表会导致同步逻辑误以为云端被清空，从而触发全量重新上传，消耗大量流量。
      rethrow;
    }
  }

  /// 上传文件
  /// [localFilePath] 本地文件绝对路径
  /// [remoteFilePath] 云端完整路径，例如 '/PaperWhisper/diary_data/abc.txt'
  Future<void> uploadFile(String localFilePath, String remoteFilePath) async {
    if (_client == null) return;
    try {
      await _client!.writeFromFile(localFilePath, remoteFilePath);
      debugPrint('Uploaded: $remoteFilePath');
    } catch (e) {
      debugPrint('WebDAV upload failed: $e');
      rethrow;
    }
  }

  /// 下载文件
  /// [remoteFilePath] 云端完整路径
  /// [localSavePath] 本地保存完整路径
  Future<void> downloadFile(String remoteFilePath, String localSavePath) async {
    if (_client == null) return;
    try {
      await _client!.read2File(remoteFilePath, localSavePath);
      debugPrint('Downloaded: $remoteFilePath');
    } catch (e) {
      debugPrint('WebDAV download failed: $e');
      rethrow;
    }
  }

  /// 删除云端文件 (慎用，现建议移动到 Trash)
  Future<void> deleteFile(String remoteFilePath) async {
    if (_client == null) return;
    try {
      await _client!.remove(remoteFilePath);
      debugPrint('Deleted Remote: $remoteFilePath');
    } catch (e) {
      debugPrint('WebDAV delete failed: $e');
    }
  }

  /// 移动/重命名云端文件
  Future<void> moveFile(String oldPath, String newPath) async {
    if (_client == null) return;
    try {
      // 确保目标目录存在
      await ensureDirectoryExists(path.posix.dirname(newPath));
      
      await _client!.rename(oldPath, newPath, false); // false = don't overwrite? wait, rename param overwrite
      // pub webdav_client rename(path, newPath, overwrite)
      debugPrint('Moved Remote: $oldPath -> $newPath');
    } catch (e) {
      debugPrint('WebDAV move failed: $e');
      rethrow;
    }
  }

  /// 读取云端文件内容为字符串
  Future<String?> readRemoteFile(String remotePath) async {
    if (_client == null) return null;
    try {
      // 临时下载到缓冲区
      List<int> bytes = await _client!.read(remotePath);
      return utf8.decode(bytes);
    } catch (e) {
      // 404 is common for new manifest
      debugPrint('WebDAV read failed (might be 404): $e');
      return null;
    }
  }

  /// 直接写入字符串到云端文件
  Future<void> writeRemoteFile(String remotePath, String content) async {
    if (_client == null) return;
    try {
      Uint8List bytes = Uint8List.fromList(utf8.encode(content));
      await _client!.write(remotePath, bytes);
      debugPrint('Wrote string to: $remotePath');
    } catch (e) {
      debugPrint('WebDAV write string failed: $e');
      rethrow;
    }
  }
}
