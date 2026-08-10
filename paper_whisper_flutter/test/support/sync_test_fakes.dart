import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:paper_whisper_flutter/features/diary/data/diary_entry.dart';
import 'package:paper_whisper_flutter/features/sync/data/cloud_storage_service.dart';
import 'package:paper_whisper_flutter/features/diary/data/diary_service.dart';
import 'package:paper_whisper_flutter/features/sync/data/manifest_service.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment_service.dart';
import 'package:paper_whisper_flutter/services/trash_service.dart';

/// 内存版云端存储替身：实现 [CloudStorageService] 接口，
/// 记录上传/下载/删除/移动副作用，供 SyncRunner 测试断言外部行为。
///
/// 断言对象是路径常量、outcome 与外部副作用集合，不锁定私有调用顺序。
class FakeCloudStorageService implements CloudStorageService {
  FakeCloudStorageService({
    this.failUploadFor,
    this.failDownloadFor,
    this.downloadError = 'Network failure',
    this.hangingDownloadFor = const <String>{},
  });

  /// remotePath 包含该子串时上传抛错。
  final String? failUploadFor;

  /// remotePath 包含该子串时下载抛错。
  final String? failDownloadFor;
  final String downloadError;

  /// remotePath 包含任一子串时下载永不完成（配合 Runner 的
  /// `imageDownloadTimeout` 覆盖图片下载超时进入 failedDownloads 的路径）。
  final Set<String> hangingDownloadFor;

  /// 内存远端文件表（完整云端路径 → 内容）。
  final Map<String, String> remoteFiles = <String, String>{};
  final List<String> uploadedPaths = <String>[];
  final List<String> downloadedPaths = <String>[];
  final List<String> deletedPaths = <String>[];
  final List<String> movedFrom = <String>[];
  final List<String> movedTo = <String>[];

  @override
  bool get isConnected => true;

  @override
  String? get lastConnectionError => null;

  @override
  Future<bool> connect() async => true;

  @override
  Future<bool> testConnection() async => true;

  @override
  Future<List<RemoteFile>> listFiles(String remotePath) async {
    return remoteFiles.entries
        .where((entry) => entry.key.startsWith(remotePath))
        .map(
          (entry) => RemoteFile(
            path: entry.key,
            name: path.basename(entry.key),
            size: entry.value.length,
          ),
        )
        .toList();
  }

  @override
  Future<void> uploadFile(
    String localPath,
    String remotePath, {
    Function(int sent, int total)? onProgress,
  }) async {
    if (failUploadFor != null && remotePath.contains(failUploadFor!)) {
      throw Exception('Network failure');
    }
    uploadedPaths.add(remotePath);
    remoteFiles[remotePath] = await File(localPath).readAsString();
    onProgress?.call(1, 1);
  }

  @override
  Future<void> downloadFile(
    String remotePath,
    String localPath, {
    Function(int received, int total)? onProgress,
  }) async {
    if (failDownloadFor != null && remotePath.contains(failDownloadFor!)) {
      throw Exception(downloadError);
    }
    if (hangingDownloadFor.any(remotePath.contains)) {
      // 永不完成：由 Runner 的 `.timeout` 触发 TimeoutException。
      // 不使用延迟 Timer（避免测试结束时的 pending timer 失败）。
      await Completer<void>().future;
      return;
    }
    final content = remoteFiles[remotePath];
    if (content == null) {
      throw Exception('404 Not Found');
    }
    downloadedPaths.add(remotePath);
    final file = File(localPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    onProgress?.call(1, 1);
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    deletedPaths.add(remotePath);
    remoteFiles.remove(remotePath);
  }

  @override
  Future<void> moveFile(String oldPath, String newPath) async {
    movedFrom.add(oldPath);
    movedTo.add(newPath);
    final content = remoteFiles.remove(oldPath);
    if (content == null) {
      throw Exception('404 Not Found');
    }
    remoteFiles[newPath] = content;
  }

  @override
  Future<String?> readRemoteFile(String remotePath) async =>
      remoteFiles[remotePath];

  @override
  Future<void> writeRemoteFile(String remotePath, String content) async {
    remoteFiles[remotePath] = content;
  }

  @override
  Future<void> ensureDirectoryExists(String remotePath) async {}
}

/// DiaryService 测试替身：覆写全部公开操作，不依赖父类私有字段。
/// 数据目录由 [rootDir] 下的 `diary_data/` 派生，
/// manifest（`local_manifest.json`）与回收站落盘于 [rootDir]。
class FakeDiaryService extends DiaryService {
  FakeDiaryService(this.rootDir);

  final Directory rootDir;
  final ManifestService _manifestService = ManifestService();
  final TrashService _trashService = TrashService();
  Directory? _base;
  bool _initialized = false;

  @override
  Directory? get dataDir => _base;

  @override
  String get currentDataPath => _base?.path ?? 'Unknown';

  @override
  ManifestService get manifestService => _manifestService;

  @override
  TrashService get trashService => _trashService;

  @override
  void reset() {
    _initialized = false;
    _base = null;
  }

  @override
  Future<void> init() async {
    if (_initialized) return;
    _base = Directory(path.join(rootDir.path, 'diary_data'));
    await _base!.create(recursive: true);
    await _manifestService.init(_base!);
    await _trashService.init(_base!);
    _initialized = true;
  }

  @override
  Future<List<DiaryEntry>> getEntries() async => <DiaryEntry>[];

  @override
  Future<void> saveCache(List<DiaryEntry> entries) async {}

  @override
  Future<List<DiaryEntry>?> loadCache() async => null;
}

/// MomentService 测试替身：覆写全部公开操作，不依赖父类私有字段。
/// 数据目录由 [rootDir] 下的 `moments_data/` 派生；
/// [referencedImages] 模拟 `getAllReferencedImages` 的结果（basename 集合）。
///
/// 注意：替身 init 不做 `ensureConsistency` 扫描（真实实现会），
/// 使测试可精确控制本地 manifest 内容，避免随心记 JSON 阶段产生意外操作。
class FakeMomentService extends MomentService {
  FakeMomentService(this.rootDir, {this.referencedImages = const <String>{}});

  final Directory rootDir;
  final Set<String> referencedImages;

  /// 归档记录：按调用顺序记录 `archiveMomentByFilename` 归档的文件名，
  /// 供 SyncRunner 本地删除归档断言使用。
  final List<String> archivedFilenames = <String>[];

  final ManifestService _manifestService = ManifestService();
  final TrashService _trashService = TrashService();
  Directory? _base;
  bool _initialized = false;

  @override
  Directory? get dataDir => _base;

  @override
  Directory? get imagesDir =>
      _base == null ? null : Directory(path.join(_base!.path, 'images'));

  @override
  Directory? get audioDir =>
      _base == null ? null : Directory(path.join(_base!.path, 'audio'));

  @override
  ManifestService get manifestService => _manifestService;

  @override
  TrashService get trashService => _trashService;

  @override
  void reset() {
    _initialized = false;
    _base = null;
  }

  @override
  Future<void> init() async {
    if (_initialized) return;
    _base = Directory(path.join(rootDir.path, 'moments_data'));
    await _base!.create(recursive: true);
    await imagesDir!.create(recursive: true);
    await audioDir!.create(recursive: true);
    await _manifestService.init(
      _base!,
      manifestFileName: 'local_moments_manifest.json',
    );
    await _trashService.init(_base!);
    _initialized = true;
  }

  @override
  Future<Set<String>> getAllReferencedImages() async => referencedImages;

  /// 覆写公开归档操作：记录调用并执行可控的本地文件删除与 Manifest
  /// 更新（isDeleted=true），不依赖父类私有字段（_dataDir/_trashService）。
  /// 与真实实现一致，updateItem 必须 await：否则写盘进入串行队列后仍在
  /// 异步进行，测试 tearDown 删除临时目录时会撞上文件占用（Windows）。
  @override
  Future<void> archiveMomentByFilename(
    String filename, {
    int? manifestTimestamp,
  }) async {
    archivedFilenames.add(filename);
    final file = File(path.join(_base!.path, filename));
    if (await file.exists()) {
      await file.delete();
    }
    await _manifestService.updateItem(
      filename,
      isDeleted: true,
      timestamp: manifestTimestamp,
    );
  }
}
