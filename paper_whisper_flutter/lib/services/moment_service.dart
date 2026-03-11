import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import '../models/moment.dart';
import '../models/diary_entry.dart';
import '../services/diary_service.dart';
import 'manifest_service.dart';

class MomentService {
  Directory? _dataDir;
  Directory? _imagesDir;
  Directory? _audioDir;

  // 获取数据目录路径，供 UI 显示调试用
  String get currentDataPath => _dataDir?.path ?? 'Unknown';
  Directory? get dataDir => _dataDir;
  Directory? get imagesDir => _imagesDir;
  Directory? get audioDir => _audioDir;

  void reset() {
    _dataDir = null;
    _imagesDir = null;
    _audioDir = null;
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
      // Android: Robust Permission & Path Logic
      
      // Try to get Manage External Storage first (for full access)
      if (await Permission.manageExternalStorage.isGranted) {
         _dataDir = Directory('/storage/emulated/0/Documents/PaperWhisper/moments_data');
      } else {
         // Check standard storage permissions
         // For Android 13+ (SDK 33), storage permission is split. 
         // But we mainly need to read/write our OWN files or generic docs.
         // If manageExternalStorage is NOT granted, we fall back to App-Specific storage 
         // because "Documents" is not writable without it on new Android.
         
         // However, try legacy approach just in case
         final extDir = await getExternalStorageDirectory(); // Android/data/package/files
         if (extDir != null) {
            _dataDir = Directory(path.join(extDir.path, 'moments_data'));
         } else {
            final appDir = await getApplicationDocumentsDirectory();
            _dataDir = Directory(path.join(appDir.path, 'moments_data'));
         }
      }
    } else {
      // iOS / Other
      final appDir = await getApplicationDocumentsDirectory();
      _dataDir = Directory(path.join(appDir.path, 'moments_data'));
    }

    // Ensure main data dir exists
    if (_dataDir != null && !await _dataDir!.exists()) {
      try {
        await _dataDir!.create(recursive: true);
      } catch (e) {
        debugPrint("Error creating moments data dir at ${_dataDir?.path}: $e");
        // Fallback for Android if creation failed (e.g. permission mismatch)
        if (Platform.isAndroid) {
          final appDir = await getApplicationDocumentsDirectory();
          _dataDir = Directory(path.join(appDir.path, 'moments_data'));
          await _dataDir!.create(recursive: true);
        }
      }
    }

    // Ensure images dir exists
    if (_dataDir != null) {
      _imagesDir = Directory(path.join(_dataDir!.path, 'images'));
      if (!await _imagesDir!.exists()) {
        await _imagesDir!.create(recursive: true);
      }
      
      // Init Manifest
      await _manifestService.init(_dataDir!, manifestFileName: 'local_moments_manifest.json');
      await _manifestService.ensureConsistency(_dataDir!, fileExtension: '.json');

      // Create Audio Dir
      _audioDir = Directory(path.join(_dataDir!.path, 'audio'));
      if (!await _audioDir!.exists()) {
        await _audioDir!.create(recursive: true);
      }
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

  Future<Set<String>> getAllReferencedImages() async {
    List<Moment> moments = await getMoments();
    Set<String> validImages = {};
    for (var m in moments) {
       for (var imgPath in m.images) {
          // imgPath is relative 'images/xxx.jpg' or just 'xxx.jpg' depending on version
          // We normalize to basename to be safe
          validImages.add(path.basename(imgPath));
       }
    }
    return validImages;
  }

  final ManifestService _manifestService = ManifestService();
  ManifestService get manifestService => _manifestService;

  Future<void> saveMoment(Moment moment) async {
    await init();
    // Filename convention: moment_{uuid}.json
    String filename = "moment_${moment.uuid}.json";
    File file = File(path.join(_dataDir!.path, filename));
    await file.writeAsString(moment.toJsonString());
    
    // Update Manifest
    _manifestService.updateItem(filename, isDeleted: false);
  }

  Future<void> deleteMoment(String uuid) async {
    await init();
    String filename = "moment_$uuid.json";
    File file = File(path.join(_dataDir!.path, filename));
    
    // 1. Read content to find associated images
    if (await file.exists()) {
      try {
        String content = await file.readAsString();
        Moment moment = Moment.fromJsonString(content);
        
        // 2. Cascading Delete: Delete images
        for (String relativePath in moment.images) {
          // relativePath is usually "images/xxx.jpg"
          String name = path.basename(relativePath);
          File imageFile = File(path.join(_dataDir!.path, 'images', name));
          if (await imageFile.exists()) {
             try {
               await imageFile.delete();
               debugPrint("Deleted associated image: $name");
             } catch (e) {
               debugPrint("Error deleting image $name: $e");
             }
          }
        }

        // Delete Audio if exists
        if (moment.audioPath != null) {
           String audioName = path.basename(moment.audioPath!);
           File audioFile = File(path.join(_dataDir!.path, 'audio', audioName));
           if (await audioFile.exists()) {
              try {
                await audioFile.delete();
                debugPrint("Deleted associated audio: $audioName");
              } catch (e) {
                debugPrint("Error deleting audio $audioName: $e");
              }
           }
        }
      } catch (e) {
         debugPrint("Error parsing moment for cascading delete: $e");
      }
      
      // 3. Delete the JSON file
      await file.delete();
    }
    
    // Update Manifest
    _manifestService.updateItem(filename, isDeleted: true);
  }

  /// Copy an image file to the moments images directory and return the relative path
  Future<String> saveImage(File sourceFile) async {
    await init();
    String ext = path.extension(sourceFile.path);
    // Use timestamp + random for unique filename
    String filename = "${DateTime.now().millisecondsSinceEpoch}_${sourceFile.hashCode}$ext";
    String destinationPath = path.join(_imagesDir!.path, filename);
    
    await sourceFile.copy(destinationPath);
    
    // Return relative path: images/filename (Force POSIX style for cross-platform compatibility)
    String relativePath = path.join('images', filename);
    return relativePath.replaceAll('\\', '/');
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

  /// Copy an audio file to the moments audio directory and return the relative path
  Future<String> saveAudio(String sourcePath) async {
    await init();
    File sourceFile = File(sourcePath);
    String ext = path.extension(sourcePath); // usually .m4a or .wav
    if (ext.isEmpty) ext = '.m4a';
    
    String filename = "${DateTime.now().millisecondsSinceEpoch}_audio${ext}";
    String destinationPath = path.join(_audioDir!.path, filename);

    await sourceFile.copy(destinationPath);
    
    // Return relative path: audio/filename
    String relativePath = path.join('audio', filename);
    return relativePath.replaceAll('\\', '/');
  }

  Future<String?> getAbsoluteAudioPath(String relativePath) async {
    await init();
    if (_dataDir == null) return null;
    return path.join(_dataDir!.path, relativePath);
  }

}
