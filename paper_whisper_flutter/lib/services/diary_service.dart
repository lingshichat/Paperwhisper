import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/diary_entry.dart';

class DiaryService {
  Directory? _dataDir;
  final Uuid _uuid = const Uuid();

  // 获取数据目录路径，供 UI 显示调试用
  String get currentDataPath => _dataDir?.path ?? 'Unknown';

  Future<void> init() async {
    if (_dataDir != null) return;

    if (Platform.isWindows) {
      // 1. 开发/迁移模式：检查上级目录的 diary_data (针对当前 workspace)
      // 当前运行在 paper_whisper_flutter 下，上级是 paperwhisper
      Directory devLegacyDir = Directory(path.normalize(path.absolute('..', 'diary_data')));
      if (await devLegacyDir.exists()) {
        _dataDir = devLegacyDir;
        debugPrint("Using Legacy/Dev Data Dir: ${_dataDir!.path}");
      } else {
        // 2. 便携模式：检查可执行文件同级 diary_data
        String exeDir = path.dirname(Platform.resolvedExecutable);
        Directory portableDir = Directory(path.join(exeDir, 'diary_data'));
        if (await portableDir.exists()) {
          _dataDir = portableDir;
        } else {
          // 3. 标准模式：文档目录/PaperWhisper
          final docDir = await getApplicationDocumentsDirectory();
          _dataDir = Directory(path.join(docDir.path, 'PaperWhisper', 'diary_data'));
        }
      }
    } else {
      // Android / iOS
      final appDir = await getApplicationDocumentsDirectory();
      _dataDir = Directory(path.join(appDir.path, 'diary_data'));
    }

    if (!await _dataDir!.exists()) {
      await _dataDir!.create(recursive: true);
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
    
    return filename;
  }

  Future<void> deleteEntry(String filename) async {
    await init();
    File file = File(path.join(_dataDir!.path, filename));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
