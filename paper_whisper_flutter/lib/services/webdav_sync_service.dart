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
      
      // Increase timeouts for slow networks / large files
      // Connect: 60s, Receive: 300s (5 mins)
      _client!.setConnectTimeout(60000);
      _client!.setReceiveTimeout(300000); 

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

  /// 格式化路径：移除开头的 /，防止与 BaseURL 拼接成双斜杠
  String _formatPath(String path) {
    if (path.startsWith('/')) {
      return path.substring(1);
    }
    return path;
  }

  /// 递归确保目录存在
  Future<void> ensureDirectoryExists(String remotePath) async {
    if (_client == null) return;
    
    // 规范化路径：移除开头斜杠
    remotePath = _formatPath(remotePath);
    
    // 移除末尾斜杠以便统一处理
    if (remotePath.endsWith('/')) {
      remotePath = remotePath.substring(0, remotePath.length - 1);
    }
    
    // 如果是根目录，忽略
    if (remotePath.isEmpty || remotePath == '.') return;

    // 尝试直接读取，如果成功则目录存在
    try {
       // readDir 需要以 / 结尾来列出目录内容，但开头不能有 /
       await _client!.readDir(remotePath + '/');
       return; 
    } catch (_) {
       // 目录不存在，需要创建
    }
    
    // 递归检查父目录
    // 使用 posix context 处理 WebDAV 路径 (总是 / 分隔)
    String parent = path.posix.dirname(remotePath);
    
    // 避免死循环
    if (parent != remotePath && parent != '.' && parent.isNotEmpty) {
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
      
      // format path for readDir
      String path = _formatPath(remotePath);
      if (!path.endsWith('/')) path += '/';
      
      return await _client!.readDir(path);
    } catch (e) {
      debugPrint('WebDAV list files failed for $remotePath: $e');
      // 严重错误：如果列举失败，必须抛出异常，绝对不能返回空列表！
      // 返回空列表会导致同步逻辑误以为云端被清空，从而触发全量重新上传，消耗大量流量。
      rethrow;
    }
  }

  /// 手动上传（带进度）
  Future<void> uploadFile(String localFilePath, String remoteFilePath, {Function(int count, int total)? onProgress}) async {
    if (_serverUrl == null) return;
    
    // WebDAV PUT
    final url = Uri.parse(_serverUrl! + _formatPath(remoteFilePath));
    final file = File(localFilePath);
    final totalBytes = await file.length();
    
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 60);
    
    try {
      final request = await client.putUrl(url);
      
      // Headers
      request.headers.set(HttpHeaders.authorizationHeader, _getAuthHeader());
      request.headers.contentType = ContentType.binary;
      request.contentLength = totalBytes; // Important for server to know size

      // Stream upload with progress
      final stream = file.openRead();
      int bytesSent = 0;
      
      await request.addStream(stream.map((chunk) {
        bytesSent += chunk.length;
        if (onProgress != null) onProgress(bytesSent, totalBytes);
        return chunk;
      }));

      final response = await request.close();
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
         debugPrint('Manual Upload Success: $remoteFilePath');
      } else {
         throw HttpException("Upload failed: ${response.statusCode} ${response.reasonPhrase}", uri: url);
      }
    } catch (e) {
       debugPrint('Manual Upload Failed: $e');
       rethrow;
    } finally {
       client.close();
    }
  }

  /// 手动下载（带进度）
  Future<void> downloadFile(String remoteFilePath, String localSavePath, {Function(int count, int total)? onProgress}) async {
    if (_serverUrl == null) return;

    final url = Uri.parse(_serverUrl! + _formatPath(remoteFilePath));
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 60); // Connect timeout
    
    try {
      final request = await client.getUrl(url);
      request.headers.set(HttpHeaders.authorizationHeader, _getAuthHeader());
      
      final response = await request.close();
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final totalBytes = response.contentLength; // might be -1
        final file = File(localSavePath);
        final sink = file.openWrite();
        
        int bytesReceived = 0;
        
        // Listen to stream
        await response.listen((chunk) {
           bytesReceived += chunk.length;
           sink.add(chunk);
           if (onProgress != null) onProgress(bytesReceived, totalBytes);
        }, onDone: () async {
           await sink.flush();
           await sink.close();
        }, onError: (e) {
           sink.close();
           throw e;
        }).asFuture();
        
        debugPrint('Manual Download Success: $remoteFilePath');
      } else {
         throw HttpException("Download failed: ${response.statusCode} ${response.reasonPhrase}", uri: url);
      }
    } catch (e) {
      debugPrint('Manual Download Failed: $e');
      rethrow;
    } finally {
      client.close();
    }
  }

  String _getAuthHeader() {
    if (_username == null || _password == null) return "";
    final bytes = utf8.encode('$_username:$_password');
    return 'Basic ' + base64Encode(bytes);
  }

  /// 删除云端文件 (慎用，现建议移动到 Trash)
  Future<void> deleteFile(String remoteFilePath) async {
    if (_client == null) return;
    try {
      await _client!.remove(_formatPath(remoteFilePath));
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
      
      await _client!.rename(_formatPath(oldPath), _formatPath(newPath), false); 
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
      List<int> bytes = await _client!.read(_formatPath(remotePath));
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
      await _client!.write(_formatPath(remotePath), bytes);
      debugPrint('Wrote string to: $remotePath');
    } catch (e) {
      debugPrint('WebDAV write string failed: $e');
      rethrow;
    }
  }
}
