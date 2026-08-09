import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'moment_service.dart';
import 'thumbnail_cache_service.dart';
import 'package:flutter/painting.dart';

class StorageService {
  final MomentService _momentService;

  /// 注入共享 MomentService（读目录大小/清理孤儿），不维护独立实例。
  StorageService({required MomentService momentService})
    : _momentService = momentService;

  /// 获取缓存大小（字节）
  Future<int> getCacheSize() async {
    try {
      int totalSize = 0;

      // 1. 临时目录缓存
      final tempDir = await getTemporaryDirectory();
      if (Platform.isWindows) {
        final libCache = Directory(
          path.join(tempDir.path, 'libCachedImageData'),
        );
        if (await libCache.exists()) {
          totalSize += await _getDirSize(libCache);
        }
      } else {
        totalSize += await _getDirSize(tempDir);
      }

      // 2. 图库缩略图缓存
      final thumbnailCache = ThumbnailCacheService();
      await thumbnailCache.init();
      final thumbDir = Directory(
        path.join(
          (await getApplicationDocumentsDirectory()).path,
          'thumbnail_cache',
        ),
      );
      if (await thumbDir.exists()) {
        totalSize += await _getDirSize(thumbDir);
      }

      return totalSize;
    } catch (e) {
      debugPrint("Error getting cache size: $e");
      return 0;
    }
  }

  /// 获取用户数据大小（字节）- 主要是 Moments Images
  Future<int> getUserDataSize() async {
    try {
      await _momentService.init();
      final dataDir = _momentService.dataDir;
      if (dataDir == null) return 0;
      return _getDirSize(dataDir);
    } catch (e) {
      debugPrint("Error getting user data size: $e");
      return 0;
    }
  }

  Future<String> getDataPath() async {
    await _momentService.init();
    return _momentService.dataDir?.path ?? "未初始化";
  }

  Future<int> _getDirSize(Directory dir) async {
    int size = 0;
    try {
      if (await dir.exists()) {
        await for (var entity in dir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            size += await entity.length();
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return size;
  }

  /// 清理临时缓存
  Future<void> cleanTemporaryCache() async {
    debugPrint("Starting Cache Cleanup...");
    try {
      final tempDir = await getTemporaryDirectory();

      if (Platform.isWindows) {
        // Windows: Only clean specific subdirectory
        final libCache = Directory(
          path.join(tempDir.path, 'libCachedImageData'),
        );
        if (await libCache.exists()) {
          await libCache.delete(recursive: true);
          debugPrint("Deleted Windows cache: ${libCache.path}");
        }
      } else {
        // Android/iOS: Clean entire temp dir
        if (await tempDir.exists()) {
          await for (var entity in tempDir.list(followLinks: false)) {
            try {
              if (entity is File) {
                await entity.delete();
              } else if (entity is Directory) {
                await entity.delete(recursive: true);
              }
            } catch (e) {
              debugPrint("Failed to delete temp file ${entity.path}: $e");
            }
          }
        }
      }

      // 2. 清理图库缩略图缓存
      final thumbnailCache = ThumbnailCacheService();
      await thumbnailCache.clearCache();
      debugPrint("Deleted thumbnail cache");

      // 3. 清理内存图片缓存
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      debugPrint("Cache Cleanup Finished.");
    } catch (e) {
      debugPrint("Error cleaning cache: $e");
    }
  }

  /// 深度清理：移除未被引用的孤儿图片
  /// 返回清理释放的字节数
  Future<int> cleanOrphanImages() async {
    debugPrint("Starting Deep Cleanup (Orphan Images)...");
    int deletedBytes = 0;

    try {
      await _momentService.init();
      final dataDir = _momentService.dataDir;
      if (dataDir == null) return 0;

      final imagesDir = Directory(path.join(dataDir.path, 'images'));
      if (!await imagesDir.exists()) return 0;

      // 1. 获取所有有效的图片引用
      final moments = await _momentService.getMoments();
      final Set<String> validImageNames = {};

      for (var m in moments) {
        for (var relativePath in m.images) {
          // relativePath is usually "images/xxx.jpg" or "xxx.jpg" (older versions)
          String name = path.basename(relativePath);
          validImageNames.add(name);
        }
      }

      // 2. 遍历 images 目录
      final entities = await imagesDir.list().toList();
      for (var entity in entities) {
        if (entity is File) {
          final name = path.basename(entity.path);
          // 排除 .nomedia 等系统文件
          if (name == '.nomedia') continue;

          if (!validImageNames.contains(name)) {
            // 发现孤儿文件
            int size = await entity.length();
            await entity.delete();
            deletedBytes += size;
            debugPrint("Deleted orphan image: $name ($size bytes)");
          }
        }
      }
    } catch (e) {
      debugPrint("Error during deep cleanup: $e");
    }

    debugPrint("Deep Cleanup Finished. Freed ${_formatSize(deletedBytes)}");
    return deletedBytes;
  }

  /// 清理字体缓存 (Google Fonts)
  Future<int> cleanFontCache() async {
    int freed = 0;
    try {
      final supportDir = await getApplicationSupportDirectory();
      if (await supportDir.exists()) {
        await for (var entity in supportDir.list()) {
          if (entity is File) {
            String name = path.basename(entity.path).toLowerCase();
            if (name.endsWith('.ttf') ||
                name.endsWith('.otf') ||
                name.endsWith('.dat')) {
              int size = await entity.length();
              await entity.delete();
              freed += size;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error cleaning font cache: $e");
    }
    return freed;
  }

  /// 获取 App 私有数据目录大小 (Internal Storage)
  /// 这部分对应安卓系统设置里的 "用户数据"
  Future<Map<String, dynamic>> getInternalStorageStats() async {
    int docSize = 0;
    int supportSize = 0;
    String supportDetails = "";
    String docDetails = "";
    int clutterSize =
        0; // Size of redundant user data (moments/trash) in internal

    try {
      final docDir = await getApplicationDocumentsDirectory();
      docSize = await _getDirSize(docDir);

      // List top-level items in Doc and calc clutter
      if (await docDir.exists()) {
        List<String> items = [];
        await for (var entity in docDir.list()) {
          int size = await _getDirSize(
            entity is Directory ? entity : Directory(entity.path),
          );
          items.add("${path.basename(entity.path)} (${_formatSize(size)})");

          String name = path.basename(entity.path);
          if (name == 'moments_data' || name == 'trash_data') {
            clutterSize += size;
          }
        }
        docDetails = items.join(", ");
      }
    } catch (e) {
      debugPrint('StorageService getInternalStorageStats doc error: $e');
    }

    try {
      final supportDir = await getApplicationSupportDirectory();
      supportSize = await _getDirSize(supportDir);

      // List top-level items in Support
      if (await supportDir.exists()) {
        List<String> items = [];
        await for (var entity in supportDir.list()) {
          int size = await _getDirSize(
            entity is Directory ? entity : Directory(entity.path),
          );
          items.add("${path.basename(entity.path)} (${_formatSize(size)})");
        }
        supportDetails = items.join(", ");
      }
    } catch (e) {
      debugPrint('StorageService getInternalStorageStats support error: $e');
    }

    return {
      'doc': docSize,
      'docDetails': docDetails,
      'support': supportSize,
      'supportDetails': supportDetails,
      'clutter': clutterSize,
    };
  }

  /// 强力清理私有目录残留 (慎用)
  /// 清理 docDir 下除了 known files 以外的内容
  Future<int> cleanInternalClutter() async {
    int freed = 0;
    final docDir = await getApplicationDocumentsDirectory();
    // Beware: SharedPrefs file is NOT in docDir, it's in /shared_prefs sibling.
    // docDir usually contains: app_flutter/ ...

    if (await docDir.exists()) {
      await for (var entity in docDir.list()) {
        String name = path.basename(entity.path);
        // 如果我们当前用的不是这个目录 (e.g. 用的是外部存储), 那么这里的 moments_data 全是旧数据
        if (_momentService.dataDir?.path != entity.path) {
          // simple check
          // 进一步检查：如果当前 dataDir 在 External, 那么 Internal 里的 moments_data 可以删
          // 如果 name 是 'flutter_assets' 等需保留
          if (name == 'moments_data' || name == 'trash_data') {
            int size = await _getDirSize(
              entity is Directory ? entity : Directory(entity.path),
            );
            await entity.delete(recursive: true);
            freed += size;
          }
        }
      }
    }
    return freed;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }
}
