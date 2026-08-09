import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../models/sync_manifest.dart';

/// 本地 manifest 持久化服务。
///
/// 所有写操作（[updateItem]/[removeItem]/[ensureConsistency]）均返回
/// 可等待的 Future，并通过「按 manifest 文件绝对路径共享的串行队列」
/// 串行执行——不同 [ManifestService] 实例即使各自持有内存缓存，只要
/// 写的是同一个 manifest 文件，写操作就会进入同一条队列，避免旧实例
/// 缓存整体覆盖其他实例已写入的新条目。
///
/// 每个 queued mutation 在队列内以「磁盘最新快照」为基线再应用本次
/// 变更，并对同一条目做时间戳判胜（磁盘上该条目版本时间戳更新时，
/// 跳过本次旧写入，不限 `isDeleted`，同时覆盖删除项防复活与普通条目
/// 防旧写覆盖）。磁盘快照读取/解析失败时跳过写盘、保留磁盘原样。
/// JSON 结构、时间戳判胜与 `isDeleted` 语义与原实现逐字兼容。
class ManifestService {
  File? _manifestFile;
  SyncManifest? _cachedManifest;

  /// [init] 时记录的数据目录（manifest 文件位于其父目录）。
  ///
  /// 供 [removeItem] 在队列内检查「本地对应文件是否仍存在」，
  /// 防止并发新保存的数据因幽灵清理而丢失追踪。
  Directory? _dataDir;

  /// 按 manifest 文件绝对路径共享的串行写队列（跨实例）。
  ///
  /// value 恒为不抛错的 Future（尾部已 catchError），保证单次写失败后
  /// 队列继续可用；调用方通过入队时返回的 Future 感知本次操作完成。
  static final Map<String, Future<void>> _writeQueues = {};

  Future<void> init(
    Directory dataDir, {
    String manifestFileName = 'local_manifest.json',
  }) async {
    // Manifest is stored in the same parent directory as diary_data usually, or inside it?
    // Storing it INSIDE diary_data might be confusing if user syncs files manually.
    // Better store it in the parent 'PaperWhisper' directory.

    final parentDir = dataDir.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }
    _dataDir = dataDir;
    _manifestFile = File(path.join(parentDir.path, manifestFileName));
    await _load();
  }

  Future<void> _load() async {
    if (_manifestFile == null) return;
    if (await _manifestFile!.exists()) {
      try {
        final content = await _manifestFile!.readAsString();
        if (content.isEmpty) {
          _cachedManifest = SyncManifest(lastSyncTimestamp: 0, items: {});
          return;
        }
        final json = jsonDecode(content);
        _cachedManifest = SyncManifest.fromJson(json);
      } catch (e) {
        debugPrint("Error loading manifest: $e");
        _cachedManifest = SyncManifest(lastSyncTimestamp: 0, items: {});
      }
    } else {
      _cachedManifest = SyncManifest(lastSyncTimestamp: 0, items: {});
    }
  }

  Future<void> save() async {
    if (_manifestFile == null || _cachedManifest == null) return;
    try {
      await _manifestFile!.writeAsString(jsonEncode(_cachedManifest!.toJson()));
    } catch (e) {
      debugPrint("Error saving manifest: $e");
    }
  }

  SyncManifest get manifest =>
      _cachedManifest ?? SyncManifest(lastSyncTimestamp: 0, items: {});

  /// 队列键：manifest 文件绝对路径（Windows 下统一小写）。
  ///
  /// 同一物理文件即使在不同实例中以不同路径写法（相对/绝对、大小写
  /// 差异）进入队列，也会规范化为同一条串行队列，避免写分叉。
  String? get _queueKey {
    final file = _manifestFile;
    if (file == null) return null;
    var key = path.normalize(path.absolute(file.path));
    if (Platform.isWindows) {
      // Windows 文件系统不区分大小写，casefold 避免同一文件分叉。
      key = key.toLowerCase();
    }
    return key;
  }

  /// 将写操作放入按文件路径共享的串行队列。
  ///
  /// 队列尾部吞掉错误（保证队列继续可用），调用方通过返回的 Future
  /// 感知本次操作完成（写盘错误已在队列内捕获，不会向上抛出）。
  Future<T> _enqueue<T>(String key, Future<T> Function() action) {
    final previous = _writeQueues[key] ?? Future<void>.value();
    final completer = Completer<T>();
    final tail = previous
        .then((_) => action())
        .then(
          (value) => completer.complete(value),
          onError: (Object error, StackTrace stackTrace) {
            completer.completeError(error, stackTrace);
          },
        )
        .catchError((_) {});
    _writeQueues[key] = tail;
    // 队列尾部完成后清理静态 map 条目，避免长期运行累积；仅当该 key
    // 仍指向本次 tail 时才移除，防止误删后续已入队的任务（Dart 单线程
    // 事件循环下 map 读写原子，不引入 race）。
    unawaited(
      tail.whenComplete(() {
        if (identical(_writeQueues[key], tail)) {
          _writeQueues.remove(key);
        }
      }),
    );
    return completer.future;
  }

  /// 读取磁盘上的最新快照（不覆盖内存缓存）。
  ///
  /// 供队列内写盘任务使用：以磁盘最新为基线应用本次 mutation，
  /// 避免旧实例的内存缓存整体覆盖其他实例已写入的新条目。
  ///
  /// 返回语义（数据安全优先）：
  /// - 文件不存在（首次写入基线）→ 空 manifest，可写；
  /// - 文件存在且可解析 → 磁盘快照；
  /// - 文件存在但读取/解析失败 → null（不可写）。调用方必须跳过
  ///   写盘、保留磁盘原样，防止损坏文件被空快照整体覆盖。
  Future<SyncManifest?> _readDiskSnapshot() async {
    final file = _manifestFile;
    if (file == null) return null;
    if (!await file.exists()) {
      return SyncManifest(lastSyncTimestamp: 0, items: {});
    }
    try {
      final content = await file.readAsString();
      if (content.isEmpty) {
        return SyncManifest(lastSyncTimestamp: 0, items: {});
      }
      return SyncManifest.fromJson(jsonDecode(content));
    } catch (e) {
      debugPrint("Error loading manifest: $e");
      return null;
    }
  }

  /// 登记/更新条目（含删除标记）。
  ///
  /// - 内存缓存同步更新，保持调用后立即可读（与原 fire-and-forget
  ///   语义一致）；
  /// - 写盘进入按文件路径共享的串行队列，队列内以磁盘最新快照为基线
  ///   应用本次 mutation，防止旧缓存覆盖新条目；
  /// - 时间戳判胜（磁盘侧）：磁盘上同名条目版本时间戳更新时跳过
  ///   本次写入（不限 isDeleted），避免旧缓存复活已删除项或覆盖
  ///   并发新条目。
  Future<void> updateItem(
    String filename, {
    required bool isDeleted,
    int? timestamp,
  }) {
    final key = _queueKey;
    if (key == null || _cachedManifest == null) return Future.value();

    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    // Simple hash: just use timestamp for now or we could calculate md5 if needed.
    // Ideally we want content hash but for now timestamp versioning is okay for single user.
    final hash = ts.toString();

    final existing = _cachedManifest!.items[filename];
    // 防复活（内存侧）：已有更新的删除标记时，本次旧写入直接忽略
    if (existing != null &&
        existing.isDeleted &&
        existing.versionTimestamp > ts) {
      return Future.value();
    }

    // 同步更新内存，保证调用后立即可读
    _cachedManifest!.updateItem(
      SyncItem(
        filename: filename,
        versionHash: hash,
        versionTimestamp: ts,
        isDeleted: isDeleted,
      ),
    );

    return _enqueue(key, () async {
      try {
        // 以磁盘最新快照为基线再应用本次 mutation
        final disk = await _readDiskSnapshot();
        if (disk == null) {
          // 磁盘快照不可用：跳过写盘，保留磁盘原样，避免覆写损坏文件
          debugPrint(
            'Skip manifest write for $filename: disk snapshot unavailable',
          );
          return;
        }

        final diskExisting = disk.items[filename];
        // 时间戳判胜（磁盘侧）：磁盘上同名条目版本时间戳更新时拒绝
        // 本次旧写入（不限 isDeleted，同时覆盖删除项防复活与普通条目
        // 防旧写覆盖）；相等时遵守现有本地/调用顺序语义，正常写盘。
        if (diskExisting != null && diskExisting.versionTimestamp > ts) {
          return;
        }

        disk.items[filename] = SyncItem(
          filename: filename,
          versionHash: hash,
          versionTimestamp: ts,
          isDeleted: isDeleted,
        );
        await _manifestFile!.writeAsString(jsonEncode(disk.toJson()));
      } catch (e) {
        debugPrint("Error saving manifest: $e");
      }
    });
  }

  /// 移除条目（不含删除标记，用于幽灵项清理）。
  ///
  /// 内存同步移除；写盘进入串行队列，以磁盘最新快照为基线执行，
  /// 避免整体覆盖其他实例的新条目。
  ///
  /// [expectedVersionTimestamp]：调用方观察到的该条目版本。队列内若
  /// 磁盘上同名条目版本比它更新，说明存在并发新写入，跳过删除；
  /// 若本地对应文件仍存在（可能是并发新保存的数据），同样跳过删除，
  /// 防止误删真实数据。幽灵项清理仍可用（幽灵项本地文件缺失且磁盘
  /// 版本不新时正常删除），不改变 JSON 结构。
  Future<void> removeItem(String filename, {int? expectedVersionTimestamp}) {
    final key = _queueKey;
    if (key == null || _cachedManifest == null) return Future.value();

    _cachedManifest!.items.remove(filename);

    return _enqueue(key, () async {
      try {
        final disk = await _readDiskSnapshot();
        if (disk == null) {
          debugPrint(
            'Skip removeItem for $filename: disk snapshot unavailable',
          );
          return;
        }

        final diskItem = disk.items[filename];
        // 并发保护：磁盘上已有比调用观察到的版本更新的同名条目时，
        // 该条目可能是其他实例并发写入的新数据，跳过删除。
        if (diskItem != null &&
            expectedVersionTimestamp != null &&
            diskItem.versionTimestamp > expectedVersionTimestamp) {
          debugPrint('Skip removeItem for $filename: disk has newer version');
          return;
        }

        // 并发保护：本地对应文件仍存在时，可能是并发新保存的真实
        // 数据，跳过删除以免丢失追踪。
        final localFile = _dataDir == null
            ? null
            : File(path.join(_dataDir!.path, filename));
        if (localFile != null && await localFile.exists()) {
          debugPrint('Skip removeItem for $filename: local file still exists');
          return;
        }

        disk.items.remove(filename);
        await _manifestFile!.writeAsString(jsonEncode(disk.toJson()));
      } catch (e) {
        debugPrint("Error saving manifest: $e");
      }
    });
  }

  /// Ensure manifest matches disk content (Migration/Recovery)
  ///
  /// 整体进入串行队列：队列内先重读磁盘最新快照再扫描，避免与并发写
  /// 交错导致旧快照覆盖新条目。
  Future<void> ensureConsistency(
    Directory dataDir, {
    String fileExtension = '.txt',
  }) {
    final key = _queueKey;
    if (key == null || _cachedManifest == null) return Future.value();
    return _enqueue(key, () async {
      await _load();
      if (_cachedManifest == null) return;
      if (!await dataDir.exists()) return;

      final List<FileSystemEntity> files = dataDir.listSync();
      bool changed = false;

      for (var f in files) {
        if (f is File && path.extension(f.path) == fileExtension) {
          final filename = path.basename(f.path);
          final item = _cachedManifest!.items[filename];

          // If untracked or marked deleted but exists -> Update manifest
          if (item == null || item.isDeleted) {
            final ts = await f.lastModified();
            final timestamp = ts.millisecondsSinceEpoch;

            _cachedManifest!.updateItem(
              SyncItem(
                filename: filename,
                versionHash: timestamp.toString(),
                versionTimestamp: timestamp,
                isDeleted: false,
              ),
            );
            changed = true;
            debugPrint("Manifest Migration: Adopted $filename");
          }
        }
      }

      if (changed) await save();
    });
  }

  // Clean up manifest (e.g. remove items that are permanently deleted and synced?)
  // For now keep history.
}
