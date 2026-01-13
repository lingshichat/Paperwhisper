import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'manifest_service.dart';

class TrashService {
  Directory? _trashDir;
  
  // Init with the main data directory. Trash will be sibling: 'trash_data'
  Future<void> init(Directory dataDir) async {
    final parentDir = dataDir.parent;
    _trashDir = Directory(path.join(parentDir.path, 'trash_data'));
    if (!await _trashDir!.exists()) {
      await _trashDir!.create(recursive: true);
    }
  }
  
  Directory? get trashDir => _trashDir;

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
      return _trashDir!.list().where((e) => e is File && e.path.endsWith('.txt')).cast<File>().toList();
    } catch (e) {
      return [];
    }
  }
}
