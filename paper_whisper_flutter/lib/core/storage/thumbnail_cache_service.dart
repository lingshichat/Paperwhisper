import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ThumbnailCacheService {
  static final ThumbnailCacheService _instance =
      ThumbnailCacheService._internal();
  factory ThumbnailCacheService() => _instance;
  ThumbnailCacheService._internal();

  Directory? _cacheDir;
  bool _initialized = false;

  // 缩略图尺寸 - 增大尺寸提高清晰度
  static const int thumbnailSize = 600;

  Future<void> init() async {
    if (_initialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory(path.join(appDir.path, 'thumbnail_cache'));

      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }

      _initialized = true;
      debugPrint('缩略图缓存目录: ${_cacheDir!.path}');
    } catch (e) {
      debugPrint('初始化缩略图缓存失败: $e');
    }
  }

  /// 获取图片的缓存key（使用图片路径的MD5）
  String _getCacheKey(String imagePath) {
    final bytes = utf8.encode(imagePath);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// 获取缓存文件路径
  String _getCacheFilePath(String cacheKey) {
    return path.join(_cacheDir!.path, '$cacheKey.jpg');
  }

  /// 检查缩略图是否存在
  Future<bool> hasThumbnail(String imagePath) async {
    if (!_initialized) await init();
    if (_cacheDir == null) return false;

    final cacheKey = _getCacheKey(imagePath);
    final cacheFile = File(_getCacheFilePath(cacheKey));
    return await cacheFile.exists();
  }

  /// 获取缩略图（从缓存读取）
  Future<Uint8List?> getThumbnail(String imagePath) async {
    if (!_initialized) await init();
    if (_cacheDir == null) return null;

    final cacheKey = _getCacheKey(imagePath);
    final cacheFile = File(_getCacheFilePath(cacheKey));

    if (await cacheFile.exists()) {
      try {
        return await cacheFile.readAsBytes();
      } catch (e) {
        debugPrint('读取缩略图缓存失败: $e');
      }
    }

    return null;
  }

  /// 生成缩略图（使用 compute 在后台线程执行）
  Future<Uint8List?> generateThumbnail(
    String imagePath, {
    int size = thumbnailSize,
  }) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      // 使用 compute 在后台线程处理
      final result = await compute<_ProcessImageData, Uint8List?>(
        _processImage,
        _ProcessImageData(imagePath: imagePath, targetSize: size),
      );

      return result;
    } catch (e) {
      debugPrint('生成缩略图失败: $e');
      return null;
    }
  }

  /// 保存缩略图到缓存
  Future<void> saveThumbnail(String imagePath, Uint8List thumbnailBytes) async {
    if (!_initialized) await init();
    if (_cacheDir == null) return;

    try {
      final cacheKey = _getCacheKey(imagePath);
      final cacheFile = File(_getCacheFilePath(cacheKey));
      await cacheFile.writeAsBytes(thumbnailBytes);
    } catch (e) {
      debugPrint('保存缩略图失败: $e');
    }
  }

  /// 清除所有缓存
  Future<void> clearCache() async {
    if (!_initialized) await init();
    if (_cacheDir == null) return;

    try {
      final files = await _cacheDir!.list().toList();
      for (var file in files) {
        if (file is File) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('清除缩略图缓存失败: $e');
    }
  }
}

// 用于 compute 的数据类
class _ProcessImageData {
  final String imagePath;
  final int targetSize;

  _ProcessImageData({required this.imagePath, required this.targetSize});
}

// 在后台 Isolate 中处理图片
Uint8List? _processImage(_ProcessImageData data) {
  try {
    final file = File(data.imagePath);
    if (!file.existsSync()) return null;

    // 读取原始图片
    final bytes = file.readAsBytesSync();

    // 解码图片
    final original = img.decodeImage(bytes);
    if (original == null) return null;

    // 计算缩略图尺寸（保持比例）
    int targetWidth, targetHeight;
    if (original.width > original.height) {
      targetWidth = data.targetSize;
      targetHeight = (original.height * data.targetSize / original.width)
          .round();
    } else {
      targetHeight = data.targetSize;
      targetWidth = (original.width * data.targetSize / original.height)
          .round();
    }

    // 生成缩略图
    final thumbnail = img.copyResize(
      original,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.cubic,
    );

    // 编码为 JPEG
    final thumbnailBytes = img.encodeJpg(thumbnail, quality: 85);

    return Uint8List.fromList(thumbnailBytes);
  } catch (e) {
    debugPrint('处理图片失败: $e');
    return null;
  }
}
