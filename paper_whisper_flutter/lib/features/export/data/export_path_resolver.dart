import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// 导出目录命中分支（供测试与调用方区分解析结果）。
enum ExportPathKind {
  /// Android 且已授予 manageExternalStorage：系统 Pictures 目录。
  androidPublicPictures,

  /// Android 未授权但有应用专属外部目录：external/Exports。
  androidAppExternal,

  /// Android 未授权且无应用专属外部目录：documents/Exports 兜底。
  androidDocumentsFallback,

  /// 非 Android 平台：documents/PaperWhisper_Exports。
  desktopDocuments,
}

/// 导出路径解析结果（typed value，不含任何平台 API）。
class ExportPathResult {
  const ExportPathResult({required this.path, required this.kind});

  final String path;
  final ExportPathKind kind;

  Directory get directory => Directory(path);
}

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
  Future<ExportPathResult> resolve() async {
    final bool android = (isAndroid ?? _defaultIsAndroid)();
    final Directory documents =
        await (applicationDocumentsDirectory ??
            getApplicationDocumentsDirectory)();

    if (!android) {
      return ExportPathResult(
        path: path.join(documents.path, 'PaperWhisper_Exports'),
        kind: ExportPathKind.desktopDocuments,
      );
    }

    final bool granted =
        await (isManageExternalStorageGranted ??
            _defaultManageExternalStorageGranted)();
    if (granted) {
      return const ExportPathResult(
        path: '/storage/emulated/0/Pictures/PaperWhisper',
        kind: ExportPathKind.androidPublicPictures,
      );
    }

    final Directory? extDir =
        await (externalStorageDirectory ?? getExternalStorageDirectory)();
    if (extDir != null) {
      return ExportPathResult(
        path: path.join(extDir.path, 'Exports'),
        kind: ExportPathKind.androidAppExternal,
      );
    }
    return ExportPathResult(
      path: path.join(documents.path, 'Exports'),
      kind: ExportPathKind.androidDocumentsFallback,
    );
  }

  static bool _defaultIsAndroid() => Platform.isAndroid;

  static Future<bool> _defaultManageExternalStorageGranted() =>
      Permission.manageExternalStorage.isGranted;
}
