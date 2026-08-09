import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:paper_whisper_flutter/features/sync/application/sync_error_classifier.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_progress_tracker.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_runner.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_scope_cache_store.dart';
import 'package:paper_whisper_flutter/models/sync_manifest.dart';
import 'package:paper_whisper_flutter/services/webdav_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncRunner.mergeManifests', () {
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

    test('keeps items that exist on only one side', () {
      final local = SyncManifest(
        lastSyncTimestamp: 1,
        items: {'a.txt': item('a.txt', timestamp: 100)},
      );
      final remote = SyncManifest(
        lastSyncTimestamp: 2,
        items: {'b.txt': item('b.txt', timestamp: 200)},
      );

      final merged = SyncRunner.mergeManifests(local, remote);

      expect(merged.keys, {'a.txt', 'b.txt'});
      expect(merged['a.txt']!.versionTimestamp, 100);
      expect(merged['b.txt']!.versionTimestamp, 200);
    });

    test('newer local timestamp wins over remote', () {
      final local = SyncManifest(
        lastSyncTimestamp: 0,
        items: {'a.txt': item('a.txt', timestamp: 500, hash: 'local')},
      );
      final remote = SyncManifest(
        lastSyncTimestamp: 0,
        items: {'a.txt': item('a.txt', timestamp: 400, hash: 'remote')},
      );

      final merged = SyncRunner.mergeManifests(local, remote);

      expect(merged['a.txt']!.versionTimestamp, 500);
      expect(merged['a.txt']!.versionHash, 'local');
    });

    test('newer remote timestamp wins over local', () {
      final local = SyncManifest(
        lastSyncTimestamp: 0,
        items: {'a.txt': item('a.txt', timestamp: 400, hash: 'local')},
      );
      final remote = SyncManifest(
        lastSyncTimestamp: 0,
        items: {'a.txt': item('a.txt', timestamp: 900, hash: 'remote')},
      );

      final merged = SyncRunner.mergeManifests(local, remote);

      expect(merged['a.txt']!.versionTimestamp, 900);
      expect(merged['a.txt']!.versionHash, 'remote');
    });

    test('equal timestamps keep the local item unchanged', () {
      final local = SyncManifest(
        lastSyncTimestamp: 0,
        items: {'a.txt': item('a.txt', timestamp: 777, hash: 'local-hash')},
      );
      final remote = SyncManifest(
        lastSyncTimestamp: 0,
        items: {'a.txt': item('a.txt', timestamp: 777, hash: 'remote-hash')},
      );

      final merged = SyncRunner.mergeManifests(local, remote);

      expect(merged['a.txt']!.versionTimestamp, 777);
      expect(merged['a.txt']!.versionHash, 'local-hash');
    });

    test('deleted markers and all fields are preserved verbatim', () {
      final local = SyncManifest(
        lastSyncTimestamp: 0,
        items: {
          'gone.txt': item(
            'gone.txt',
            timestamp: 321,
            hash: 'h1',
            isDeleted: true,
          ),
          'local_only.txt': item('local_only.txt', timestamp: 111),
        },
      );
      final remote = SyncManifest(
        lastSyncTimestamp: 0,
        items: {
          'gone.txt': item(
            'gone.txt',
            timestamp: 100,
            hash: 'h-old',
            isDeleted: false,
          ),
          'remote_only.txt': item(
            'remote_only.txt',
            timestamp: 222,
            hash: 'h2',
            isDeleted: true,
          ),
        },
      );

      final merged = SyncRunner.mergeManifests(local, remote);

      // 删除标记项：本地时间戳更大，整体保留本地字段（含 isDeleted=true）
      final gone = merged['gone.txt']!;
      expect(gone.isDeleted, isTrue);
      expect(gone.versionTimestamp, 321);
      expect(gone.versionHash, 'h1');
      expect(gone.filename, 'gone.txt');

      // 远端删除标记项原样保留
      final remoteOnly = merged['remote_only.txt']!;
      expect(remoteOnly.isDeleted, isTrue);
      expect(remoteOnly.versionHash, 'h2');

      // 单边项完整保留
      expect(merged['local_only.txt']!.versionTimestamp, 111);
      expect(merged.length, 3);
    });
  });

  group('SyncRunner.run', () {
    late Directory baseDir;
    late FakeCloudStorageService storage;
    late SyncRunner runner;
    late FakeDiaryService diaryService;
    late FakeMomentService momentService;
    final List<String> notifications = <String>[];

    Future<FakeDiaryService> buildDiaryService() async {
      final service = FakeDiaryService(baseDir);
      await service.init();
      return service;
    }

    Future<void> buildRunner({
      FakeCloudStorageService? storageOverride,
      FakeMomentService? momentOverride,
    }) async {
      storage = storageOverride ?? FakeCloudStorageService();
      momentService = momentOverride ?? FakeMomentService(baseDir);
      await momentService.init();
      notifications.clear();
      runner = SyncRunner(
        storage: storage,
        momentService: momentService,
        scopeCacheStore: SyncScopeCacheStore(
          prefsFactory: () async => await SharedPreferences.getInstance(),
        ),
        progressTracker: SyncProgressTracker(),
        errorClassifier: const SyncErrorClassifier(),
        onNotify: (progress, max, {body, indeterminate = false}) {
          if (body != null) notifications.add(body);
        },
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      baseDir = await Directory.systemTemp.createTemp('sync_runner_test');
    });

    tearDown(() async {
      if (await baseDir.exists()) {
        await baseDir.delete(recursive: true);
      }
    });

    Future<void> writeDiaryFile(String filename, String content) async {
      final file = File(path.join(diaryService.dataDir!.path, filename));
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    }

    test(
      'uploads a new local diary and writes the merged remote manifest',
      () async {
        await buildRunner();
        diaryService = await buildDiaryService();

        const filename = '2026-03-12_new.txt';
        await writeDiaryFile(filename, 'pending diary content');
        diaryService.manifestService.updateItem(
          filename,
          isDeleted: false,
          timestamp: 1234567890,
        );

        final outcome = await runner.run(
          isAuto: true,
          diaryService: diaryService,
        );

        expect(outcome.hasFailures, isFalse);
        expect(outcome.processedDiaries, 1);
        expect(
          storage.uploadedPaths,
          contains('${WebDavSyncService.diaryBasePath}$filename'),
        );

        // 远端 manifest 已包含该条目（时间戳一致）
        final remoteManifest =
            storage.remoteFiles['${WebDavSyncService.rootPath}manifest.json']!;
        final decoded = SyncManifest.fromJson(
          jsonDecode(remoteManifest) as Map<String, dynamic>,
        );
        expect(decoded.items[filename]!.versionTimestamp, 1234567890);
        expect(decoded.items[filename]!.isDeleted, isFalse);
      },
    );

    test(
      'records an upload failure in SyncRunOutcome without aborting',
      () async {
        await buildRunner(
          storageOverride: FakeCloudStorageService(failUploadFor: 'fail.txt'),
        );
        diaryService = await buildDiaryService();

        const filename = '2026-03-12_fail.txt';
        await writeDiaryFile(filename, 'will fail to upload');
        diaryService.manifestService.updateItem(
          filename,
          isDeleted: false,
          timestamp: 555,
        );

        final outcome = await runner.run(
          isAuto: true,
          diaryService: diaryService,
        );

        expect(outcome.failedUploads, 1);
        expect(outcome.errors.single, contains('diary upload'));
        expect(outcome.processedDiaries, 0);
        expect(outcome.hasFailures, isTrue);

        // 上传失败项不得进入写回的远端 manifest
        // （nextRemoteManifest 只在上传成功后 updateItem）
        final written =
            storage.remoteFiles['${WebDavSyncService.rootPath}manifest.json'];
        expect(written, isNotNull);
        final decoded = SyncManifest.fromJson(
          jsonDecode(written!) as Map<String, dynamic>,
        );
        expect(decoded.items.containsKey('2026-03-12_fail.txt'), isFalse);
        expect(decoded.items, isEmpty);
      },
    );

    test('tolerates a remote 404 ghost while syncing a normal item', () async {
      await buildRunner();
      diaryService = await buildDiaryService();

      // 远端 manifest 声称存在 ghost 文件，但远端文件本身缺失 → 下载 404；
      // 同时存在一个本地待上传的正常项，验证 ghost 移除不影响正常项同步。
      const ghostName = '2026-01-01_ghost.txt';
      const goodName = '2026-03-12_good.txt';
      await writeDiaryFile(goodName, 'normal pending diary');
      diaryService.manifestService.updateItem(
        goodName,
        isDeleted: false,
        timestamp: 3000,
      );

      storage.remoteFiles['${WebDavSyncService.rootPath}manifest.json'] =
          jsonEncode(
            SyncManifest(
              lastSyncTimestamp: 0,
              items: {
                ghostName: SyncItem(
                  filename: ghostName,
                  versionHash: '2000',
                  versionTimestamp: 2000,
                ),
              },
            ).toJson(),
          );

      final outcome = await runner.run(
        isAuto: true,
        diaryService: diaryService,
      );

      expect(outcome.hasFailures, isFalse);
      expect(outcome.failedDownloads, 0);
      // ghost 不计数，正常项上传 1 项
      expect(outcome.processedDiaries, 1);

      // 正常项已上传
      expect(
        storage.uploadedPaths,
        contains('${WebDavSyncService.diaryBasePath}$goodName'),
      );

      // 写回的远端 manifest 只保留正常项，ghost 被移除
      final written =
          jsonDecode(
                storage
                    .remoteFiles['${WebDavSyncService.rootPath}manifest.json']!,
              )
              as Map<String, dynamic>;
      final items = written['items'] as Map<String, dynamic>;
      expect(items.containsKey(ghostName), isFalse);
      expect(items.containsKey(goodName), isTrue);
      expect(items.length, 1);
    });

    test('records a non-404 download failure in SyncRunOutcome', () async {
      await buildRunner(
        storageOverride: FakeCloudStorageService(
          failDownloadFor: 'broken.txt',
          downloadError: 'Connection reset by peer',
        ),
      );
      diaryService = await buildDiaryService();

      const filename = '2026-01-01_broken.txt';
      storage.remoteFiles['${WebDavSyncService.rootPath}manifest.json'] =
          jsonEncode(
            SyncManifest(
              lastSyncTimestamp: 0,
              items: {
                filename: SyncItem(
                  filename: filename,
                  versionHash: '3000',
                  versionTimestamp: 3000,
                ),
              },
            ).toJson(),
          );
      storage.remoteFiles['${WebDavSyncService.diaryBasePath}$filename'] =
          'content';

      final outcome = await runner.run(
        isAuto: true,
        diaryService: diaryService,
      );

      expect(outcome.failedDownloads, 1);
      expect(outcome.errors.single, contains('diary download'));
      expect(outcome.hasFailures, isTrue);
    });

    test(
      'archives a deleted diary locally and moves it to remote trash',
      () async {
        await buildRunner();
        diaryService = await buildDiaryService();

        const filename = '2026-03-12_gone.txt';
        await writeDiaryFile(filename, 'to be deleted');
        // 本地标记删除且时间戳较新
        diaryService.manifestService.updateItem(
          filename,
          isDeleted: true,
          timestamp: 5000,
        );
        // 远端仍保留未删除版本
        storage.remoteFiles['${WebDavSyncService.rootPath}manifest.json'] =
            jsonEncode(
              SyncManifest(
                lastSyncTimestamp: 0,
                items: {
                  filename: SyncItem(
                    filename: filename,
                    versionHash: '4000',
                    versionTimestamp: 4000,
                  ),
                },
              ).toJson(),
            );
        storage.remoteFiles['${WebDavSyncService.diaryBasePath}$filename'] =
            'old remote content';

        final outcome = await runner.run(
          isAuto: true,
          diaryService: diaryService,
        );

        expect(outcome.hasFailures, isFalse);
        expect(outcome.processedDiaries, 2);

        // 远端文件被移动到回收站路径
        expect(
          storage.movedFrom,
          contains('${WebDavSyncService.diaryBasePath}$filename'),
        );
        expect(
          storage.movedTo,
          contains('${WebDavSyncService.trashBasePath}$filename'),
        );

        // 本地文件已归档（离开 diary_data）
        expect(
          await File(path.join(diaryService.dataDir!.path, filename)).exists(),
          isFalse,
        );

        // 写回的远端 manifest 标记该条目已删除
        final decoded = SyncManifest.fromJson(
          jsonDecode(
                storage
                    .remoteFiles['${WebDavSyncService.rootPath}manifest.json']!,
              )
              as Map<String, dynamic>,
        );
        expect(decoded.items[filename]!.isDeleted, isTrue);
        expect(decoded.items[filename]!.versionTimestamp, 5000);
      },
    );

    test('missing diary provider is reported as a delete failure', () async {
      await buildRunner();

      final outcome = await runner.run(isAuto: true);

      expect(outcome.failedDeletes, 1);
      expect(outcome.errors.single, 'DiaryProvider not initialized');
      expect(outcome.hasFailures, isTrue);
    });

    test(
      'uploads a new local moment json and writes the merged remote manifest',
      () async {
        await buildRunner();
        diaryService = await buildDiaryService();

        const filename = 'moment_u1.json';
        await File(
          path.join(momentService.dataDir!.path, filename),
        ).writeAsString('{"uuid":"u1","content":"hi"}');
        momentService.manifestService.updateItem(
          filename,
          isDeleted: false,
          timestamp: 1234567890,
        );

        final outcome = await runner.run(
          isAuto: true,
          diaryService: diaryService,
        );

        expect(outcome.hasFailures, isFalse);
        expect(outcome.processedMoments, 1);
        expect(
          storage.uploadedPaths,
          contains('${WebDavSyncService.momentsBasePath}$filename'),
        );

        // 远端 moments_manifest 已包含该条目（时间戳一致）
        final remoteManifest = storage
            .remoteFiles['${WebDavSyncService.rootPath}moments_manifest.json']!;
        final decoded = SyncManifest.fromJson(
          jsonDecode(remoteManifest) as Map<String, dynamic>,
        );
        expect(decoded.items[filename]!.versionTimestamp, 1234567890);
        expect(decoded.items[filename]!.isDeleted, isFalse);
      },
    );

    test('downloads a remote moment json missing locally', () async {
      await buildRunner();
      diaryService = await buildDiaryService();

      const filename = 'moment_remote.json';
      storage.remoteFiles['${WebDavSyncService.rootPath}moments_manifest.json'] =
          jsonEncode(
            SyncManifest(
              lastSyncTimestamp: 0,
              items: {
                filename: SyncItem(
                  filename: filename,
                  versionHash: '900',
                  versionTimestamp: 900,
                ),
              },
            ).toJson(),
          );
      storage.remoteFiles['${WebDavSyncService.momentsBasePath}$filename'] =
          '{"uuid":"remote"}';

      final outcome = await runner.run(
        isAuto: true,
        diaryService: diaryService,
      );

      expect(outcome.hasFailures, isFalse);
      expect(outcome.processedMoments, 1);
      expect(
        storage.downloadedPaths,
        contains('${WebDavSyncService.momentsBasePath}$filename'),
      );

      // 本地文件已落地，写回的远端 manifest 保留该条目
      expect(
        await File(path.join(momentService.dataDir!.path, filename)).exists(),
        isTrue,
      );
      final decoded = SyncManifest.fromJson(
        jsonDecode(
              storage
                  .remoteFiles['${WebDavSyncService.rootPath}moments_manifest.json']!,
            )
            as Map<String, dynamic>,
      );
      expect(decoded.items[filename]!.versionTimestamp, 900);
    });

    test('tolerates a moment json ghost while syncing a normal item', () async {
      await buildRunner();
      diaryService = await buildDiaryService();

      const ghostName = 'moment_ghost.json';
      const goodName = 'moment_good.json';
      await File(
        path.join(momentService.dataDir!.path, goodName),
      ).writeAsString('{"uuid":"good"}');
      momentService.manifestService.updateItem(
        goodName,
        isDeleted: false,
        timestamp: 3000,
      );

      storage.remoteFiles['${WebDavSyncService.rootPath}moments_manifest.json'] =
          jsonEncode(
            SyncManifest(
              lastSyncTimestamp: 0,
              items: {
                ghostName: SyncItem(
                  filename: ghostName,
                  versionHash: '2000',
                  versionTimestamp: 2000,
                ),
              },
            ).toJson(),
          );

      final outcome = await runner.run(
        isAuto: true,
        diaryService: diaryService,
      );

      expect(outcome.hasFailures, isFalse);
      expect(outcome.failedDownloads, 0);
      expect(outcome.processedMoments, 1);

      // 正常项已上传，ghost 不产生任何远端副作用
      expect(
        storage.uploadedPaths,
        contains('${WebDavSyncService.momentsBasePath}$goodName'),
      );
      expect(storage.deletedPaths, isEmpty);

      // 写回的远端 manifest 只保留正常项，ghost 被移除
      final written =
          jsonDecode(
                storage
                    .remoteFiles['${WebDavSyncService.rootPath}moments_manifest.json']!,
              )
              as Map<String, dynamic>;
      final items = written['items'] as Map<String, dynamic>;
      expect(items.containsKey(ghostName), isFalse);
      expect(items.containsKey(goodName), isTrue);
      expect(items.length, 1);
    });

    test(
      'archives a deleted moment json locally and moves it to remote trash',
      () async {
        await buildRunner();
        diaryService = await buildDiaryService();

        const filename = 'moment_gone.json';
        await File(
          path.join(momentService.dataDir!.path, filename),
        ).writeAsString('{"uuid":"gone"}');
        // 本地标记删除且时间戳较新
        momentService.manifestService.updateItem(
          filename,
          isDeleted: true,
          timestamp: 5000,
        );
        // 远端仍保留未删除版本
        storage.remoteFiles['${WebDavSyncService.rootPath}moments_manifest.json'] =
            jsonEncode(
              SyncManifest(
                lastSyncTimestamp: 0,
                items: {
                  filename: SyncItem(
                    filename: filename,
                    versionHash: '4000',
                    versionTimestamp: 4000,
                  ),
                },
              ).toJson(),
            );
        storage.remoteFiles['${WebDavSyncService.momentsBasePath}$filename'] =
            'old remote content';

        final outcome = await runner.run(
          isAuto: true,
          diaryService: diaryService,
        );

        expect(outcome.hasFailures, isFalse);
        expect(outcome.processedMoments, 2);

        // 本地归档走 archiveMomentByFilename：记录调用 + 文件移出 moments_data
        expect(momentService.archivedFilenames, contains(filename));
        expect(
          await File(path.join(momentService.dataDir!.path, filename)).exists(),
          isFalse,
        );

        // 远端文件被移动到回收站路径
        expect(
          storage.movedFrom,
          contains('${WebDavSyncService.momentsBasePath}$filename'),
        );
        expect(
          storage.movedTo,
          contains('${WebDavSyncService.trashBasePath}moments_$filename'),
        );

        // 写回的远端 manifest 标记该条目已删除
        final decoded = SyncManifest.fromJson(
          jsonDecode(
                storage
                    .remoteFiles['${WebDavSyncService.rootPath}moments_manifest.json']!,
              )
              as Map<String, dynamic>,
        );
        expect(decoded.items[filename]!.isDeleted, isTrue);
        expect(decoded.items[filename]!.versionTimestamp, 5000);
      },
    );

    test('auto sync skips image upload batches larger than 20', () async {
      final images = <String>{for (var i = 0; i < 21; i++) 'img_$i.jpg'};
      final fakeMoments = FakeMomentService(baseDir, referencedImages: images);
      await fakeMoments.init();
      for (var i = 0; i < 21; i++) {
        final file = File(path.join(fakeMoments.imagesDir!.path, 'img_$i.jpg'));
        await file.writeAsString('img-$i');
      }

      await buildRunner(momentOverride: fakeMoments);
      diaryService = await buildDiaryService();

      final outcome = await runner.run(
        isAuto: true,
        diaryService: diaryService,
      );

      expect(outcome.skippedOperations, 21);
      expect(outcome.processedImages, 0);
      expect(outcome.hasFailures, isFalse);
      // 流量保护在 safety check 处提前返回，不产生任何上传
      expect(storage.uploadedPaths, isEmpty);
    });

    test(
      'auto sync uploads exactly 20 images without traffic protection',
      () async {
        // 边界：toUpload 恰好 20（> 20 才触发保护），应全部真实上传
        final images = <String>{for (var i = 0; i < 20; i++) 'img_$i.jpg'};
        final fakeMoments = FakeMomentService(
          baseDir,
          referencedImages: images,
        );
        await fakeMoments.init();
        for (var i = 0; i < 20; i++) {
          final file = File(
            path.join(fakeMoments.imagesDir!.path, 'img_$i.jpg'),
          );
          await file.writeAsString('img-$i');
        }

        await buildRunner(momentOverride: fakeMoments);
        diaryService = await buildDiaryService();

        final outcome = await runner.run(
          isAuto: true,
          diaryService: diaryService,
        );

        expect(outcome.skippedOperations, 0);
        expect(outcome.processedImages, 20);
        expect(outcome.hasFailures, isFalse);
        expect(storage.uploadedPaths.length, 20);
        expect(
          storage.uploadedPaths,
          contains('${WebDavSyncService.momentsImagesPath}img_0.jpg'),
        );
      },
    );

    test('auto sync skips audio upload batches larger than 20', () async {
      final fakeMoments = FakeMomentService(baseDir);
      await fakeMoments.init();
      for (var i = 0; i < 21; i++) {
        final file = File(path.join(fakeMoments.audioDir!.path, 'rec_$i.m4a'));
        await file.writeAsString('audio-$i');
      }

      await buildRunner(momentOverride: fakeMoments);
      diaryService = await buildDiaryService();

      final outcome = await runner.run(
        isAuto: true,
        diaryService: diaryService,
      );

      expect(outcome.skippedOperations, 21);
      expect(outcome.processedAudio, 0);
      expect(outcome.hasFailures, isFalse);
    });

    test(
      'cleans up orphan images on both sides and uploads valid ones',
      () async {
        final fakeMoments = FakeMomentService(
          baseDir,
          referencedImages: const <String>{'keep.jpg'},
        );
        await fakeMoments.init();
        // 本地：被引用的 keep.jpg + 孤儿 orphan_local.jpg
        await File(
          path.join(fakeMoments.imagesDir!.path, 'keep.jpg'),
        ).writeAsString('keep');
        await File(
          path.join(fakeMoments.imagesDir!.path, 'orphan_local.jpg'),
        ).writeAsString('orphan');
        // 远端：孤儿 orphan_remote.jpg（必须通过 storageOverride 传入，
        // 否则 buildRunner 会重建空 storage 覆盖预置内容）
        storage = FakeCloudStorageService();
        storage.remoteFiles['${WebDavSyncService.momentsImagesPath}orphan_remote.jpg'] =
            'remote orphan';

        await buildRunner(
          storageOverride: storage,
          momentOverride: fakeMoments,
        );
        diaryService = await buildDiaryService();

        final outcome = await runner.run(
          isAuto: true,
          diaryService: diaryService,
        );

        expect(outcome.hasFailures, isFalse);
        expect(outcome.processedImages, 3);

        // 远端孤儿被删除
        expect(
          storage.deletedPaths,
          contains('${WebDavSyncService.momentsImagesPath}orphan_remote.jpg'),
        );
        // 本地孤儿被删除，被引用图片保留并上传
        expect(
          await File(
            path.join(fakeMoments.imagesDir!.path, 'orphan_local.jpg'),
          ).exists(),
          isFalse,
        );
        expect(
          await File(
            path.join(fakeMoments.imagesDir!.path, 'keep.jpg'),
          ).exists(),
          isTrue,
        );
        expect(
          storage.uploadedPaths,
          contains('${WebDavSyncService.momentsImagesPath}keep.jpg'),
        );
      },
    );

    test('manual sync emits progress notifications', () async {
      await buildRunner();
      diaryService = await buildDiaryService();

      const filename = '2026-03-12_notify.txt';
      await writeDiaryFile(filename, 'notify me');
      diaryService.manifestService.updateItem(
        filename,
        isDeleted: false,
        timestamp: 100,
      );

      await runner.run(isAuto: false, diaryService: diaryService);

      expect(notifications, isNotEmpty);
      expect(notifications, contains('开始同步 1 个变更...'));
    });
  });
}
