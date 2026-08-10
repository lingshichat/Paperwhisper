import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment.dart';
import 'package:paper_whisper_flutter/features/diary/data/diary_entry.dart';
import 'package:paper_whisper_flutter/models/trash_record.dart';
import 'package:paper_whisper_flutter/services/manifest_service.dart';
import 'package:paper_whisper_flutter/services/trash_service.dart';
import 'package:paper_whisper_flutter/features/diary/data/diary_service.dart';

class MomentService {
  MomentService({Directory? debugDataDir, DiaryService? diaryService})
    : _debugDataDir = debugDataDir,
      _diaryService = diaryService;

  final Directory? _debugDataDir;

  /// 聚合导出使用的共享 DiaryService（由 composition root 注入，
  /// 不再局部 new，避免写独立 manifest 造成状态分歧）。
  final DiaryService? _diaryService;
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

    if (_debugDataDir != null) {
      _dataDir = _debugDataDir;
    } else if (Platform.isWindows) {
      // 1. 开发/迁移模式：检查上级目录的 moments_data
      Directory devLegacyDir = Directory(
        path.normalize(path.absolute('..', 'moments_data')),
      );
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
          _dataDir = Directory(
            path.join(docDir.path, 'PaperWhisper', 'moments_data'),
          );
        }
      }
    } else if (Platform.isAndroid) {
      // Android: Robust Permission & Path Logic

      // Try to get Manage External Storage first (for full access)
      if (await Permission.manageExternalStorage.isGranted) {
        _dataDir = Directory(
          '/storage/emulated/0/Documents/PaperWhisper/moments_data',
        );
      } else {
        // Check standard storage permissions
        // For Android 13+ (SDK 33), storage permission is split.
        // But we mainly need to read/write our OWN files or generic docs.
        // If manageExternalStorage is NOT granted, we fall back to App-Specific storage
        // because "Documents" is not writable without it on new Android.

        // However, try legacy approach just in case
        final extDir =
            await getExternalStorageDirectory(); // Android/data/package/files
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
      await _manifestService.init(
        _dataDir!,
        manifestFileName: 'local_moments_manifest.json',
      );
      await _manifestService.ensureConsistency(
        _dataDir!,
        fileExtension: '.json',
      );
      await _trashService.init(_dataDir!);

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
  final TrashService _trashService = TrashService();
  ManifestService get manifestService => _manifestService;
  TrashService get trashService => _trashService;

  Future<void> saveMoment(Moment moment) async {
    await init();
    // Filename convention: moment_{uuid}.json
    String filename = "moment_${moment.uuid}.json";
    File file = File(path.join(_dataDir!.path, filename));
    await file.writeAsString(moment.toJsonString());

    // Update Manifest (串行队列，可等待)
    await _manifestService.updateItem(filename, isDeleted: false);
  }

  Future<void> deleteMoment(String uuid) async {
    await archiveMomentByFilename('moment_$uuid.json');
  }

  Future<void> archiveMomentByFilename(
    String filename, {
    int? manifestTimestamp,
  }) async {
    await init();
    File file = File(path.join(_dataDir!.path, filename));

    if (await file.exists()) {
      final _MomentArchivePayload payload = await _buildArchivePayload(
        filename,
        file,
      );
      try {
        await _trashService.archiveRecord(
          record: payload.record,
          primaryFile: file,
          relatedFiles: payload.relatedFiles,
        );
      } catch (e) {
        debugPrint("Error archiving moment $filename: $e");
        rethrow;
      }
    }

    await _manifestService.updateItem(
      filename,
      isDeleted: true,
      timestamp: manifestTimestamp,
    );
  }

  Future<_MomentArchivePayload> _buildArchivePayload(
    String filename,
    File file,
  ) async {
    final Map<String, File> relatedFiles = <String, File>{};
    String? previewText;

    try {
      final content = await file.readAsString();
      final moment = Moment.fromJsonString(content);
      final trimmedContent = moment.content.trim();
      previewText = trimmedContent.isEmpty ? null : trimmedContent;

      for (final relativePath in moment.images) {
        final name = path.basename(relativePath);
        final imageFile = File(path.join(_dataDir!.path, 'images', name));
        if (await imageFile.exists()) {
          relatedFiles[path.join('images', name)] = imageFile;
        }
      }

      if (moment.audioPath != null && moment.audioPath!.trim().isNotEmpty) {
        final audioName = path.basename(moment.audioPath!);
        final audioFile = File(path.join(_dataDir!.path, 'audio', audioName));
        if (await audioFile.exists()) {
          relatedFiles[path.join('audio', audioName)] = audioFile;
        }
      }
    } catch (e) {
      debugPrint("Error reading moment archive payload $filename: $e");
    }

    return _MomentArchivePayload(
      record: TrashRecord(
        type: TrashRecordType.moment,
        primaryFilename: filename,
        relatedFiles: relatedFiles.keys
            .map((item) => item.replaceAll('\\', '/'))
            .toList(),
        deletedAt: DateTime.now(),
        title: '随心记',
        previewText: previewText,
      ),
      relatedFiles: relatedFiles,
    );
  }

  /// Copy an image file to the moments images directory and return the relative path
  Future<String> saveImage(File sourceFile) async {
    await init();
    String ext = path.extension(sourceFile.path);
    // Use timestamp + random for unique filename
    String filename =
        "${DateTime.now().millisecondsSinceEpoch}_${sourceFile.hashCode}$ext";
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
  Future<String?> exportDailySummary(
    DateTime date, {
    String customTitle = "",
  }) async {
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
      String timeStr =
          "${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}";
      buffer.writeln("[$timeStr] ${m.weather ?? ''} ${m.mood ?? ''}");
      buffer.writeln(m.content);
      if (m.images.isNotEmpty) {
        buffer.writeln("\n(包含 ${m.images.length} 张图片，请在随心记查看)");
      }
      buffer.writeln("\n${'-' * 20}\n");
    }

    // 3. Save via DiaryService (共享注入实例，不再局部 new，
    //    避免写独立 manifest 造成状态分歧)
    final diaryService = _diaryService;
    if (diaryService == null) {
      debugPrint('exportDailySummary skipped: no DiaryService injected');
      return null;
    }

    String dateStr =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    String finalTitle = customTitle.isNotEmpty
        ? customTitle
        : "${date.year}年${date.month}月${date.day}日 随心记聚合";

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

    String filename = "${DateTime.now().millisecondsSinceEpoch}_audio$ext";
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

class _MomentArchivePayload {
  final TrashRecord record;
  final Map<String, File> relatedFiles;

  const _MomentArchivePayload({
    required this.record,
    required this.relatedFiles,
  });
}
