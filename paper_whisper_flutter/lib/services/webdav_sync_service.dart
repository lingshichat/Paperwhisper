import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:path/path.dart' as path;
import 'cloud_storage_service.dart';

class WebDavSyncService implements CloudStorageService {
  webdav.Client? _client;
  String? _serverUrl;
  String? _username;
  String? _password;
  String? _lastConnectionError;

  // 基础路径常量
  static const String rootPath = '/PaperWhisper/';
  static const String diaryBasePath = '/PaperWhisper/diary_data/';
  static const String trashBasePath = '/PaperWhisper/trash/'; // New Trash Path
  static const String momentsBasePath = '/PaperWhisper/moments_data/';
  static const String momentsImagesPath = '/PaperWhisper/moments_data/images/';
  static const String momentsAudioPath = '/PaperWhisper/moments_data/audio/';

  bool get isConnected => _client != null;

  @override
  String? get lastConnectionError => _lastConnectionError;

  void initConfig(String serverUrl, String username, String password) {
      _serverUrl = serverUrl;
      _username = username;
      _password = password;
  }

  @override
  Future<bool> connect() async {
    if (_serverUrl == null || _username == null || _password == null) {
      _lastConnectionError = 'Missing credentials';
      return false;
    }
    try {
      // 确保 URL 以 / 结尾
      String url = _serverUrl!;
      if (!url.endsWith('/')) {
        url += '/';
      }

      _client = webdav.newClient(
        url,
        user: _username!,
        password: _password!,
        debug: kDebugMode,
      );
      
      // Increase timeouts
      _client!.setConnectTimeout(60000);
      _client!.setReceiveTimeout(300000); 

      // 简单的 Ping 测试
      await _client!.ping();
      _lastConnectionError = null;
      debugPrint('WebDAV connected to $url');
      return true;
    } catch (e) {
      _lastConnectionError = e.toString();
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

  @override
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
      // 忽略创建错误
    }
  }

  @override
  Future<bool> testConnection() async {
    if (_client == null) return false;
    try {
      await _client!.ping();
      // 预先创建常用目录
      await ensureDirectoryExists(diaryBasePath);
      _lastConnectionError = null;
      return true;
    } catch (e) {
      _lastConnectionError = e.toString();
      debugPrint('WebDAV test connection failed: $e');
      return false;
    }
  }

  @override
  Future<List<RemoteFile>> listFiles(String remotePath) async {
    if (_client == null) return [];
    try {
      // 确保目录存在
      await ensureDirectoryExists(remotePath); 
      
      // format path for readDir
      String p = _formatPath(remotePath);
      if (!p.endsWith('/')) p += '/';
      
      final list = await _client!.readDir(p);
      return list.map((f) => RemoteFile(
        path: f.path ?? '',
        name: f.name ?? '',
        size: f.size ?? 0,
        lastModified: f.mTime,
        isDirectory: f.isDir ?? false,
      )).toList();
    } catch (e) {
      debugPrint('WebDAV list files failed for $remotePath: $e');
      rethrow;
    }
  }

  @override
  Future<void> uploadFile(String localFilePath, String remoteFilePath, {Function(int sent, int total)? onProgress}) async {
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
      request.contentLength = totalBytes; 

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

  @override
  Future<void> downloadFile(String remoteFilePath, String localSavePath, {Function(int received, int total)? onProgress}) async {
    if (_serverUrl == null) return;

    final url = Uri.parse(_serverUrl! + _formatPath(remoteFilePath));
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 60);
    
    try {
      final request = await client.getUrl(url);
      request.headers.set(HttpHeaders.authorizationHeader, _getAuthHeader());
      
      final response = await request.close();
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final totalBytes = response.contentLength;
        final file = File(localSavePath);
        final sink = file.openWrite();
        
        int bytesReceived = 0;
        
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

  @override
  Future<void> deleteFile(String remoteFilePath) async {
    if (_client == null) return;
    try {
      await _client!.remove(_formatPath(remoteFilePath));
      debugPrint('Deleted Remote: $remoteFilePath');
    } catch (e) {
      debugPrint('WebDAV delete failed: $e');
    }
  }

  @override
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

  @override
  Future<String?> readRemoteFile(String remotePath) async {
    if (_client == null) return null;
    try {
      List<int> bytes = await _client!.read(_formatPath(remotePath));
      return utf8.decode(bytes);
    } catch (e) {
      debugPrint('WebDAV read failed (might be 404): $e');
      return null;
    }
  }

  @override
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
