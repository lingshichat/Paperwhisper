import 'dart:io';

/// 随心记存储对跨域缓存清理暴露的最小端口。
///
/// core 只依赖目录与已引用图片名，不读取随心记业务模型。
abstract interface class MomentStorageAccess {
  Directory? get dataDir;

  Future<void> init();

  Future<Set<String>> getAllReferencedImages();
}
