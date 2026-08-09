import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

import '../../export/data/export_path_resolver.dart';

/// 长图导出分块计划（纯数据，可独立测试）。
///
/// 布局固定为 1 个 Header + N 个正文块 + 1 个 Footer，
/// 每个正文块不超过 [DiaryExportService.linesPerChunk] 行。
class DiaryExportChunkPlan {
  const DiaryExportChunkPlan({
    required this.totalChunks,
    required this.bodyChunkTexts,
  });

  /// 全部分块数（Header + 正文 + Footer）。
  final int totalChunks;

  /// 每个正文分块的文本切片（不含 Header/Footer）。
  final List<String> bodyChunkTexts;
}

/// 分块捕获回调：由展示层实现 RepaintBoundary 查找与 RenderObject 捕获。
///
/// 返回 null 表示该分块当前不可捕获（与原页面行为一致：跳过该块，
/// 只要仍有其他块成功即继续）；抛出异常则中断整个导出。
typedef DiaryChunkCapture =
    Future<ui.Image?> Function(int chunkIndex, double pixelRatio);

/// 导出结果：文件路径、尺寸与分块统计。
class DiaryExportResult {
  const DiaryExportResult({
    required this.filePath,
    required this.width,
    required this.height,
    required this.chunkCount,
    required this.bodyChunkCount,
  });

  final String filePath;
  final int width;
  final int height;
  final int chunkCount;
  final int bodyChunkCount;
}

/// 导出失败异常（携带用户可见的错误类别，不携带堆栈）。
class DiaryExportException implements Exception {
  const DiaryExportException(this.message);

  final String message;

  // 与原页面 `throw Exception(...)` 的 toString 输出保持一致，
  // 避免改变失败提示中的用户可见文案。
  @override
  String toString() => 'Exception: $message';
}

/// 长图导出服务：分块计划、捕获编排、图片拼接、编码与文件写入。
///
/// 职责边界：
/// - 持有分块计算、ui.Image 捕获编排、PNG 解码、JPG 编码、路径/目录解析与写入
/// - 不持有 BuildContext，不负责 RepaintBoundary 查找、Dialog/Toast 与权限 UI
///
/// 展示层通过 [DiaryChunkCapture] 注入捕获能力，捕获到的 RenderObject
/// 归属权仍在展示层，本服务只消费其产生的 [ui.Image]。
class DiaryExportService {
  /// [exportDirectoryResolver]：导出目录解析器（可注入，测试可用临时目录）。
  ///
  /// production 缺省逐字走 [_resolveExportDirectory] 的平台三分支逻辑。
  /// [timestampMillis]：文件名时间戳（毫秒）来源（可注入，测试可用固定值）。
  ///
  /// production 缺省为 `DateTime.now().millisecondsSinceEpoch`。
  /// 本服务不暴露 BuildContext / Widget / Provider。
  const DiaryExportService({
    this.exportDirectoryResolver,
    this.timestampMillis,
  });

  /// 导出目录解析器（可注入）；为 null 时使用平台三分支默认逻辑。
  final Future<Directory> Function()? exportDirectoryResolver;

  /// 文件名时间戳（毫秒）来源（可注入）；为 null 时使用系统当前时间。
  final int Function()? timestampMillis;

  /// 每块正文行数：40 行 * 32px ≈ 1280px 高度（含内边距），拼接安全。
  static const int linesPerChunk = 40;

  /// 捕获像素比：分块后每块独立捕获，可负担 3.0 高清输出。
  static const double pixelRatio = 3.0;

  /// JPG 编码质量。
  static const int jpgQuality = 90;

  /// 根据正文文本计算分块计划（纯函数，无 I/O）。
  DiaryExportChunkPlan buildChunkPlan(String text) {
    final List<String> lines = text.split('\n');
    if (lines.isEmpty) lines.add('');

    int textChunkCount = (lines.length / linesPerChunk).ceil();
    if (textChunkCount == 0) textChunkCount = 1;

    // Chunks: 1 Header + N Body + 1 Footer
    final int totalChunks = 1 + textChunkCount + 1;

    final List<String> bodyChunkTexts = [];
    for (int i = 0; i < lines.length; i += linesPerChunk) {
      final int end = (i + linesPerChunk < lines.length)
          ? i + linesPerChunk
          : lines.length;
      bodyChunkTexts.add(lines.sublist(i, end).join('\n'));
    }

    return DiaryExportChunkPlan(
      totalChunks: totalChunks,
      bodyChunkTexts: bodyChunkTexts,
    );
  }

  /// 执行完整导出：捕获全部分块 → 拼接 → 编码 → 写入文件。
  ///
  /// [baseName] 参与文件名（原页面语义：`diary_<baseName>_<毫秒时间戳>.jpg`，
  /// 新建日记传 'new'）。[capture] 由展示层实现，负责按分块索引捕获图像。
  Future<DiaryExportResult> export({
    required DiaryExportChunkPlan plan,
    required String baseName,
    required DiaryChunkCapture capture,
  }) async {
    // 1. 捕获全部分块（跳过不可捕获的块，与原行为一致）
    final List<img.Image> capturedImages = [];
    double totalHeight = 0;
    double maxWidth = 0;

    for (int i = 0; i < plan.totalChunks; i++) {
      final ui.Image? image = await capture(i, pixelRatio);
      if (image == null) continue;

      try {
        final ByteData? byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (byteData == null) continue;

        final img.Image? decoded = img.decodePng(byteData.buffer.asUint8List());
        if (decoded != null) {
          capturedImages.add(decoded);
          totalHeight += decoded.height;
          if (decoded.width > maxWidth) maxWidth = decoded.width.toDouble();
        }
      } finally {
        // ui.Image 由本服务消费完毕后释放（原页面未释放，这里补上资源回收）
        image.dispose();
      }
    }

    if (capturedImages.isEmpty) {
      throw const DiaryExportException('No content captured');
    }

    // 2. 拼接：透明画布上按顺序纵向堆叠（各块自带纸面底色）
    final img.Image stitchCanvas = img.Image(
      width: maxWidth.toInt(),
      height: totalHeight.toInt(),
    );

    int currentY = 0;
    for (final img.Image part in capturedImages) {
      img.compositeImage(stitchCanvas, part, dstX: 0, dstY: currentY);
      currentY += part.height;
    }

    // 3. 解析导出目录并写入
    final Directory exportDir = await _resolveExportDir();
    if (!await exportDir.exists()) {
      try {
        await exportDir.create(recursive: true);
      } catch (_) {
        // 目录创建失败不阻断后续 File 写入（File.writeAsBytes 会再次尝试）
      }
    }

    final int timestamp =
        timestampMillis?.call() ?? DateTime.now().millisecondsSinceEpoch;
    final String fileName = 'diary_${baseName}_$timestamp.jpg';
    final File file = File(path.join(exportDir.path, fileName));
    await file.writeAsBytes(img.encodeJpg(stitchCanvas, quality: jpgQuality));

    return DiaryExportResult(
      filePath: file.path,
      width: stitchCanvas.width,
      height: stitchCanvas.height,
      chunkCount: capturedImages.length,
      bodyChunkCount: plan.bodyChunkTexts.length,
    );
  }

  /// 解析导出目录：优先使用注入的 resolver，缺省走 [ExportPathResolver]
  /// 的平台三分支（Android 授权 / Android 未授权 / 非 Android）。
  Future<Directory> _resolveExportDir() async {
    final resolver = exportDirectoryResolver;
    if (resolver != null) return resolver();
    return (await const ExportPathResolver().resolve()).directory;
  }
}
