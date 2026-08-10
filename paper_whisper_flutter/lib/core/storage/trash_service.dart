import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:paper_whisper_flutter/core/storage/trash_record.dart';

class TrashService {
  Directory? _trashDir;
  Directory? _recordsDir;

  // Init with the main data directory. Trash will be sibling: 'trash_data'
  Future<void> init(Directory dataDir) async {
    final parentDir = dataDir.parent;
    _trashDir = Directory(path.join(parentDir.path, 'trash_data'));
    if (!await _trashDir!.exists()) {
      await _trashDir!.create(recursive: true);
    }
    _recordsDir = Directory(path.join(_trashDir!.path, 'records'));
    if (!await _recordsDir!.exists()) {
      await _recordsDir!.create(recursive: true);
    }
  }

  Directory? get trashDir => _trashDir;
  Directory? get recordsDir => _recordsDir;

  String _recordPath(String primaryFilename) {
    final recordName = '${path.basenameWithoutExtension(primaryFilename)}.json';
    return path.join(_recordsDir!.path, recordName);
  }

  String _bundlePath(String primaryFilename) {
    return path.join(
      _trashDir!.path,
      path.basenameWithoutExtension(primaryFilename),
    );
  }

  Future<void> moveToTrash(File file) async {
    if (_trashDir == null) return;
    try {
      final filename = path.basename(file.path);
      final targetPath = path.join(_trashDir!.path, filename);
      await file.rename(targetPath); // Move
      debugPrint("Moved to trash: $filename");
    } catch (e) {
      debugPrint("Trash error: $e");
      // If rename fails (cross-device?), try copy-delete
      try {
        final filename = path.basename(file.path);
        final targetPath = path.join(_trashDir!.path, filename);
        await file.copy(targetPath);
        await file.delete();
      } catch (e2) {
        debugPrint("Trash copy-delete failed: $e2");
        rethrow;
      }
    }
  }

  Future<void> restoreFromTrash(String filename, Directory targetDir) async {
    if (_trashDir == null) return;
    final trashFile = File(path.join(_trashDir!.path, filename));
    if (!await trashFile.exists()) return; // Already gone?

    final targetPath = path.join(targetDir.path, filename);
    await trashFile.rename(targetPath);
  }

  Future<void> deletePermanently(String filename) async {
    if (_trashDir == null) return;
    final trashFile = File(path.join(_trashDir!.path, filename));
    if (await trashFile.exists()) {
      await trashFile.delete();
    }
  }

  Future<List<File>> listValidTrashFiles() async {
    if (_trashDir == null) return [];
    try {
      return _trashDir!
          .list()
          .where((e) => e is File && e.path.endsWith('.txt'))
          .cast<File>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> archiveRecord({
    required TrashRecord record,
    required File primaryFile,
    required Map<String, File> relatedFiles,
  }) async {
    if (_trashDir == null || _recordsDir == null) return;

    final bundleDir = Directory(_bundlePath(record.primaryFilename));
    await bundleDir.create(recursive: true);

    final primaryTarget = File(
      path.join(bundleDir.path, record.primaryFilename),
    );
    await _moveFile(primaryFile, primaryTarget);

    for (final entry in relatedFiles.entries) {
      final target = File(path.join(bundleDir.path, entry.key));
      await _moveFile(entry.value, target);
    }

    final recordFile = File(_recordPath(record.primaryFilename));
    await recordFile.writeAsString(jsonEncode(record.toJson()));
  }

  Future<void> restoreRecord(TrashRecord record, Directory targetDir) async {
    if (_trashDir == null || _recordsDir == null) return;

    final bundleDir = Directory(_bundlePath(record.primaryFilename));
    final primarySource = File(
      path.join(bundleDir.path, record.primaryFilename),
    );
    if (await primarySource.exists()) {
      await _moveFile(
        primarySource,
        File(path.join(targetDir.path, record.primaryFilename)),
      );
    }

    for (final relativePath in record.relatedFiles) {
      final source = File(path.join(bundleDir.path, relativePath));
      if (!await source.exists()) {
        continue;
      }
      await _moveFile(source, File(path.join(targetDir.path, relativePath)));
    }

    final recordFile = File(_recordPath(record.primaryFilename));
    if (await recordFile.exists()) {
      await recordFile.delete();
    }
    if (await bundleDir.exists()) {
      await bundleDir.delete(recursive: true);
    }
  }

  Future<void> deleteRecordPermanently(TrashRecord record) async {
    if (_trashDir == null || _recordsDir == null) return;

    final bundleDir = Directory(_bundlePath(record.primaryFilename));
    if (await bundleDir.exists()) {
      await bundleDir.delete(recursive: true);
    }

    final recordFile = File(_recordPath(record.primaryFilename));
    if (await recordFile.exists()) {
      await recordFile.delete();
    }
  }

  Future<List<TrashRecord>> listRecords({TrashRecordType? type}) async {
    if (_recordsDir == null || !await _recordsDir!.exists()) {
      return <TrashRecord>[];
    }

    final List<TrashRecord> records = <TrashRecord>[];
    for (final entity in _recordsDir!.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) {
        continue;
      }

      try {
        final record = TrashRecord.fromJson(
          jsonDecode(await entity.readAsString()) as Map<String, dynamic>,
        );
        if (type == null || record.type == type) {
          records.add(record);
        }
      } catch (e) {
        debugPrint('Trash record parse failed: $e');
      }
    }

    return records;
  }

  Future<bool> hasRecord(String primaryFilename) async {
    if (_recordsDir == null) {
      return false;
    }
    return File(_recordPath(primaryFilename)).exists();
  }

  Future<void> _moveFile(File source, File target) async {
    await target.parent.create(recursive: true);
    try {
      await source.rename(target.path);
    } catch (_) {
      await source.copy(target.path);
      await source.delete();
    }
  }
}
