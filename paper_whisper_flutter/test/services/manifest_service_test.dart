import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:paper_whisper_flutter/features/sync/data/manifest_service.dart';

void main() {
  group('ManifestService', () {
    late Directory tempDir;
    late Directory dataDir;
    late ManifestService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('manifest_service_test');
      dataDir = Directory(path.join(tempDir.path, 'diary_data'));
      await dataDir.create(recursive: true);
      service = ManifestService();
      await service.init(dataDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('ensureConsistency adopts untracked files from disk', () async {
      const filename = '2026-03-12_a.txt';
      final file = File(path.join(dataDir.path, filename));
      await file.writeAsString('hello');

      await service.ensureConsistency(dataDir);

      final item = service.manifest.items[filename];
      expect(item, isNotNull);
      expect(item!.isDeleted, isFalse);
      expect(item.versionTimestamp, greaterThan(0));
    });

    test(
      'ensureConsistency revives deleted entry when local file exists',
      () async {
        const filename = '2026-03-12_b.txt';
        final file = File(path.join(dataDir.path, filename));
        await file.writeAsString('still here');

        service.updateItem(filename, isDeleted: true, timestamp: 1);

        await service.ensureConsistency(dataDir);

        final item = service.manifest.items[filename];
        expect(item, isNotNull);
        expect(item!.isDeleted, isFalse);
        expect(item.versionTimestamp, greaterThan(1));
      },
    );
  });

  group('ManifestService 多实例并发矩阵', () {
    /// 两个独立实例 init 同一个 dataDir（写同一 manifest 文件），
    /// 模拟「页面实例 vs 同步实例」各自持内存缓存的真实场景。
    late Directory tempDir;
    late Directory dataDir;
    late File manifestFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('manifest_matrix_test');
      dataDir = Directory(path.join(tempDir.path, 'diary_data'));
      await dataDir.create(recursive: true);
      manifestFile = File(path.join(tempDir.path, 'local_manifest.json'));
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<ManifestService> freshInstance() async {
      final instance = ManifestService();
      await instance.init(dataDir);
      return instance;
    }

    test('并发写入不同条目：两个实例的条目都保留（不互相覆盖）', () async {
      final a = await freshInstance();
      final b = await freshInstance();

      // 不 await 中间结果：A 写 a.txt、B 写 b.txt 交错入队
      final f1 = a.updateItem(
        '2026-03-12_a.txt',
        isDeleted: false,
        timestamp: 100,
      );
      final f2 = b.updateItem(
        '2026-03-12_b.txt',
        isDeleted: false,
        timestamp: 200,
      );
      await Future.wait(<Future<void>>[f1, f2]);

      // 断言以磁盘为准：全新实例重读，不依赖任一实例内存缓存
      final disk = await freshInstance();
      final keys = disk.manifest.items.keys.toList();
      expect(
        keys,
        containsAll(<String>['2026-03-12_a.txt', '2026-03-12_b.txt']),
      );
    });

    test('同一条目新时间戳写入后，旧时间戳不回退', () async {
      final a = await freshInstance();
      final b = await freshInstance();

      // A 先写 ts=200（较新），B 后写同条目 ts=100（较旧）
      final f1 = a.updateItem(
        '2026-03-12_x.txt',
        isDeleted: false,
        timestamp: 200,
      );
      final f2 = b.updateItem(
        '2026-03-12_x.txt',
        isDeleted: false,
        timestamp: 100,
      );
      await Future.wait(<Future<void>>[f1, f2]);

      final disk = await freshInstance();
      final item = disk.manifest.items['2026-03-12_x.txt'];
      expect(item, isNotNull);
      expect(item!.versionTimestamp, 200, reason: '旧时间戳写入不得覆盖新版本');
    });

    test('新删除标记后旧未删除写入不复活', () async {
      final a = await freshInstance();
      final b = await freshInstance();

      // A 写删除（ts=200，较新），B 后写未删除（ts=100，较旧）
      final f1 = a.updateItem(
        '2026-03-12_del.txt',
        isDeleted: true,
        timestamp: 200,
      );
      final f2 = b.updateItem(
        '2026-03-12_del.txt',
        isDeleted: false,
        timestamp: 100,
      );
      await Future.wait(<Future<void>>[f1, f2]);

      final disk = await freshInstance();
      final item = disk.manifest.items['2026-03-12_del.txt'];
      expect(item, isNotNull);
      expect(item!.isDeleted, isTrue, reason: '旧未删除写入不得复活已删除条目');
      expect(item.versionTimestamp, 200);
    });

    test('removeItem expectedVersion 与并发 update 交错：新条目不被幽灵清理', () async {
      final a = await freshInstance();
      final b = await freshInstance();

      // 1) 实例 A 先落盘 g.txt ts=100 并 await，保证磁盘与 A 的内存均已就绪。
      //    实例 A/B 均 init 同一 dataDir，指向同一物理 manifest 文件
      //    （tempDir/local_manifest.json），即同一条串行写队列。
      await a.updateItem('2026-03-12_g.txt', isDeleted: false, timestamp: 100);
      expect(
        await manifestFile.exists(),
        isTrue,
        reason: 'A 落盘后共享 manifest 文件应已创建',
      );
      final seeded =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      expect(
        (seeded['items'] as Map<String, dynamic>).containsKey(
          '2026-03-12_g.txt',
        ),
        isTrue,
        reason: 'A 落盘的 g.txt 应写入共享 manifest 文件（A/B 同路径前提）',
      );

      // 2) 按调用顺序：B 先入队 update g.txt ts=200（并发新版本），
      //    A 再以旧版本 100 入队 remove（幽灵清理）。
      //    串行队列内 remove 必然在 update 之后执行：若无 expectedVersion
      //    并发保护，remove 会以旧快照删除 ts=200 的新条目。
      final f1 = b.updateItem(
        '2026-03-12_g.txt',
        isDeleted: false,
        timestamp: 200,
      );
      final f2 = a.removeItem(
        '2026-03-12_g.txt',
        expectedVersionTimestamp: 100,
      );
      await Future.wait(<Future<void>>[f1, f2]);

      // 3) 全新实例重读磁盘：g.txt 必须仍存在、未删除且版本为 ts=200。
      final disk = await freshInstance();
      final item = disk.manifest.items['2026-03-12_g.txt'];
      expect(item, isNotNull, reason: '并发新版本不得被旧快照的幽灵清理删除');
      expect(item!.isDeleted, isFalse, reason: '新条目不得被误标为删除');
      expect(
        item.versionTimestamp,
        200,
        reason: 'remove 不得覆盖 update 写入的新版本时间戳',
      );
    });

    test('await update/remove resolve 后磁盘已更新（新实例可读）', () async {
      final a = await freshInstance();
      final b = await freshInstance();

      await a.updateItem(
        '2026-03-12_await.txt',
        isDeleted: false,
        timestamp: 42,
      );
      // remove 在磁盘上存在该条目时生效（本地无对应文件）
      await b.removeItem('2026-03-12_await.txt', expectedVersionTimestamp: 42);

      final disk = await freshInstance();
      expect(disk.manifest.items.containsKey('2026-03-12_await.txt'), isFalse);
    });

    test('损坏 JSON 时 mutation 不覆写原文件', () async {
      await manifestFile.writeAsString('{not-valid-json!!');

      final a = await freshInstance();

      await a.updateItem('2026-03-12_c.txt', isDeleted: false, timestamp: 5);

      // 磁盘原样保留：损坏内容不被空快照整体覆盖
      expect(await manifestFile.readAsString(), '{not-valid-json!!');
    });

    test('ensureConsistency 与并发 update 并集（扫描采纳 + 新条目共存）', () async {
      // 磁盘上存在未登记文件 a.txt、b.txt
      await File(
        path.join(dataDir.path, '2026-03-12_a.txt'),
      ).writeAsString('a');
      await File(
        path.join(dataDir.path, '2026-03-12_b.txt'),
      ).writeAsString('b');

      final a = await freshInstance();
      final b = await freshInstance();

      // 交错：A 做 ensureConsistency 扫描采纳，B 并发登记新条目 c.txt
      final f1 = a.ensureConsistency(dataDir);
      final f2 = b.updateItem(
        '2026-03-12_c.txt',
        isDeleted: false,
        timestamp: 300,
      );
      await Future.wait(<Future<void>>[f1, f2]);

      final disk = await freshInstance();
      final keys = disk.manifest.items.keys.toList();
      expect(
        keys,
        containsAll(<String>[
          '2026-03-12_a.txt',
          '2026-03-12_b.txt',
          '2026-03-12_c.txt',
        ]),
      );
      // 扫描采纳的文件保持未删除语义
      expect(disk.manifest.items['2026-03-12_a.txt']!.isDeleted, isFalse);
      // JSON 仍可解析（非空快照覆盖损坏/整体覆盖）
      final raw = jsonDecode(await manifestFile.readAsString());
      expect(raw, isA<Map<String, dynamic>>());
    });
  });
}
