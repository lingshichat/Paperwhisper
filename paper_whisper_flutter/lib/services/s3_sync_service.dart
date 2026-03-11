
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:minio/minio.dart';
import 'package:path/path.dart' as path;
import 'cloud_storage_service.dart';

class S3SyncService implements CloudStorageService {
  Minio? _client;
  String? _endPoint;
  String? _accessKey;
  String? _secretKey;
  String? _bucketName;
  String? _region;

  bool get isConnected => _client != null;

  void initConfig({
     required String endPoint,
     required String accessKey,
     required String secretKey,
     required String bucketName,
     String? region,
  }) {
    _endPoint = endPoint;
    _accessKey = accessKey;
    _secretKey = secretKey;
    _bucketName = bucketName;
    _region = region;
  }

  @override
  Future<bool> connect() async {
    if (_endPoint == null || _accessKey == null || _secretKey == null || _bucketName == null) {
      return false;
    }
    
    try {
      // Clean endpoint (remove https:// or trailing /)
      String ep = _endPoint!;
      bool useSsl = true;
      
      if (ep.startsWith('http://')) {
        useSsl = false;
        ep = ep.substring(7);
      } else if (ep.startsWith('https://')) {
        ep = ep.substring(8);
      }
      
      if (ep.endsWith('/')) ep = ep.substring(0, ep.length - 1);
      
      int? port;
      if (ep.contains(':')) {
        final parts = ep.split(':');
        ep = parts[0];
        port = int.tryParse(parts[1]);
      }

      _client = Minio(
        endPoint: ep,
        port: port,
        useSSL: useSsl,
        accessKey: _accessKey!,
        secretKey: _secretKey!,
        region: _region,
      );
      
      return true;
    } catch (e) {
      debugPrint('S3 init failed: $e');
      _client = null;
      return false;
    }
  }

  @override
  Future<bool> testConnection() async {
    if (_client == null || _bucketName == null) return false;
    try {
      final exists = await _client!.bucketExists(_bucketName!);
      if (!exists) {
        debugPrint('S3 Bucket $_bucketName does not exist');
        return false;
      }
      // Try list to ensure permissions
      // maxKeys argument might vary by version, usually supported in listObjectsV2 or similar
      // Minio dart listObjects returns Stream<ListObjectsResult>
      await _client!.listObjects(_bucketName!).take(1).toList();
      debugPrint('S3 Connected to $_bucketName');
      return true;
    } catch (e) {
      debugPrint('S3 test connection failed: $e');
      return false;
    }
  }

  // S3 doesn't really have "directories", but we simulate structure with keys
  String _normalizeKey(String remotePath) {
    if (remotePath.startsWith('/')) return remotePath.substring(1);
    return remotePath;
  }

  @override
  Future<void> ensureDirectoryExists(String remotePath) async {
    // S3 is flat, no need to create directories.
  }

  @override
  Future<List<RemoteFile>> listFiles(String remotePath) async {
    if (_client == null || _bucketName == null) return [];
    
    String prefix = _normalizeKey(remotePath);
    if (!prefix.endsWith('/') && prefix.isNotEmpty) prefix += '/';
    
    try {
      final stream = _client!.listObjects(_bucketName!, prefix: prefix, recursive: false);
      final list = await stream.toList();
      
      List<RemoteFile> files = [];
      
      for (var result in list) {
        // Objects in this result
        for (var obj in result.objects) {
             // Skip the directory itself placeholder if exists
             if (obj.key == prefix) continue;
             
             files.add(RemoteFile(
               path: obj.key ?? '',
               name: path.url.basename(obj.key ?? ''),
               size: obj.size ?? 0,
               lastModified: obj.lastModified,
               isDirectory: false
             ));
        }
        
        // Prefixes (Subdirectories) - they are strings in minio 3.5.8
        for (var p in result.prefixes) {
           // p is already a String
           String name = p.endsWith('/') ? p.substring(0, p.length - 1) : p;
           name = path.url.basename(name);
           
           files.add(RemoteFile(
             path: p,
             name: name,
             size: 0,
             isDirectory: true
           ));
        }
      }
      return files;
    } catch (e) {
      debugPrint('S3 list files failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> uploadFile(String localPath, String remotePath, {Function(int, int)? onProgress}) async {
    if (_client == null || _bucketName == null) return;
    
    final file = File(localPath);
    final key = _normalizeKey(remotePath);
    final stat = await file.stat();
    
    try {
      var bytesSent = 0;
      final total = stat.size;
      
      // Minio putObject expects Stream<Uint8List>
      Stream<Uint8List> stream = file.openRead().map((chunk) {
         if (chunk is Uint8List) return chunk;
         return Uint8List.fromList(chunk);
      });
      
      if (onProgress != null) {
          stream = stream.transform(
            StreamTransformer.fromHandlers(
              handleData: (data, sink) {
                bytesSent += data.length;
                onProgress(bytesSent, total);
                sink.add(data);
              }
            )
          );
      }
      
      await _client!.putObject(_bucketName!, key, stream, size: total);
      debugPrint('S3 Uploaded: $key');
    } catch (e) {
      if (_isSuccess204(e)) {
         debugPrint('S3 Upload 204 (Success): $key');
         return;
      }
      debugPrint('S3 Upload failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> downloadFile(String remotePath, String localPath, {Function(int, int)? onProgress}) async {
   if (_client == null || _bucketName == null) {
     debugPrint('S3 Download skipped: client or bucket is null');
     throw Exception('S3 客户端未初始化');
   }
   final key = _normalizeKey(remotePath);
   
   // 确保目标目录存在
   final parentDir = File(localPath).parent;
   if (!await parentDir.exists()) {
     await parentDir.create(recursive: true);
   }
   
   // 1. 尝试获取文件元信息（可选，失败不影响下载）
   //    某些 S3 兼容服务（如 Cloudflare R2）的 HEAD 请求会返回 204，
   //    minio 客户端会抛出 "200 expected, got 204" 异常
   int total = 0;
   try {
     final stat = await _client!.statObject(_bucketName!, key);
     total = stat.size ?? 0;
     debugPrint('S3 Download stat OK: $key (size: $total bytes)');
   } catch (e) {
     // statObject 失败不阻止下载，只是无法预知文件大小
     debugPrint('S3 statObject skipped (non-fatal): $key → $e');
   }
   
   // 2. 执行实际下载（GET 请求）
   try {
     final stream = await _client!.getObject(_bucketName!, key);
     
     final file = File(localPath);
     final sink = file.openWrite();
     
     int bytesReceived = 0;
     
     await stream.listen((chunk) {
        bytesReceived += chunk.length;
        sink.add(chunk);
        if (onProgress != null) onProgress(bytesReceived, total > 0 ? total : bytesReceived);
     }).asFuture();
     
     await sink.flush();
     await sink.close();
     
     // 3. 验证文件确实写入成功
     final writtenFile = File(localPath);
     if (!await writtenFile.exists()) {
       throw Exception('S3 下载后文件不存在: $localPath');
     }
     final writtenSize = await writtenFile.length();
     debugPrint('S3 Downloaded OK: $key → $localPath ($writtenSize bytes)');
   } catch (e) {
     // 如果 getObject 也返回 204，说明文件可能真的不存在或为空
     if (_isSuccess204(e)) {
       debugPrint('S3 getObject also got 204: $key — 文件可能不存在于远端');
       throw Exception('S3 下载失败(GET 204): $key');
     }
     debugPrint('S3 Download FAILED: $key → $e');
     rethrow;
   }
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    if (_client == null || _bucketName == null) return;
    try {
      await _client!.removeObject(_bucketName!, _normalizeKey(remotePath));
    } catch (e) {
      if (_isSuccess204(e)) return;
      debugPrint('S3 delete failed: $e');
    }
  }

  @override
  Future<void> moveFile(String oldPath, String newPath) async {
     if (_client == null || _bucketName == null) return;
     final srcKey = _normalizeKey(oldPath);
     final destKey = _normalizeKey(newPath);
     
     try {
       // Copy
       await _client!.copyObject(_bucketName!, destKey, path.join(_bucketName!, srcKey));
       // Delete old
       await _client!.removeObject(_bucketName!, srcKey);
       debugPrint('S3 Moved: $srcKey -> $destKey');
     } catch (e) {
       if (_isSuccess204(e)) return;
       debugPrint('S3 move failed: $e');
       rethrow;
     }
  }

  @override
  Future<String?> readRemoteFile(String remotePath) async {
     if (_client == null || _bucketName == null) return null;
     final key = _normalizeKey(remotePath);
     
     try {
       final stream = await _client!.getObject(_bucketName!, key);
       final bytes = await stream.expand((chunk) => chunk).toList();
       return utf8.decode(bytes);
     } catch (e) {
       // MinioError... 
       debugPrint('S3 read failed: $e');
       return null;
     }
  }

  @override
  Future<void> writeRemoteFile(String remotePath, String content) async {
     if (_client == null || _bucketName == null) return;
     final key = _normalizeKey(remotePath);
     final bytes = utf8.encode(content);
     final stream = Stream<Uint8List>.fromIterable([Uint8List.fromList(bytes)]);
     
     try {
       await _client!.putObject(_bucketName!, key, stream, size: bytes.length);
     } catch (e) {
       if (_isSuccess204(e)) return;
       debugPrint('S3 write string failed: $e');
       rethrow;
     }
  }
  
  // Helper to suppress 204 errors (Common with some S3 providers like Cloudflare R2 / MinIO)
  bool _isSuccess204(dynamic e) {
    final str = e.toString();
    return str.contains("200 expected, got 204");
  }
}
