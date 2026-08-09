import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:paper_whisper_flutter/models/moment.dart';
import 'package:paper_whisper_flutter/models/trash_record.dart';
import 'package:paper_whisper_flutter/services/moment_service.dart';

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
  });
}
