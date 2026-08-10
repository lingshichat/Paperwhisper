import 'package:paper_whisper_flutter/core/storage/storage_service.dart';

/// 设置页存储快照（typed）。
class SettingsStorageSnapshot {
  const SettingsStorageSnapshot({
    required this.cacheSize,
    required this.dataSize,
    required this.dataPath,
    required this.docSize,
    required this.supportSize,
    required this.clutterSize,
    required this.hasInternalClutter,
  });

  final int cacheSize;
  final int dataSize;
  final String dataPath;
  final int docSize;
  final int supportSize;

  /// 内部私有目录冗余数据量（moments_data / trash_data）。
  final int clutterSize;

  /// 外部路径 + 内部残留 > 1MB（逐字 settings `_hasInternalClutter` 判定）。
  final bool hasInternalClutter;

  /// 内容占用合计（cache + data，settings 语义）。
  int get totalSize => cacheSize + dataSize;

  /// 逐字保留 settings `_storageInfo` 文案。
  String get summary =>
      '内容占用: ${SettingsStorageController.formatSize(totalSize)} (缓存: ${SettingsStorageController.formatSize(cacheSize)})';

  /// 逐字保留 settings `_internalStats` 文案。
  String get internalStats =>
      'Doc: ${SettingsStorageController.formatSize(docSize)} / Support: ${SettingsStorageController.formatSize(supportSize)}';
}

/// 设置页存储数据网关（controller 唯一数据来源 seam，测试注入替身）。
///
/// 覆盖 settings `_loadStorageInfo` 与四个清理动作的全部数据访问；
/// 生产适配器包装现有 [StorageService]，不新建 MomentService。
abstract interface class SettingsStorageGateway {
  Future<int> getCacheSize();
  Future<int> getUserDataSize();
  Future<String> getDataPath();
  Future<Map<String, dynamic>> getInternalStorageStats();
  Future<int> cleanOrphanImages();
  Future<void> cleanTemporaryCache();
  Future<int> cleanInternalClutter();
  Future<void> cleanFontCache();
}

/// 生产适配器：包装 [StorageService] 实例。
///
/// 实例由接线方提供（如 `StorageService(momentService: ...)`），
/// 与页面现注入方式一致，本适配器不创建任何服务。
class SettingsStorageGatewayAdapter implements SettingsStorageGateway {
  SettingsStorageGatewayAdapter(this._service);

  final StorageService _service;

  @override
  Future<int> getCacheSize() => _service.getCacheSize();

  @override
  Future<int> getUserDataSize() => _service.getUserDataSize();

  @override
  Future<String> getDataPath() => _service.getDataPath();

  @override
  Future<Map<String, dynamic>> getInternalStorageStats() =>
      _service.getInternalStorageStats();

  @override
  Future<int> cleanOrphanImages() => _service.cleanOrphanImages();

  @override
  Future<void> cleanTemporaryCache() => _service.cleanTemporaryCache();

  @override
  Future<int> cleanInternalClutter() => _service.cleanInternalClutter();

  @override
  Future<void> cleanFontCache() => _service.cleanFontCache();
}

/// 设置页存储控制器（context-free）。
///
/// 职责边界：
/// - load 返回 typed snapshot（cache/data/path/doc/support/clutter 与
///   external+clutter>1MiB 判定）；与页面一致不做 try/catch，异常向调用方传播；
/// - 四个清理动作 typed 透传（orphan/clutter 返回释放字节数）；
/// - formatSize 为纯静态函数（逐字 settings `_formatSize`）；
/// - dispose 后任何公开方法抛 [StateError]，不再变更状态。
class SettingsStorageController {
  SettingsStorageController({required SettingsStorageGateway gateway})
    : _gateway = gateway;

  final SettingsStorageGateway _gateway;

  SettingsStorageSnapshot? _snapshot;
  bool _disposed = false;

  /// 最近一次 load 的快照；未加载时为 null。
  SettingsStorageSnapshot? get snapshot => _snapshot;

  void _ensureUsable() {
    if (_disposed) {
      throw StateError('SettingsStorageController 已 dispose');
    }
  }

  /// 汇总存储信息并返回 typed snapshot。异常不做捕获，向调用方传播
  /// （与页面现有 `_loadStorageInfo` 语义一致）。
  Future<SettingsStorageSnapshot> load() async {
    _ensureUsable();
    final cacheSize = await _gateway.getCacheSize();
    final dataSize = await _gateway.getUserDataSize();
    final path = await _gateway.getDataPath();
    final internal = await _gateway.getInternalStorageStats();

    final docSize = internal['doc'] as int? ?? 0;
    final supportSize = internal['support'] as int? ?? 0;
    final clutterSize = internal['clutter'] as int? ?? 0;

    // 逐字保留 settings clutter 判定：外部路径 + 内部残留 > 1MB。
    final usingExternal = path.contains('/storage/emulated/0');
    final hasClutter = usingExternal && clutterSize > 1024 * 1024;

    final snap = SettingsStorageSnapshot(
      cacheSize: cacheSize,
      dataSize: dataSize,
      dataPath: path,
      docSize: docSize,
      supportSize: supportSize,
      clutterSize: clutterSize,
      hasInternalClutter: hasClutter,
    );
    _ensureUsable();
    _snapshot = snap;
    return snap;
  }

  /// 清理无用图片，返回释放字节数。
  Future<int> cleanOrphanImages() async {
    _ensureUsable();
    final freed = await _gateway.cleanOrphanImages();
    _ensureUsable();
    return freed;
  }

  /// 清理临时缓存。
  Future<void> cleanTemporaryCache() async {
    _ensureUsable();
    await _gateway.cleanTemporaryCache();
    _ensureUsable();
  }

  /// 清理内部私有残留，返回释放字节数。
  Future<int> cleanInternalClutter() async {
    _ensureUsable();
    final freed = await _gateway.cleanInternalClutter();
    _ensureUsable();
    return freed;
  }

  /// 清理字体缓存。
  Future<void> cleanFontCache() async {
    _ensureUsable();
    await _gateway.cleanFontCache();
    _ensureUsable();
  }

  /// 纯函数：字节数 → 人类可读大小（逐字 settings `_formatSize`）。
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 释放：之后所有公开方法抛 [StateError]，不产生任何状态变更。
  void dispose() => _disposed = true;
}
