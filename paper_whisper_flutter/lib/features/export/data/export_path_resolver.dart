import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// 按平台与存储授权状态解析导出目录。
///
/// 职责边界：
/// - 只做路径决策，不做目录创建、权限申请或文件写入；
/// - 不持有 BuildContext，不依赖 Widget / Provider；
/// - 平台、权限与目录来源全部通过可选依赖 seam 注入，测试可逐分支替换。
///
/// 迁移来源（原三处重复逻辑，逐字保持行为）：
/// - `editor_page._captureAndSave`（导出路径分支）
/// - `moment_card._captureAndSave`（导出路径分支）
/// - `diary_export_service._resolveExportDirectory`
///
/// 默认分支规则：
/// - Android 且 manageExternalStorage 已授权 → `/storage/emulated/0/Pictures/PaperWhisper`
/// - Android 未授权 → 应用外部目录 `Exports`，无则 documents `Exports` 兜底
/// - 非 Android → documents `PaperWhisper_Exports`
class ExportPathResolver {
  const ExportPathResolver({
    this.isAndroid,
    this.isManageExternalStorageGranted,
    this.applicationDocumentsDirectory,
    this.externalStorageDirectory,
  });

  /// 平台判定（默认 [Platform.isAndroid]）。
  final bool Function()? isAndroid;

  /// 存储授权判定（默认 [Permission.manageExternalStorage.isGranted]）。
  final Future<bool> Function()? isManageExternalStorageGranted;

  /// 应用文档目录（默认 [getApplicationDocumentsDirectory]）。
  final Future<Directory> Function()? applicationDocumentsDirectory;

  /// 应用专属外部目录（默认 [getExternalStorageDirectory]，可空）。
  final Future<Directory?> Function()? externalStorageDirectory;

  /// 解析导出目录。
  Future<Directory> resolve() async {
    final bool android = (isAndroid ?? _defaultIsAndroid)();
    final Directory documents =
        await (applicationDocumentsDirectory ??
            getApplicationDocumentsDirectory)();

    if (!android) {
      return Directory(path.join(documents.path, 'PaperWhisper_Exports'));
    }

    final bool granted =
        await (isManageExternalStorageGranted ??
            _defaultManageExternalStorageGranted)();
    if (granted) {
      return Directory('/storage/emulated/0/Pictures/PaperWhisper');
    }

    final Directory? extDir =
        await (externalStorageDirectory ?? getExternalStorageDirectory)();
    if (extDir != null) {
      return Directory(path.join(extDir.path, 'Exports'));
    }
    return Directory(path.join(documents.path, 'Exports'));
  }

  static bool _defaultIsAndroid() => Platform.isAndroid;

  static Future<bool> _defaultManageExternalStorageGranted() =>
      Permission.manageExternalStorage.isGranted;
}
