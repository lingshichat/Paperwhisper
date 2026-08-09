import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/settings/application/settings_storage_controller.dart';

/// 注入替身：不触碰任何文件系统 / IO。
class _FakeStorageGateway implements SettingsStorageGateway {
  int cacheSize = 0;
  int dataSize = 0;
  String dataPath = '/data/user/0/app';
  Map<String, dynamic> internalStats = const {
    'doc': 0,
    'support': 0,
    'clutter': 0,
  };
  bool throwOnLoad = false;

  /// 独立 cleanup seam：置位后四个清理方法统一抛该异常，
  /// 不误用 [throwOnLoad]（后者只影响 load 的 getCacheSize）。
  Object? cleanupError;

  final calls = <String>[];
  int orphanFreed = 0;
  int clutterFreed = 0;

  @override
  Future<int> getCacheSize() async {
    if (throwOnLoad) throw Exception('cache boom');
    return cacheSize;
  }

  @override
  Future<int> getUserDataSize() async => dataSize;

  @override
  Future<String> getDataPath() async => dataPath;

  @override
  Future<Map<String, dynamic>> getInternalStorageStats() async => internalStats;

  void _maybeThrowCleanup() {
    final err = cleanupError;
    if (err != null) throw err;
  }

  @override
  Future<int> cleanOrphanImages() async {
    calls.add('orphan');
    _maybeThrowCleanup();
    return orphanFreed;
  }

  @override
  Future<void> cleanTemporaryCache() async {
    calls.add('cache');
    _maybeThrowCleanup();
  }

  @override
  Future<int> cleanInternalClutter() async {
    calls.add('clutter');
    _maybeThrowCleanup();
    return clutterFreed;
  }

  @override
  Future<void> cleanFontCache() async {
    calls.add('font');
    _maybeThrowCleanup();
  }
}

void main() {
  group('SettingsStorageController.formatSize', () {
    test('边界：B / KB / MB 三分支与四舍五入', () {
      expect(SettingsStorageController.formatSize(0), '0 B');
      expect(SettingsStorageController.formatSize(1023), '1023 B');
      expect(SettingsStorageController.formatSize(1024), '1.0 KB');
      expect(SettingsStorageController.formatSize(1536), '1.5 KB');
      expect(
        SettingsStorageController.formatSize(1024 * 1024 - 1),
        '1024.0 KB',
      );
      expect(SettingsStorageController.formatSize(1024 * 1024), '1.0 MB');
      expect(SettingsStorageController.formatSize(3 * 1024 * 1024), '3.0 MB');
    });
  });

  group('SettingsStorageController.load', () {
    test('成功：缓存 typed snapshot，summary / internalStats 逐字', () async {
      final gateway = _FakeStorageGateway()
        ..cacheSize = 2048
        ..dataSize = 4096
        ..dataPath = '/storage/emulated/0/Android/data/app'
        ..internalStats = {
          'doc': 1024 * 1024,
          'support': 512 * 1024,
          'clutter': 2 * 1024 * 1024,
        };
      final controller = SettingsStorageController(gateway: gateway);

      final snap = await controller.load();

      expect(snap.cacheSize, 2048);
      expect(snap.dataSize, 4096);
      expect(snap.totalSize, 6144);
      expect(snap.docSize, 1024 * 1024);
      expect(snap.supportSize, 512 * 1024);
      expect(snap.clutterSize, 2 * 1024 * 1024);
      // 逐字 settings 文案。
      expect(snap.summary, '内容占用: 6.0 KB (缓存: 2.0 KB)');
      expect(snap.internalStats, 'Doc: 1.0 MB / Support: 512.0 KB');
      expect(controller.snapshot, same(snap));
    });

    test('clutter 阈值：外部路径 + 残留 >1MB 为 true', () async {
      final gateway = _FakeStorageGateway()
        ..dataPath = '/storage/emulated/0/Android/data/app'
        ..internalStats = {'doc': 0, 'support': 0, 'clutter': 1024 * 1024 + 1};
      final controller = SettingsStorageController(gateway: gateway);

      final snap = await controller.load();
      expect(snap.hasInternalClutter, isTrue);
    });

    test('clutter 阈值：恰好 1MB 不算（> 严格大于）', () async {
      final gateway = _FakeStorageGateway()
        ..dataPath = '/storage/emulated/0/Android/data/app'
        ..internalStats = {'doc': 0, 'support': 0, 'clutter': 1024 * 1024};
      final controller = SettingsStorageController(gateway: gateway);

      final snap = await controller.load();
      expect(snap.hasInternalClutter, isFalse);
    });

    test('clutter 阈值：非外部路径即使残留巨大也为 false', () async {
      final gateway = _FakeStorageGateway()
        ..dataPath = '/data/user/0/app'
        ..internalStats = {
          'doc': 0,
          'support': 0,
          'clutter': 100 * 1024 * 1024,
        };
      final controller = SettingsStorageController(gateway: gateway);

      final snap = await controller.load();
      expect(snap.hasInternalClutter, isFalse);
    });

    test('load 异常：向调用方传播（页面无 try/catch 语义），不缓存快照', () async {
      final gateway = _FakeStorageGateway()..throwOnLoad = true;
      final controller = SettingsStorageController(gateway: gateway);

      await expectLater(controller.load(), throwsException);
      expect(controller.snapshot, isNull);
    });
  });

  group('SettingsStorageController 清理动作', () {
    test('每个 cleanup 透传并返回 typed 结果', () async {
      final gateway = _FakeStorageGateway()
        ..orphanFreed = 12345
        ..clutterFreed = 999;
      final controller = SettingsStorageController(gateway: gateway);

      expect(await controller.cleanOrphanImages(), 12345);
      await controller.cleanTemporaryCache();
      expect(await controller.cleanInternalClutter(), 999);
      await controller.cleanFontCache();

      expect(gateway.calls, ['orphan', 'cache', 'clutter', 'font']);
    });

    test('cleanup 异常：向调用方传播（四个清理动作各自独立）', () async {
      final gateway = _FakeStorageGateway();
      final controller = SettingsStorageController(gateway: gateway);

      gateway.cleanupError = Exception('orphan boom');
      await expectLater(controller.cleanOrphanImages(), throwsException);

      gateway.cleanupError = Exception('cache boom');
      await expectLater(controller.cleanTemporaryCache(), throwsException);

      gateway.cleanupError = Exception('clutter boom');
      await expectLater(controller.cleanInternalClutter(), throwsException);

      gateway.cleanupError = Exception('font boom');
      await expectLater(controller.cleanFontCache(), throwsException);
    });

    test('dispose 后 load / clean 抛 StateError，不产生状态变更', () async {
      final gateway = _FakeStorageGateway()..cacheSize = 1;
      final controller = SettingsStorageController(gateway: gateway);

      controller.dispose();
      await expectLater(controller.load(), throwsStateError);
      await expectLater(controller.cleanOrphanImages(), throwsStateError);
      expect(controller.snapshot, isNull);
    });
  });
}
