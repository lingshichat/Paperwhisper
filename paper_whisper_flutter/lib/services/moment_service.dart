import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import '../models/moment.dart';
import '../models/diary_entry.dart';
import '../services/diary_service.dart';

class MomentService {
  Directory? _dataDir;
  Directory? _imagesDir;

  // 获取数据目录路径，供 UI 显示调试用
  String get currentDataPath => _dataDir?.path ?? 'Unknown';
  Directory? get dataDir => _dataDir;

  void reset() {
    _dataDir = null;
    _imagesDir = null;
  }

  Future<void> init() async {
    if (_dataDir != null) return;

    if (Platform.isWindows) {
      // 1. 开发/迁移模式：检查上级目录的 moments_data
      Directory devLegacyDir = Directory(path.normalize(path.absolute('..', 'moments_data')));
      if (await devLegacyDir.exists()) {
        _dataDir = devLegacyDir;
        debugPrint("Using Legacy/Dev Moments Data Dir: ${_dataDir!.path}");
      } else {
        // 2. 便携模式：检查可执行文件同级 moments_data
        String exeDir = path.dirname(Platform.resolvedExecutable);
        Directory portableDir = Directory(path.join(exeDir, 'moments_data'));
        if (await portableDir.exists()) {
          _dataDir = portableDir;
        } else {
          // 3. 标准模式：文档目录/PaperWhisper/moments_data
          final docDir = await getApplicationDocumentsDirectory();
          _dataDir = Directory(path.join(docDir.path, 'PaperWhisper', 'moments_data'));
        }
      }
    } else if (Platform.isAndroid) {
      // Android: 检查权限状态
      var status = await Permission.manageExternalStorage.status;
      
      bool hasLegacyStorage = false;
      if (!status.isGranted) {
         var storageStatus = await Permission.storage.status;
         hasLegacyStorage = storageStatus.isGranted;
      }

      if (status.isGranted || hasLegacyStorage) {
         // 有权限：使用公共 Documents 目录
         _dataDir = Directory('/storage/emulated/0/Documents/PaperWhisper/moments_data');
      } else {
         // 无权限：使用应用私有目录 (Fallback)
         final appDir = await getApplicationDocumentsDirectory();
         _dataDir = Directory(path.join(appDir.path, 'moments_data'));
      }
    } else {
      // iOS / Other
      final appDir = await getApplicationDocumentsDirectory();
      _dataDir = Directory(path.join(appDir.path, 'moments_data'));
    }

    // Ensure main data dir exists
    if (!await _dataDir!.exists()) {
      try {
        await _dataDir!.create(recursive: true);
      } catch (e) {
        debugPrint("Error creating moments data dir: $e");
        if (Platform.isAndroid) {
          final appDir = await getApplicationDocumentsDirectory();
          _dataDir = Directory(path.join(appDir.path, 'moments_data'));
          await _dataDir!.create(recursive: true);
        }
      }
    }

    // Ensure images dir exists
    _imagesDir = Directory(path.join(_dataDir!.path, 'images'));
    if (!await _imagesDir!.exists()) {
      await _imagesDir!.create(recursive: true);
    }
  }

  Future<List<Moment>> getMoments() async {
    await init();
    List<Moment> moments = [];
    if (_dataDir == null) return moments;

    try {
      List<FileSystemEntity> files = await _dataDir!.list().toList();
      for (var file in files) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            String content = await file.readAsString();
            moments.add(Moment.fromJsonString(content));
          } catch (e) {
            debugPrint("Error reading moment file ${file.path}: $e");
          }
        }
      }
      // Sort by createdAt desc
      moments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint("Error listing moment files: $e");
    }
    
    return moments;
  }

  Future<void> saveMoment(Moment moment) async {
    await init();
    // Filename convention: moment_{uuid}.json
    String filename = "moment_${moment.uuid}.json";
    File file = File(path.join(_dataDir!.path, filename));
    await file.writeAsString(moment.toJsonString());
  }

  Future<void> deleteMoment(String uuid) async {
    await init();
    String filename = "moment_$uuid.json";
    File file = File(path.join(_dataDir!.path, filename));
    if (await file.exists()) {
      await file.delete();
    }
    // Note: We are not automatically deleting images to avoid accidental data loss 
    // if images are shared (though here they are copied). 
    // Optimization: could add logic to delete images if they are unique to this moment.
  }

  /// Copy an image file to the moments images directory and return the relative path
  Future<String> saveImage(File sourceFile) async {
    await init();
    String ext = path.extension(sourceFile.path);
    // Use timestamp + random for unique filename
    String filename = "${DateTime.now().millisecondsSinceEpoch}_${sourceFile.hashCode}$ext";
    String destinationPath = path.join(_imagesDir!.path, filename);
    
    await sourceFile.copy(destinationPath);
    
    // Return relative path: images/filename
    return path.join('images', filename);
  }

  /// Get absolute path of an image from its relative path
  Future<String?> getAbsoluteImagePath(String relativePath) async {
    await init();
    if (_dataDir == null) return null;
    return path.join(_dataDir!.path, relativePath);
  }

  /// Export daily summary to DiaryService
  Future<String?> exportDailySummary(DateTime date, {String customTitle = ""}) async {
    await init();
    
    // 1. Filter moments for the date
    List<Moment> moments = await getMoments();
    List<Moment> dayMoments = moments.where((m) {
      return m.createdAt.year == date.year && 
             m.createdAt.month == date.month && 
             m.createdAt.day == date.day;
    }).toList();
    
    if (dayMoments.isEmpty) return null;
    
    // Sort by time asc
    dayMoments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    // 2. Build content
    StringBuffer buffer = StringBuffer();
    // Add a header
    buffer.writeln("今日随心记聚合\n");
    
    for (var m in dayMoments) {
       String timeStr = "${m.createdAt.hour.toString().padLeft(2,'0')}:${m.createdAt.minute.toString().padLeft(2,'0')}";
       buffer.writeln("[$timeStr] ${m.weather ?? ''} ${m.mood ?? ''}");
       buffer.writeln(m.content);
       if (m.images.isNotEmpty) {
         buffer.writeln("\n(包含 ${m.images.length} 张图片，请在随心记查看)");
       }
       buffer.writeln("\n" + "-" * 20 + "\n");
    }
    
    // 3. Save via DiaryService
    final diaryService = DiaryService();
    
    String dateStr = "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
    String finalTitle = customTitle.isNotEmpty ? customTitle : "${date.year}年${date.month}月${date.day}日 随心记聚合";
    
    // Fixed filename to allow overwrite: YYYY-MM-DD_moments_summary.txt
    String fixedFilename = "${dateStr}_moments_summary.txt";

    DiaryEntry entry = DiaryEntry(
      filename: fixedFilename, 
      title: finalTitle,
      dateString: dateStr,
      content: buffer.toString(),
      isMarkdown: false,
    );
    
    return await diaryService.saveEntry(entry);
  }
}
