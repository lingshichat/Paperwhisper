import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/export/data/export_path_resolver.dart';
import 'package:path/path.dart' as path;

/// ExportPathResolver 单元测试（阶段 4 L0 第一批）。
///
/// 契约覆盖：
/// - 四种路径分支：Android 授权、Android 未授权外部目录、
///   Android 兜底 documents、非 Android documents，断言 [Directory.path]；
/// - 全部依赖通过构造 seam 注入，测试内不触碰 permission_handler /
///   path_provider 等任何插件（各 seam 计数断言调用与否）；
/// - 三个依赖 seam 的异常按契约原样向上传播。
///
/// 纯逻辑测试，无真实 IO、无等待、无平台 channel。
void main() {
  group('ExportPathResolver 四分支', () {
    test(
      '非 Android：documents/PaperWhisper_Exports（desktopDocuments）',
      () async {
        final documents = Directory('C:/fake/documents');
        var documentsCalls = 0;
        var grantedCalls = 0;
        var extCalls = 0;

        final dir = await ExportPathResolver(
          isAndroid: () => false,
          applicationDocumentsDirectory: () async {
            documentsCalls++;
            return documents;
          },
          isManageExternalStorageGranted: () async {
            grantedCalls++;
            return true;
          },
          externalStorageDirectory: () async {
            extCalls++;
            return Directory('C:/fake/ext');
          },
        ).resolve();

        expect(dir.path, path.join(documents.path, 'PaperWhisper_Exports'));
        // 非 Android 分支不触碰授权与外部目录 seam（即不触碰插件默认实现）
        expect(documentsCalls, 1);
        expect(grantedCalls, 0);
        expect(extCalls, 0);
      },
    );

    test(
      'Android 已授权：/storage/emulated/0/Pictures/PaperWhisper（androidPublicPictures）',
      () async {
        var documentsCalls = 0;
        var grantedCalls = 0;
        var extCalls = 0;

        final dir = await ExportPathResolver(
          isAndroid: () => true,
          applicationDocumentsDirectory: () async {
            documentsCalls++;
            return Directory('/data/user/0/app/files');
          },
          isManageExternalStorageGranted: () async {
            grantedCalls++;
            return true;
          },
          externalStorageDirectory: () async {
            extCalls++;
            return Directory('/storage/emulated/0/Android/data/app');
          },
        ).resolve();

        expect(dir.path, '/storage/emulated/0/Pictures/PaperWhisper');
        // 授权分支：documents 仍先解析，授权 seam 被查询，外部目录不查询
        expect(documentsCalls, 1);
        expect(grantedCalls, 1);
        expect(extCalls, 0);
      },
    );

    test('Android 未授权但有外部目录：external/Exports（androidAppExternal）', () async {
      final extDir = Directory('/storage/emulated/0/Android/data/com.example');
      final dir = await ExportPathResolver(
        isAndroid: () => true,
        applicationDocumentsDirectory: () async =>
            Directory('/data/user/0/app/files'),
        isManageExternalStorageGranted: () async => false,
        externalStorageDirectory: () async => extDir,
      ).resolve();

      expect(dir.path, path.join(extDir.path, 'Exports'));
    });

    test(
      'Android 未授权且无外部目录：documents/Exports 兜底（androidDocumentsFallback）',
      () async {
        final documents = Directory('/data/user/0/app/files');
        final dir = await ExportPathResolver(
          isAndroid: () => true,
          applicationDocumentsDirectory: () async => documents,
          isManageExternalStorageGranted: () async => false,
          externalStorageDirectory: () async => null,
        ).resolve();

        expect(dir.path, path.join(documents.path, 'Exports'));
      },
    );
  });

  group('依赖 seam 异常传播', () {
    test('applicationDocumentsDirectory 异常向上传播（非 Android）', () async {
      await expectLater(
        ExportPathResolver(
          isAndroid: () => false,
          applicationDocumentsDirectory: () async =>
              throw StateError('doc boom'),
        ).resolve(),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', 'doc boom'),
        ),
      );
    });

    test('isManageExternalStorageGranted 异常向上传播（Android）', () async {
      await expectLater(
        ExportPathResolver(
          isAndroid: () => true,
          applicationDocumentsDirectory: () async => Directory('/d'),
          isManageExternalStorageGranted: () async =>
              throw StateError('granted boom'),
        ).resolve(),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', 'granted boom'),
        ),
      );
    });

    test('externalStorageDirectory 异常向上传播（Android 未授权）', () async {
      await expectLater(
        ExportPathResolver(
          isAndroid: () => true,
          applicationDocumentsDirectory: () async => Directory('/d'),
          isManageExternalStorageGranted: () async => false,
          externalStorageDirectory: () async => throw StateError('ext boom'),
        ).resolve(),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', 'ext boom'),
        ),
      );
    });
  });
}
