import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:paper_whisper_flutter/core/storage/trash_record.dart';
import 'package:paper_whisper_flutter/core/storage/trash_service.dart';

void main() {
  group('TrashService', () {
    late Directory rootDir;
    late Directory dataDir;
    late TrashService trashService;

    setUp(() async {
      rootDir = await Directory.systemTemp.createTemp('trash_service_test');
      dataDir = Directory(path.join(rootDir.path, 'moments_data'));
      await dataDir.create(recursive: true);
      trashService = TrashService();
      await trashService.init(dataDir);
    });

    tearDown(() async {
      if (await rootDir.exists()) {
        await rootDir.delete(recursive: true);
      }
    });

    test(
      'archive and restore record moves primary and related files together',
      () async {
        final primaryFile = File(path.join(dataDir.path, 'moment_demo.json'));
        await primaryFile.create(recursive: true);
        await primaryFile.writeAsString('{"uuid":"demo"}');

        final imageFile = File(path.join(dataDir.path, 'images', 'demo.jpg'));
        await imageFile.create(recursive: true);
        await imageFile.writeAsString('image-bytes');

        final audioFile = File(path.join(dataDir.path, 'audio', 'demo.m4a'));
        await audioFile.create(recursive: true);
        await audioFile.writeAsString('audio-bytes');

        final record = TrashRecord(
          type: TrashRecordType.moment,
          primaryFilename: 'moment_demo.json',
          relatedFiles: <String>['images/demo.jpg', 'audio/demo.m4a'],
          deletedAt: DateTime(2026, 3, 12, 10, 30),
          title: '随心记',
          previewText: '测试归档',
        );

        await trashService.archiveRecord(
          record: record,
          primaryFile: primaryFile,
          relatedFiles: <String, File>{
            'images/demo.jpg': imageFile,
            'audio/demo.m4a': audioFile,
          },
        );

        expect(await primaryFile.exists(), isFalse);
        expect(await imageFile.exists(), isFalse);
        expect(await audioFile.exists(), isFalse);
        expect(await trashService.hasRecord('moment_demo.json'), isTrue);

        final records = await trashService.listRecords(
          type: TrashRecordType.moment,
        );
        expect(records, hasLength(1));
        expect(
          records.single.relatedFiles,
          containsAll(<String>['images/demo.jpg', 'audio/demo.m4a']),
        );

        await trashService.restoreRecord(records.single, dataDir);

        expect(await primaryFile.exists(), isTrue);
        expect(await imageFile.exists(), isTrue);
        expect(await audioFile.exists(), isTrue);
        expect(await trashService.hasRecord('moment_demo.json'), isFalse);
      },
    );

    test('deleteRecordPermanently removes bundle and metadata', () async {
      final primaryFile = File(path.join(dataDir.path, 'moment_demo.json'));
      await primaryFile.create(recursive: true);
      await primaryFile.writeAsString('{"uuid":"demo"}');

      final record = TrashRecord(
        type: TrashRecordType.moment,
        primaryFilename: 'moment_demo.json',
        relatedFiles: const <String>[],
        deletedAt: DateTime(2026, 3, 12, 10, 30),
      );

      await trashService.archiveRecord(
        record: record,
        primaryFile: primaryFile,
        relatedFiles: const <String, File>{},
      );

      final records = await trashService.listRecords(
        type: TrashRecordType.moment,
      );
      expect(records, hasLength(1));

      await trashService.deleteRecordPermanently(records.single);

      expect(await trashService.hasRecord('moment_demo.json'), isFalse);
      final bundleDir = Directory(
        path.join(trashService.trashDir!.path, 'moment_demo'),
      );
      expect(await bundleDir.exists(), isFalse);
    });
  });
}
