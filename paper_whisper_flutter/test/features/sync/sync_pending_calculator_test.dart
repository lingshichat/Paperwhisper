import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:paper_whisper_flutter/features/sync/application/sync_pending_calculator.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_scope_cache_store.dart';
import 'package:paper_whisper_flutter/models/moment.dart';
import 'package:paper_whisper_flutter/models/sync_config.dart';
import 'package:paper_whisper_flutter/models/sync_manifest.dart';
import 'package:paper_whisper_flutter/services/moment_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncPendingCalculator.countPendingManifestItems', () {
    SyncItem item(
      String filename, {
      int timestamp = 0,
      String? hash,
      bool isDeleted = false,
    }) {
      return SyncItem(
        filename: filename,
        versionHash: hash ?? '$timestamp',
        versionTimestamp: timestamp,
        isDeleted: isDeleted,
      );
    }

    test('counts local-only items as pending', () {
      final local = SyncManifest(
        lastSyncTimestamp: 0,
        items: {'a.txt': item('a.txt', timestamp: 1)},
      );
      expect(
        SyncPendingCalculator.countPendingManifestItems(
          local,
          SyncManifest(lastSyncTimestamp: 0, items: {}),
        ),
        1,
      );
    });

    test('ignores remote-only items (local side decides)', () {
      final remote = SyncManifest(
        lastSyncTimestamp: 0,
        items: {'a.txt': item('a.txt', timestamp: 1)},
      );
      expect(
        SyncPendingCalculator.countPendingManifestItems(
          SyncManifest(lastSyncTimestamp: 0, items: {}),
          remote,
        ),
        0,
      );
    });

    test('identical items are not pending', () {
      final manifest = SyncManifest(
        lastSyncTimestamp: 0,
        items: {'a.txt': item('a.txt', timestamp: 7, hash: 'h')},
      );
      expect(
        SyncPendingCalculator.countPendingManifestItems(manifest, manifest),
        0,
      );
    });

    test('counts items that differ in timestamp, hash or deleted flag', () {
      final base = SyncManifest(
        lastSyncTimestamp: 0,
        items: {'a.txt': item('a.txt', timestamp: 10)},
      );
      final byTimestamp = SyncManifest(
        lastSyncTimestamp: 0,
        items: {'a.txt': item('a.txt', timestamp: 11)},
      );
      final byHash = SyncManifest(
        lastSyncTimestamp: 0,
        items: {'a.txt': item('a.txt', timestamp: 10, hash: 'other')},
      );
      final byDeleted = SyncManifest(
        lastSyncTimestamp: 0,
        items: {'a.txt': item('a.txt', timestamp: 10, isDeleted: true)},
      );

      expect(
        SyncPendingCalculator.countPendingManifestItems(base, byTimestamp),
        1,
      );
      expect(SyncPendingCalculator.countPendingManifestItems(base, byHash), 1);
      expect(
        SyncPendingCalculator.countPendingManifestItems(base, byDeleted),
        1,
      );
    });

    test('sums across a mixed manifest', () {
      final local = SyncManifest(
        lastSyncTimestamp: 0,
        items: {
          'only_local.txt': item('only_local.txt', timestamp: 1),
          'changed.txt': item('changed.txt', timestamp: 100),
          'same.txt': item('same.txt', timestamp: 50),
        },
      );
      final remote = SyncManifest(
        lastSyncTimestamp: 0,
        items: {
          'changed.txt': item('changed.txt', timestamp: 99),
          'same.txt': item('same.txt', timestamp: 50),
          'remote_only.txt': item('remote_only.txt', timestamp: 1),
        },
      );

      expect(SyncPendingCalculator.countPendingManifestItems(local, remote), 2);
    });
  });

  group('SyncPendingCalculator.countPendingAssetNames', () {
    test('counts both directions of the difference', () {
      expect(
        SyncPendingCalculator.countPendingAssetNames(
          {'a.jpg', 'b.jpg'},
          {'b.jpg', 'c.jpg'},
        ),
        2, // a.jpg (local only) + c.jpg (remote only)
      );
    });

    test('empty sets produce zero', () {
      expect(SyncPendingCalculator.countPendingAssetNames({}, {}), 0);
      expect(
        SyncPendingCalculator.countPendingAssetNames({'a.jpg'}, {'a.jpg'}),
        0,
      );
    });

    test('all-local and all-remote sets are fully pending', () {
      expect(
        SyncPendingCalculator.countPendingAssetNames({
          'a.jpg',
          'b.jpg',
        }, <String>{}),
        2,
      );
      expect(
        SyncPendingCalculator.countPendingAssetNames(<String>{}, {'x.m4a'}),
        1,
      );
    });
  });

  group('SyncPendingCalculator.calculate', () {
    late Directory baseDir;
    late SharedPreferences prefs;
    late SyncScopeCacheStore store;
    late MomentService momentService;
    late SyncPendingCalculator calculator;
    late FakeDiaryService diaryService;

    SyncConfig webdavConfig({String username = 'user'}) {
      return SyncConfig(
        syncType: SyncType.webdav,
        enabled: true,
        serverUrl: 'https://dav.example.com/',
        username: username,
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      store = SyncScopeCacheStore(prefsFactory: () async => prefs);

      baseDir = await Directory.systemTemp.createTemp('sync_pending_test');
      // 真实 MomentService：manifest 写入 baseDir（dataDir 的父目录），
      // tearDown 删除 baseDir 时一并清理
      momentService = MomentService(
        debugDataDir: Directory(path.join(baseDir.path, 'moments_data')),
      );
      calculator = SyncPendingCalculator(
        scopeCacheStore: store,
        momentService: momentService,
      );

      diaryService = FakeDiaryService(baseDir);
      await diaryService.init();
    });

    tearDown(() async {
      if (await baseDir.exists()) {
        await baseDir.delete(recursive: true);
      }
    });

    Future<void> seedLocalData() async {
      // 日记：2 个 txt 文件
      for (final name in ['2026-01-01_a.txt', '2026-01-02_b.txt']) {
        final file = File(path.join(diaryService.dataDir!.path, name));
        await file.writeAsString('content $name');
      }

      // 随心记：2 个 JSON（各引用一张图）+ 2 张图片 + 2 段语音
      await momentService.init();
      for (final id in [1, 2]) {
        final moment = Moment(
          uuid: 'u$id',
          content: 'moment $id',
          images: <String>['images/img_$id.jpg'],
          createdAt: DateTime(2026, 1, id),
        );
        await File(
          path.join(momentService.dataDir!.path, 'moment_u$id.json'),
        ).writeAsString(moment.toJsonString());
        await File(
          path.join(momentService.imagesDir!.path, 'img_$id.jpg'),
        ).writeAsString('img-$id');
        await File(
          path.join(momentService.audioDir!.path, 'rec_$id.m4a'),
        ).writeAsString('audio-$id');
      }
    }

    Future<void> saveBaselineFor(SyncConfig config) async {
      // 基线必须反映 ensureConsistency 之后的 manifest（与 calculate 内部一致），
      // 否则保存的是空 manifest，后续 calculate 仍会判为 pending。
      await diaryService.init();
      await diaryService.manifestService.ensureConsistency(
        diaryService.dataDir!,
      );
      await momentService.init();
      await momentService.manifestService.ensureConsistency(
        momentService.dataDir!,
        fileExtension: '.json',
      );

      await store.saveCachedManifest(
        SyncScopeCacheStore.lastKnownRemoteManifestKey,
        config,
        diaryService.manifestService.manifest,
      );
      await store.saveCachedManifest(
        SyncScopeCacheStore.lastKnownMomentsManifestKey,
        config,
        momentService.manifestService.manifest,
      );
      await store.saveCachedNameSet(
        SyncScopeCacheStore.lastKnownMomentImagesKey,
        config,
        await momentService.getAllReferencedImages(),
      );
      await store.saveCachedNameSet(
        SyncScopeCacheStore.lastKnownMomentAudioKey,
        config,
        await calculator.getLocalAudioNames(),
      );
    }

    test('without any baseline every category is pending', () async {
      await seedLocalData();

      final counts = await calculator.calculate(
        webdavConfig(),
        diaryService: diaryService,
      );

      expect(counts.diaries, 2);
      expect(counts.moments, 2);
      expect(counts.images, 2);
      expect(counts.audio, 2);
      expect(counts.total, 8);
    });

    test('diary side is zero when diary service is absent', () async {
      await seedLocalData();

      final counts = await calculator.calculate(webdavConfig());

      expect(counts.diaries, 0);
      expect(counts.moments, 2);
      expect(counts.images, 2);
      expect(counts.audio, 2);
      expect(counts.total, 6);
    });

    test('a matching baseline makes the same scope fully clean', () async {
      await seedLocalData();
      final config = webdavConfig();

      // 第一次计算会触发 manifest ensureConsistency，随后保存一致基线
      final before = await calculator.calculate(
        config,
        diaryService: diaryService,
      );
      expect(before.total, 8);

      await saveBaselineFor(config);

      final after = await calculator.calculate(
        config,
        diaryService: diaryService,
      );
      expect(after.diaries, 0);
      expect(after.moments, 0);
      expect(after.images, 0);
      expect(after.audio, 0);
      expect(after.total, 0);
    });

    test('baselines are isolated per remote scope', () async {
      await seedLocalData();
      final syncedScope = webdavConfig(username: 'user');
      final otherScope = webdavConfig(username: 'other');

      await saveBaselineFor(syncedScope);

      final clean = await calculator.calculate(
        syncedScope,
        diaryService: diaryService,
      );
      expect(clean.total, 0);

      // 未同步过的 scope 不共享基线，全部视为 pending
      final pending = await calculator.calculate(
        otherScope,
        diaryService: diaryService,
      );
      expect(pending.diaries, 2);
      expect(pending.moments, 2);
      expect(pending.images, 2);
      expect(pending.audio, 2);
      expect(pending.total, 8);
    });
  });
}
