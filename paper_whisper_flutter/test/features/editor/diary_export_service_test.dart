import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:paper_whisper_flutter/features/editor/data/diary_export_service.dart';
import 'package:path/path.dart' as path;

/// DiaryExportService 单元测试（阶段 3 测试 lane 第四批）。
///
/// 通过公开契约与可注入 seam 刻画导出服务行为，不触碰私有状态、不做
/// private shadow：
/// - 分块计划纯函数：空文本 / 尾换行 / 39/40/41/80/81 行边界、长行不按
///   字符拆分、正文拼接还原原文、Header+Body+Footer 总块数不变式
/// - DiaryExportException.toString 保留 "Exception: " 前缀（与重构前
///   `throw Exception(...)` 的用户可见文案一致）
/// - 主链路：注入临时目录 resolver + 固定时间戳，capture 用 dart:ui
///   PictureRecorder 生成多块不同宽高纯色 ui.Image，断言捕获调用
///   index/pixelRatio、结果 path 精确文件名、width=max / height=sum、
///   chunk/body 统计、文件存在且 JPEG decode 尺寸一致
/// - 目录缺失自动创建；某块 null 跳过且统计一致；全部 null 抛
///   DiaryExportException；capture / 目录 resolver 异常按契约传播
/// - 捕获的 ui.Image 由服务消费后释放（通过公开 debugDisposed 判定）
///
/// 真实异步（Picture.toImage / toByteData / 文件 IO）在普通 test 下可用，
/// 无需 fake clock，不真实等待；临时目录只用系统 temp 下自建目录并在
/// tearDown 清理，不触碰真实用户路径。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  final List<ui.Image> createdImages = [];

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('diary_export_service_test');
  });

  tearDown(() {
    // 兜底释放：未被服务消费（如异常中断路径）的 ui.Image 由测试清理，
    // 已被服务 dispose 的跳过，避免重复 dispose。
    for (final image in createdImages) {
      if (!isImageDisposed(image)) image.dispose();
    }
    createdImages.clear();
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  // 生成指定尺寸的纯色 ui.Image（PictureRecorder 渲染，无真实设备依赖）。
  Future<ui.Image> makeSolidImage(int width, int height, ui.Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = color,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    createdImages.add(image);
    return image;
  }

  // 构造 capture：按 [sizes] 顺序生成纯色块；[nullIndices] 返回 null；
  // [errors] 中 index 对应的异常在捕获时抛出。记录每次 (index, pixelRatio)。
  Future<ui.Image?> Function(int, double) buildCapture(
    List<(int, int)> sizes,
    List<(int, double)> calls, {
    Set<int> nullIndices = const {},
    Map<int, Object> errors = const {},
  }) {
    return (index, pixelRatio) async {
      calls.add((index, pixelRatio));
      final error = errors[index];
      if (error != null) throw error;
      if (nullIndices.contains(index)) return null;
      final (width, height) = sizes[index];
      return makeSolidImage(width, height, const ui.Color(0xFFE8DCC0));
    };
  }

  // 默认导出目录解析到测试自建临时目录、时间戳固定，便于断言文件名。
  DiaryExportService buildService({
    Future<Directory> Function()? resolver,
    int Function()? timestamp,
  }) {
    return DiaryExportService(
      exportDirectoryResolver: resolver ?? () async => tempRoot,
      timestampMillis: timestamp ?? () => 1700000000000,
    );
  }

  group('分块计划（纯函数）', () {
    const service = DiaryExportService();

    test('空文本：1 个空正文块，Header+Body+Footer 共 3 块', () {
      final plan = service.buildChunkPlan('');
      expect(plan.totalChunks, 3);
      expect(plan.bodyChunkTexts, ['']);
    });

    test('尾换行文本：保留换行，单正文块', () {
      final plan = service.buildChunkPlan('第一行\n');
      expect(plan.totalChunks, 3);
      expect(plan.bodyChunkTexts, ['第一行\n']);
    });

    test('39 行：单块，内容完整', () {
      final text = makeLines(39);
      final plan = service.buildChunkPlan(text);
      expect(plan.totalChunks, 3);
      expect(plan.bodyChunkTexts.length, 1);
      expect(plan.bodyChunkTexts.single, text);
    });

    test('40 行：恰好单块（不触发分块）', () {
      final text = makeLines(40);
      final plan = service.buildChunkPlan(text);
      expect(plan.totalChunks, 3);
      expect(plan.bodyChunkTexts.length, 1);
      expect(plan.bodyChunkTexts.single, text);
    });

    test('41 行：两块（40 + 1）', () {
      final text = makeLines(41);
      final plan = service.buildChunkPlan(text);
      expect(plan.totalChunks, 4);
      expect(plan.bodyChunkTexts.length, 2);
      expect(plan.bodyChunkTexts[0], makeLines(40));
      expect(plan.bodyChunkTexts[1], '行41');
    });

    test('80 行：两块（40 + 40）', () {
      final text = makeLines(80);
      final plan = service.buildChunkPlan(text);
      expect(plan.totalChunks, 4);
      expect(plan.bodyChunkTexts.length, 2);
      expect(plan.bodyChunkTexts[0], makeLines(40));
      expect(plan.bodyChunkTexts[1], makeLines(40, start: 41));
    });

    test('81 行：三块（40 + 40 + 1）', () {
      final text = makeLines(81);
      final plan = service.buildChunkPlan(text);
      expect(plan.totalChunks, 5);
      expect(plan.bodyChunkTexts.length, 3);
      expect(plan.bodyChunkTexts[0], makeLines(40));
      expect(plan.bodyChunkTexts[1], makeLines(40, start: 41));
      expect(plan.bodyChunkTexts[2], '行81');
    });

    test('长行不按字符拆：1000 字符单行保持整块', () {
      final text = '长' * 1000;
      final plan = service.buildChunkPlan(text);
      expect(plan.totalChunks, 3);
      expect(plan.bodyChunkTexts.length, 1);
      expect(plan.bodyChunkTexts.single, text);
    });

    test('多块正文按序拼接可还原原文', () {
      final text = makeLines(81);
      final plan = service.buildChunkPlan(text);
      expect(plan.bodyChunkTexts.join('\n'), text);
    });

    test('总块数不变式：totalChunks = 正文块数 + 2（Header/Footer）', () {
      for (final count in [0, 1, 39, 40, 41, 80, 81, 200]) {
        final plan = service.buildChunkPlan(makeLines(count));
        expect(
          plan.totalChunks,
          plan.bodyChunkTexts.length + 2,
          reason: '行数 $count',
        );
      }
    });

    test('DiaryExportException.toString 保留 "Exception: " 前缀', () {
      const error = DiaryExportException('No content captured');
      expect(error.toString(), 'Exception: No content captured');
    });
  });

  group('主链路（真实捕获与文件写入）', () {
    test('成功导出：调用 index/pixelRatio、拼接尺寸、文件名与 JPEG 尺寸一致', () async {
      const baseName = 'new';
      const timestamp = 1700000000000;
      final sizes = [(100, 200), (200, 150), (150, 250), (180, 120)];
      final calls = <(int, double)>[];
      final plan = DiaryExportChunkPlan(
        totalChunks: 4,
        bodyChunkTexts: const ['第一块', '第二块'],
      );

      final result = await buildService().export(
        plan: plan,
        baseName: baseName,
        capture: buildCapture(sizes, calls),
      );

      // 捕获调用：全部分块按序、pixelRatio 固定为服务常量
      expect(calls.map((c) => c.$1), [0, 1, 2, 3]);
      expect(calls.every((c) => c.$2 == DiaryExportService.pixelRatio), isTrue);

      // 拼接尺寸：width=max，height=sum
      expect(result.width, 200);
      expect(result.height, 200 + 150 + 250 + 120);

      // 分块统计：chunkCount=捕获成功块数，bodyChunkCount=计划正文块数
      expect(result.chunkCount, 4);
      expect(result.bodyChunkCount, 2);

      // 文件路径精确匹配：<导出目录>/diary_<baseName>_<毫秒时间戳>.jpg
      final expectedPath = path.join(
        tempRoot.path,
        'diary_${baseName}_$timestamp.jpg',
      );
      expect(result.filePath, expectedPath);

      final file = File(expectedPath);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));

      // JPEG decode 尺寸与拼接画布一致
      final decoded = img.decodeJpg(await file.readAsBytes());
      expect(decoded, isNotNull);
      expect(decoded!.width, 200);
      expect(decoded.height, 720);
    });

    test('导出目录缺失时自动创建', () async {
      final exportDir = Directory(
        path.join(tempRoot.path, 'exports', 'nested'),
      );
      final plan = DiaryExportChunkPlan(
        totalChunks: 2,
        bodyChunkTexts: const ['正文'],
      );
      final calls = <(int, double)>[];

      final result = await buildService(resolver: () async => exportDir).export(
        plan: plan,
        baseName: 'new',
        capture: buildCapture([(120, 80), (90, 60)], calls),
      );

      expect(await exportDir.exists(), isTrue);
      expect(await File(result.filePath).exists(), isTrue);
      expect(path.dirname(result.filePath), exportDir.path);
    });

    test('某分块不可捕获（null）被跳过，统计与尺寸一致', () async {
      final sizes = [(100, 200), (200, 150), (150, 250), (180, 120)];
      final calls = <(int, double)>[];
      final plan = DiaryExportChunkPlan(
        totalChunks: 4,
        bodyChunkTexts: const ['第一块', '第二块'],
      );

      final result = await buildService().export(
        plan: plan,
        baseName: 'new',
        capture: buildCapture(sizes, calls, nullIndices: {1, 3}),
      );

      // 全部索引仍被尝试捕获
      expect(calls.map((c) => c.$1), [0, 1, 2, 3]);
      // 跳过块不计入统计与尺寸
      expect(result.chunkCount, 2);
      expect(result.bodyChunkCount, 2);
      expect(result.width, 150);
      expect(result.height, 200 + 250);
      expect(await File(result.filePath).exists(), isTrue);
    });

    test('全部分块不可捕获抛 DiaryExportException', () async {
      final plan = DiaryExportChunkPlan(
        totalChunks: 3,
        bodyChunkTexts: const ['正文'],
      );
      final calls = <(int, double)>[];

      await expectLater(
        buildService().export(
          plan: plan,
          baseName: 'new',
          capture: buildCapture([], calls, nullIndices: {0, 1, 2}),
        ),
        throwsA(
          isA<DiaryExportException>().having(
            (e) => e.message,
            'message',
            'No content captured',
          ),
        ),
      );
      expect(calls, hasLength(3));
    });

    test('capture 异常按契约向上传播（不包裹）', () async {
      final plan = DiaryExportChunkPlan(
        totalChunks: 3,
        bodyChunkTexts: const ['正文'],
      );
      final calls = <(int, double)>[];
      final boom = StateError('capture boom');

      await expectLater(
        buildService().export(
          plan: plan,
          baseName: 'new',
          capture: buildCapture(
            [(120, 80), (100, 90)],
            calls,
            errors: {1: boom},
          ),
        ),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', 'capture boom'),
        ),
      );
    });

    test('导出目录解析异常向上传播', () async {
      final plan = DiaryExportChunkPlan(
        totalChunks: 2,
        bodyChunkTexts: const ['正文'],
      );
      final calls = <(int, double)>[];
      final boom = StateError('dir boom');

      await expectLater(
        buildService(resolver: () async => throw boom).export(
          plan: plan,
          baseName: 'new',
          capture: buildCapture([(120, 80), (100, 90)], calls),
        ),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', 'dir boom'),
        ),
      );
    });

    test('捕获的 ui.Image 由服务消费后释放', () async {
      final plan = DiaryExportChunkPlan(
        totalChunks: 3,
        bodyChunkTexts: const ['正文'],
      );
      final images = <ui.Image>[];
      Future<ui.Image?> capture(int index, double pixelRatio) async {
        final image = await makeSolidImage(
          120 + index * 10,
          80,
          const ui.Color(0xFFE8DCC0),
        );
        images.add(image);
        return image;
      }

      await buildService().export(
        plan: plan,
        baseName: 'new',
        capture: capture,
      );

      expect(images, hasLength(3));
      for (final image in images) {
        expect(isImageDisposed(image), isTrue, reason: '服务消费完应释放 ui.Image');
      }
    });
  });
}

/// 生成 [count] 行文本（行号从 [start] 起，如 `行1\n行2`）。
String makeLines(int count, {int start = 1}) =>
    List.generate(count, (i) => '行${start + i}').join('\n');

/// 仅当断言开启（flutter test 调试模式）时读取 ui.Image.debugDisposed，
/// 断言关闭时返回 false，避免 StateError。
bool isImageDisposed(ui.Image image) {
  var disposed = false;
  assert(() {
    disposed = image.debugDisposed;
    return true;
  }());
  return disposed;
}
