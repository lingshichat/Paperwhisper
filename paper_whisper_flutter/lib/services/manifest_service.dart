import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../models/sync_manifest.dart';

class ManifestService {
  File? _manifestFile;
  SyncManifest? _cachedManifest;

  Future<void> init(Directory dataDir, {String manifestFileName = 'local_manifest.json'}) async {
    // Manifest is stored in the same parent directory as diary_data usually, or inside it?
    // Storing it INSIDE diary_data might be confusing if user syncs files manually.
    // Better store it in the parent 'PaperWhisper' directory.
    
    final parentDir = dataDir.parent;
    if (!await parentDir.exists()) {
       await parentDir.create(recursive: true);
    }
    _manifestFile = File(path.join(parentDir.path, manifestFileName));
    await _load();
  }
  
  Future<void> _load() async {
    if (_manifestFile == null) return;
    if (await _manifestFile!.exists()) {
      try {
        final content = await _manifestFile!.readAsString();
        if (content.isEmpty) {
          _cachedManifest = SyncManifest(lastSyncTimestamp: 0, items: {});
          return;
        }
        final json = jsonDecode(content);
        _cachedManifest = SyncManifest.fromJson(json);
      } catch (e) {
        debugPrint("Error loading manifest: $e");
        _cachedManifest = SyncManifest(lastSyncTimestamp: 0, items: {});
      }
    } else {
      _cachedManifest = SyncManifest(lastSyncTimestamp: 0, items: {});
    }
  }

  Future<void> save() async {
    if (_manifestFile == null || _cachedManifest == null) return;
    try {
      await _manifestFile!.writeAsString(jsonEncode(_cachedManifest!.toJson()));
    } catch (e) {
      debugPrint("Error saving manifest: $e");
    }
  }
  
  SyncManifest get manifest => _cachedManifest ?? SyncManifest(lastSyncTimestamp: 0, items: {});
  
  void updateItem(String filename, {required bool isDeleted, int? timestamp}) {
    if (_cachedManifest == null) return;
    
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    // Simple hash: just use timestamp for now or we could calculate md5 if needed. 
    // Ideally we want content hash but for now timestamp versioning is okay for single user.
    final hash = ts.toString(); 

    _cachedManifest!.updateItem(SyncItem(
      filename: filename,
      versionHash: hash,
      versionTimestamp: ts,
      isDeleted: isDeleted,
    ));
    
    save(); // Auto save
  }

  void removeItem(String filename) {
    if (_cachedManifest == null) return;
    _cachedManifest!.items.remove(filename);
    save();
  }

  /// Ensure manifest matches disk content (Migration/Recovery)
  Future<void> ensureConsistency(Directory dataDir, {String fileExtension = '.txt'}) async {
     if (_cachedManifest == null) return;
     if (!await dataDir.exists()) return;
     
     final List<FileSystemEntity> files = dataDir.listSync();
     bool changed = false;
     
     for (var f in files) {
        if (f is File && path.extension(f.path) == fileExtension) {
           final filename = path.basename(f.path);
           final item = _cachedManifest!.items[filename];
           
           // If untracked or marked deleted but exists -> Update manifest
           if (item == null || item.isDeleted) {
              final ts = await f.lastModified();
              final timestamp = ts.millisecondsSinceEpoch;
              
              _cachedManifest!.updateItem(SyncItem(
                filename: filename,
                versionHash: timestamp.toString(),
                versionTimestamp: timestamp,
                isDeleted: false,
              ));
              changed = true;
              debugPrint("Manifest Migration: Adopted $filename");
           }
        }
     }
     
     if (changed) await save();
  }
  
  // Clean up manifest (e.g. remove items that are permanently deleted and synced?)
  // For now keep history.
}
