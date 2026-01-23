import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/diary_entry.dart';
import 'manifest_service.dart';
import 'trash_service.dart';
import 'package:permission_handler/permission_handler.dart';

class DiaryService {
  Directory? _dataDir;
  final Uuid _uuid = const Uuid();
  
  final ManifestService _manifestService = ManifestService();
  final TrashService _trashService = TrashService();
  
  ManifestService get manifestService => _manifestService;
  TrashService get trashService => _trashService;

  // 获取数据目录路径，供 UI 显示调试用
  String get currentDataPath => _dataDir?.path ?? 'Unknown';
  Directory? get dataDir => _dataDir;

  void reset() {
    _dataDir = null;
  }

  Future<void> init() async {
    if (_dataDir != null) return;

    if (Platform.isWindows) {
      // 1. Windows: 优先使用文档目录 (Standard Mode)，不再根据 Dev/Portable 随意切换，保证数据位置唯一
      final docDir = await getApplicationDocumentsDirectory();
      _dataDir = Directory(path.join(docDir.path, 'PaperWhisper', 'diary_data'));
      
      // 旧版/便携版兼容检查 (Optional: 如果发现标准目录为空但旧目录有数据，可以考虑迁移，但为了避免混乱，暂时只打印 Log)
      String exeDir = path.dirname(Platform.resolvedExecutable);
      Directory portableDir = Directory(path.join(exeDir, 'diary_data'));
      if (await portableDir.exists()) {
         debugPrint("Found Portable Data: ${portableDir.path} (Using Standard Path instead: ${_dataDir!.path})");
      }
    } else if (Platform.isAndroid) {
      // Android: 权限检查移交 UI 层，这里只做路径决策和迁移
      var status = await Permission.manageExternalStorage.status;
      
      // 检查旧版存储权限
      bool hasLegacyStorage = false;
      if (!status.isGranted) {
         var storageStatus = await Permission.storage.status;
         hasLegacyStorage = storageStatus.isGranted;
      }
      
      final bool canUsePublic = status.isGranted || hasLegacyStorage;
      
      if (canUsePublic) {
         // 有权限：使用公共 Documents 目录
         _dataDir = Directory('/storage/emulated/0/Documents/PaperWhisper/diary_data');
         
         // [MIGRATION] 检查是否存在私有目录数据，如果有则迁移
         await _migrateFromPrivateToPublic(_dataDir!);
      } else {
         // 无权限：使用应用私有目录
         final appDir = await getApplicationDocumentsDirectory();
         _dataDir = Directory(path.join(appDir.path, 'diary_data'));
      }
    } else {
      // iOS / MacOS
      final appDir = await getApplicationDocumentsDirectory();
      _dataDir = Directory(path.join(appDir.path, 'diary_data'));
    }

    if (!await _dataDir!.exists()) {
      try {
        await _dataDir!.create(recursive: true);
      } catch (e) {
        debugPrint("Error creating data dir: $e");
        // Fallback
        if (Platform.isAndroid) {
          final appDir = await getApplicationDocumentsDirectory();
          _dataDir = Directory(path.join(appDir.path, 'diary_data'));
          await _dataDir!.create(recursive: true);
        }
      }
    }
    
    debugPrint("✅ DiaryService Initialized. Using Data Dir: ${_dataDir!.path}");
    
    // Init Helper Services
    await _manifestService.init(_dataDir!);
    await _trashService.init(_dataDir!);
    await _manifestService.ensureConsistency(_dataDir!);
  }

  /// Android: 将私有目录数据迁移到公共目录
  Future<void> _migrateFromPrivateToPublic(Directory publicDir) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final privateDir = Directory(path.join(appDir.path, 'diary_data'));
      
      if (await privateDir.exists()) {
        final files = privateDir.listSync();
        if (files.isEmpty) return;
        
        // 确保目标目录已创建
        if (!await publicDir.exists()) {
          await publicDir.create(recursive: true);
        }

        int count = 0;
        for (var entity in files) {
          if (entity is File && entity.path.endsWith('.txt')) {
             String filename = path.basename(entity.path);
             File targetFile = File(path.join(publicDir.path, filename));
             
             // 如果目标文件不存在，才移动（避免覆盖）
             if (!await targetFile.exists()) {
               await entity.copy(targetFile.path); // Copy first
               await entity.delete(); // Then delete
               count++;
             }
          }
        }
        if (count > 0) {
          debugPrint("🚀 Migrated $count diaries from Private to Public storage.");
        }
      }
    } catch (e) {
      debugPrint("Migration failed: $e");
    }
  }

  Future<List<DiaryEntry>> getEntries() async {
    await init();
    List<DiaryEntry> entries = [];
    if (_dataDir == null) return entries;

    try {
      List<FileSystemEntity> files = await _dataDir!.list().toList();
      for (var file in files) {
        if (file is File && file.path.endsWith('.txt')) {
          try {
            String content = await file.readAsString();
            String filename = path.basename(file.path);
            entries.add(DiaryEntry.fromFileContent(filename, content));
          } catch (e) {
            debugPrint("Error reading file ${file.path}: $e");
          }
        }
      }
      // Sort by date desc
      entries.sort((a, b) => b.dateString.compareTo(a.dateString));
    } catch (e) {
      debugPrint("Error listing files: $e");
    }
    
    return entries;
  }

  Future<String> saveEntry(DiaryEntry entry) async {
    await init();
    
    // 如果没有文件名（新日记），生成一个
    // Python逻辑: unique_id = str(uuid.uuid4())[:8]; filename = f"{date}_{unique_id}.txt"
    String filename = entry.filename;
    if (filename.isEmpty) {
      String dateStr = entry.dateString;
      String uniqueId = _uuid.v4().substring(0, 8);
      filename = "${dateStr}_$uniqueId.txt";
    }

    // 完整的保存逻辑，包含 filename 更新（如果是新建的话，虽然 DiaryEntry 是 final filename... 
    // Wait, DiaryEntry.filename is final. So if it's new, we need to return the new filename or object.
    // The Input entry might have empty filename.
    
    File file = File(path.join(_dataDir!.path, filename));
    await file.writeAsString(entry.toFileContent());
    
    // Update Manifest
    _manifestService.updateItem(filename, isDeleted: false);
    
    return filename;
  }

  Future<void> deleteEntry(String filename) async {
    await init();
    File file = File(path.join(_dataDir!.path, filename));
    if (await file.exists()) {
      // Logic changed: Move to Trash instead of Delete
      await _trashService.moveToTrash(file);
    }
    
    _manifestService.updateItem(filename, isDeleted: true);
  }

  // --- Cache Mechanism for Fast Launch ---

  Future<void> saveCache(List<DiaryEntry> entries) async {
    if (_dataDir == null) return;
    try {
      final cacheFile = File(path.join(_dataDir!.path, 'diary_cache.json'));
      // 为了性能，不使用 compute，直接在 IO 线程序列化（数据量不大）
      // 如果数据量巨大，可以考虑 compute
      final jsonList = entries.map((e) => e.toJson()).toList();
      final jsonStr = jsonEncode(jsonList);
      await cacheFile.writeAsString(jsonStr);
      
      // Update Manifest? Not strictly necessary for cache file as it is local-only optimization usually,
      // but if we want to sync cache context (not recommended due to conflict), skip it.
      // Cache is derived data.
    } catch (e) {
      debugPrint("Error saving cache: $e");
    }
  }

  Future<List<DiaryEntry>?> loadCache() async {
    await init(); // Ensure dir
    if (_dataDir == null) return null;

    try {
      final cacheFile = File(path.join(_dataDir!.path, 'diary_cache.json'));
      if (await cacheFile.exists()) {
        final jsonStr = await cacheFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        final entries = jsonList.map((e) => DiaryEntry.fromJson(e)).toList();
        
        // Sort by date desc (Cache should be sorted, but ensure it)
        entries.sort((a, b) => b.dateString.compareTo(a.dateString));
        return entries;
      }
    } catch (e) {
      debugPrint("Error loading cache: $e");
    }
    return null;
  }
}
