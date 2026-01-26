
import 'dart:async';
import 'dart:io';

abstract class CloudStorageService {
  bool get isConnected;
  
  /// 连接/初始化服务
  Future<bool> connect();

  /// 测试连接有效性
  Future<bool> testConnection();

  /// 获取远程文件列表
  /// [remotePath] 是相对于服务根目录的路径
  Future<List<RemoteFile>> listFiles(String remotePath);

  /// 上传文件
  Future<void> uploadFile(String localPath, String remotePath, {Function(int sent, int total)? onProgress});

  /// 下载文件
  Future<void> downloadFile(String remotePath, String localPath, {Function(int received, int total)? onProgress});

  /// 删除远程文件
  Future<void> deleteFile(String remotePath);

  /// 移动/重命名远程文件
  Future<void> moveFile(String oldPath, String newPath);

  /// 读取远程文件内容 (主要用于小文件如 manifest)
  Future<String?> readRemoteFile(String remotePath);

  /// 写入字符串内容到远程文件
  Future<void> writeRemoteFile(String remotePath, String content);
  
  /// 确保目录存在
  Future<void> ensureDirectoryExists(String remotePath);
}

/// 统一的远程文件模型，屏蔽不同库的差异
class RemoteFile {
  final String path;
  final String name;
  final int size;
  final DateTime? lastModified;
  final bool isDirectory;

  RemoteFile({
    required this.path,
    required this.name,
    required this.size,
    this.lastModified,
    this.isDirectory = false,
  });
  
  @override
  String toString() => 'RemoteFile(name: $name, size: $size, isDir: $isDirectory)';
}
