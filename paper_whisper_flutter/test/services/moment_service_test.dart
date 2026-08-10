import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:paper_whisper_flutter/features/diary/data/diary_entry.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment.dart';
import 'package:paper_whisper_flutter/models/trash_record.dart';
import 'package:paper_whisper_flutter/features/diary/data/diary_service.dart';
import 'package:paper_whisper_flutter/features/sync/data/manifest_service.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment_service.dart';

void main() {
  group('MomentService', () {
    late Directory rootDir;
    late Directory dataDir;
    late MomentService service;

    setUp(() async {
      rootDir = await Directory.systemTemp.createTemp('moment_service_test');
      dataDir = Directory(path.join(rootDir.path, 'moments_data'));
      service = MomentService(debugDataDir: dataDir);
      await service.init();
    });

    tearDown(() async {
      if (await rootDir.exists()) {
        await rootDir.delete(recursive: true);
      }
    });

    test(
      'deleteMoment archives json and media instead of hard deleting',
      () async {
        final imageFile = File(path.join(service.imagesDir!.path, 'demo.jpg'));
        await imageFile.create(recursive: true);
        await imageFile.writeAsString('image-bytes');

        final audioFile = File(path.join(service.audioDir!.path, 'demo.m4a'));
        await audioFile.create(recursive: true);
        await audioFile.writeAsString('audio-bytes');

        final moment = Moment(
          uuid: 'demo',
          content: '今天把删除改成可恢复了',
          images: const <String>['images/demo.jpg'],
          createdAt: DateTime(2026, 3, 12, 9, 30),
          audioPath: 'audio/demo.m4a',
          audioTitle: '测试语音',
          audioDuration: 12,
        );

        await service.saveMoment(moment);
        final filename = 'moment_${moment.uuid}.json';
        final jsonFile = File(path.join(dataDir.path, filename));
        expect(await jsonFile.exists(), isTrue);

        await service.deleteMoment(moment.uuid);

        expect(await service.trashService.hasRecord(filename), isTrue);
        expect(await jsonFile.exists(), isFalse);
        expect(await imageFile.exists(), isFalse);
        expect(await audioFile.exists(), isFalse);

        final record = (await service.trashService.listRecords(
          type: TrashRecordType.moment,
        )).single;
        expect(
          record.relatedFiles,
          containsAll(<String>['images/demo.jpg', 'audio/demo.m4a']),
        );
        expect(record.previewText, contains('删除改成可恢复'));

        final manifestItem = service.manifestService.manifest.items[filename];
        expect(manifestItem, isNotNull);
        expect(manifestItem!.isDeleted, isTrue);
      },
    );

    test(
      'saveMoment registers manifest item and media references, surviving restart',
      () async {
        final imageFile = File(path.join(service.imagesDir!.path, 'demo.jpg'));
        await imageFile.create(recursive: true);
        await imageFile.writeAsString('image-bytes');

        final audioFile = File(path.join(service.audioDir!.path, 'demo.m4a'));
        await audioFile.create(recursive: true);
        await audioFile.writeAsString('audio-bytes');

        final moment = Moment(
          uuid: 'manifest-save',
          content: '保存后应登记到 manifest',
          images: const <String>['images/demo.jpg'],
          createdAt: DateTime(2026, 3, 12, 10, 30),
          audioPath: 'audio/demo.m4a',
          audioTitle: '测试语音',
          audioDuration: 8,
        );

        await service.saveMoment(moment);

        final filename = 'moment_${moment.uuid}.json';
        final jsonFile = File(path.join(dataDir.path, filename));
        expect(await jsonFile.exists(), isTrue);

        // Manifest 登记：未删除、带版本时间戳
        final item = service.manifestService.manifest.items[filename];
        expect(item, isNotNull);
        expect(item!.isDeleted, isFalse);
        expect(item.versionTimestamp, greaterThan(0));

        // 媒体引用：图片被登记为有效引用，文件存在
        final referenced = await service.getAllReferencedImages();
        expect(referenced, contains('demo.jpg'));
        expect(await imageFile.exists(), isTrue);
        expect(await audioFile.exists(), isTrue);

        // 重启（重新 init）后 manifest 从磁盘恢复，登记仍在
        service.reset();
        await service.init();
        final reloadedItem = service.manifestService.manifest.items[filename];
        expect(reloadedItem, isNotNull);
        expect(reloadedItem!.isDeleted, isFalse);
        expect(await service.getAllReferencedImages(), contains('demo.jpg'));
      },
    );

    test(
      'archiveMomentByFilename keeps provided tombstone timestamp',
      () async {
        final moment = Moment(
          uuid: 'remote-delete',
          content: '来自远端的删除也应该可恢复',
          images: const <String>[],
          createdAt: DateTime(2026, 3, 12, 11, 0),
        );

        await service.saveMoment(moment);
        final filename = 'moment_${moment.uuid}.json';

        await service.archiveMomentByFilename(filename, manifestTimestamp: 42);

        final manifestItem = service.manifestService.manifest.items[filename];
        expect(manifestItem, isNotNull);
        expect(manifestItem!.isDeleted, isTrue);
        expect(manifestItem.versionTimestamp, 42);
        expect(await service.trashService.hasRecord(filename), isTrue);
      },
    );

    test(
      'exportDailySummary writes through the injected DiaryService instance',
      () async {
        final diaryService = RecordingDiaryService(rootDir);
        await diaryService.init();

        final exporting = MomentService(
          debugDataDir: dataDir,
          diaryService: diaryService,
        );
        await exporting.init();

        await exporting.saveMoment(
          Moment(
            uuid: 'summary-day',
            content: '今天心情不错',
            images: const <String>[],
            createdAt: DateTime(2026, 3, 12, 9, 0),
          ),
        );
        await exporting.saveMoment(
          Moment(
            uuid: 'other-day',
            content: '不该出现在今天的聚合里',
            images: const <String>[],
            createdAt: DateTime(2026, 3, 13, 9, 0),
          ),
        );

        final filename = await exporting.exportDailySummary(
          DateTime(2026, 3, 12),
        );

        // 固定文件名允许覆盖
        expect(filename, '2026-03-12_moments_summary.txt');
        // 写入发生在注入的共享 DiaryService 上（若仍局部 new 则此处为空）
        expect(diaryService.savedEntries, hasLength(1));
        final entry = diaryService.savedEntries.single;
        expect(entry.title, '2026年3月12日 随心记聚合');
        expect(entry.content, contains('今天心情不错'));
        expect(entry.content, isNot(contains('不该出现在今天的聚合里')));
        // 共享 DiaryService 的 manifest 同步登记（无独立实例状态分歧）
        final item = diaryService
            .manifestService
            .manifest
            .items['2026-03-12_moments_summary.txt'];
        expect(item, isNotNull);
        expect(item!.isDeleted, isFalse);
      },
    );

    test(
      'exportDailySummary returns null without an injected DiaryService',
      () async {
        final standalone = MomentService(debugDataDir: dataDir);
        await standalone.init();
        await standalone.saveMoment(
          Moment(
            uuid: 'no-diary',
            content: '没有注入 DiaryService',
            images: const <String>[],
            createdAt: DateTime(2026, 3, 12, 9, 0),
          ),
        );

        final result = await standalone.exportDailySummary(
          DateTime(2026, 3, 12),
        );

        expect(result, isNull, reason: '未注入共享 DiaryService 时聚合导出应安全跳过');
      },
    );
  });
}

/// 完整公开 fake：覆写 [DiaryService] 全部相关公开操作，不依赖父类私有字段。
/// 用于验证 [MomentService.exportDailySummary] 把日记写入路由到注入实例。
class RecordingDiaryService extends DiaryService {
  RecordingDiaryService(this.rootDir);

  final Directory rootDir;
  final List<DiaryEntry> savedEntries = <DiaryEntry>[];
  final ManifestService _manifestService = ManifestService();
  Directory? _base;
  bool _initialized = false;

  @override
  Directory? get dataDir => _base;

  @override
  String get currentDataPath => _base?.path ?? 'Unknown';

  @override
  ManifestService get manifestService => _manifestService;

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
    _initialized = true;
  }

  @override
  Future<String> saveEntry(DiaryEntry entry) async {
    savedEntries.add(entry);
    final file = File(path.join(_base!.path, entry.filename));
    await file.writeAsString(entry.toFileContent());
    await _manifestService.updateItem(entry.filename, isDeleted: false);
    return entry.filename;
  }

  @override
  Future<List<DiaryEntry>> getEntries() async => <DiaryEntry>[];

  @override
  Future<void> saveCache(List<DiaryEntry> entries) async {}

  @override
  Future<List<DiaryEntry>?> loadCache() async => null;
}
