import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:paper_whisper_flutter/services/manifest_service.dart';

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

    test('ensureConsistency revives deleted entry when local file exists', () async {
      const filename = '2026-03-12_b.txt';
      final file = File(path.join(dataDir.path, filename));
      await file.writeAsString('still here');

      service.updateItem(filename, isDeleted: true, timestamp: 1);

      await service.ensureConsistency(dataDir);

      final item = service.manifest.items[filename];
      expect(item, isNotNull);
      expect(item!.isDeleted, isFalse);
      expect(item.versionTimestamp, greaterThan(1));
    });
  });
}
