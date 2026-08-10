import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/update/application/update_download_controller.dart';
import 'package:paper_whisper_flutter/features/update/data/update_info.dart';
import 'package:paper_whisper_flutter/features/update/data/update_service.dart';

/// UpdateDownloadController 行为刻画测试。
///
/// 覆盖：
/// - start：URL 缺失（null / 平台 key 缺失）、progress 上报、成功到 downloaded；
/// - cancel：token 取消 + Dio cancel 回调回 idle；
/// - Dio 各类型错误与 FileSystemException/通用异常的逐字文案映射；
/// - install：launched / permissionDenied / unsupportedPlatform / failed 与异常；
/// - fallback：useBackup 透传；
/// - dispose：取消进行中下载，且之后不再 notify（无 ChangeNotifier 断言）。
///
/// 通过注入 [UpdateDownloadGateway] 完全绕开真实网络与 UpdateService 单例，
/// 全部用例 context-free。
void main() {
  UpdateInfo sampleInfo({
    Map<String, String>? downloadUrl = const {
      'android': 'https://example.com/app.apk',
    },
  }) {
    return UpdateInfo(
      latestVersion: '2.0.0',
      isForceUpdate: false,
      changelog: const ['修复若干问题'],
      downloadUrl: downloadUrl,
      backupUrl: const {'android': 'https://example.com/backup.apk'},
    );
  }

  DioException dioError(
    DioExceptionType type, {
    String? message,
    Object? error,
    int? statusCode,
  }) {
    final options = RequestOptions(path: 'https://example.com/app.apk');
    return DioException(
      requestOptions: options,
      type: type,
      message: message,
      error: error,
      response: statusCode != null
          ? Response<dynamic>(requestOptions: options, statusCode: statusCode)
          : null,
    );
  }

  group('start：URL 决策', () {
    test('当前平台无下载链接（null）：进入 error 态并给出提示', () async {
      final gateway = _FakeGateway(platform: 'android');
      final controller = UpdateDownloadController(gateway: gateway);

      await controller.start(sampleInfo(downloadUrl: null));

      expect(controller.state.isError, isTrue);
      expect(controller.state.error, '未找到当前平台的下载链接');
      expect(gateway.downloadCalls, 0);
      controller.dispose();
    });

    test('当前平台 key 缺失：进入 error 态，不发起下载', () async {
      final gateway = _FakeGateway(platform: 'windows');
      final controller = UpdateDownloadController(gateway: gateway);

      await controller.start(
        sampleInfo(
          downloadUrl: const {'android': 'https://example.com/app.apk'},
        ),
      );

      expect(controller.state.isError, isTrue);
      expect(controller.state.error, '未找到当前平台的下载链接');
      expect(gateway.downloadCalls, 0);
      controller.dispose();
    });

    test('有链接：进入 downloading，成功后到 downloaded 并携带路径', () async {
      final gateway = _FakeGateway();
      final controller = UpdateDownloadController(gateway: gateway);

      final future = controller.start(sampleInfo());
      expect(controller.state.isDownloading, isTrue);
      await future;

      expect(controller.state.isDownloaded, isTrue);
      expect(controller.state.path, '/tmp/update.apk');
      expect(gateway.downloadCalls, 1);
      expect(gateway.lastUrl, 'https://example.com/app.apk');
      controller.dispose();
    });

    test('progress 回调：received/total/progress 快照更新', () async {
      final gateway = _FakeGateway();
      final controller = UpdateDownloadController(gateway: gateway);

      final future = controller.start(sampleInfo());
      gateway.lastProgress?.call(10, 100);
      expect(controller.state.received, 10);
      expect(controller.state.total, 100);
      expect(controller.state.progress, closeTo(0.1, 1e-9));
      expect(controller.state.isDownloading, isTrue);

      gateway.lastProgress?.call(50, 100);
      expect(controller.state.progress, closeTo(0.5, 1e-9));

      await future;
      controller.dispose();
    });

    test('total 未知（0）：progress 为 0', () async {
      final gateway = _FakeGateway();
      final controller = UpdateDownloadController(gateway: gateway);

      final future = controller.start(sampleInfo());
      gateway.lastProgress?.call(0, 0);
      expect(controller.state.progress, 0);
      await future;
      controller.dispose();
    });
  });

  group('cancel：回 idle', () {
    test('cancel 取消 CancelToken，Dio cancel 回调将状态回置 idle', () async {
      final gateway = _FakeGateway.pending();
      final controller = UpdateDownloadController(gateway: gateway);

      final future = controller.start(sampleInfo());
      expect(controller.state.isDownloading, isTrue);

      controller.cancel();
      expect(gateway.lastCancelToken, isNotNull);
      expect(gateway.lastCancelToken!.isCancelled, isTrue);

      // 模拟 Dio 取消后的 cancel 异常回调
      gateway.completeError(dioError(DioExceptionType.cancel));
      await future;

      expect(controller.state.isIdle, isTrue);
      expect(controller.state.error, isNull);
      expect(controller.state.received, 0);
      controller.dispose();
    });
  });

  group('start：Dio 错误文案映射（逐字）', () {
    Future<String> runWithError(DioException e) async {
      final gateway = _FakeGateway(error: e);
      final controller = UpdateDownloadController(gateway: gateway);
      await controller.start(sampleInfo());
      final message = controller.state.error!;
      controller.dispose();
      return message;
    }

    test('connectionTimeout/sendTimeout/receiveTimeout：网络超时提示', () async {
      expect(
        await runWithError(dioError(DioExceptionType.connectionTimeout)),
        '网络超时，请检查网络连接后重试',
      );
      expect(
        await runWithError(dioError(DioExceptionType.sendTimeout)),
        '网络超时，请检查网络连接后重试',
      );
      expect(
        await runWithError(dioError(DioExceptionType.receiveTimeout)),
        '网络超时，请检查网络连接后重试',
      );
    });

    test('connectionError：网络连接失败提示', () async {
      expect(
        await runWithError(dioError(DioExceptionType.connectionError)),
        '网络连接失败，请检查网络设置',
      );
    });

    test('badResponse：携带状态码', () async {
      expect(
        await runWithError(
          dioError(DioExceptionType.badResponse, statusCode: 500),
        ),
        '服务器异常 (500)',
      );
    });

    test('FileSystemException：存储空间不足提示', () async {
      expect(
        await runWithError(
          dioError(
            DioExceptionType.unknown,
            error: FileSystemException('no space'),
          ),
        ),
        '存储空间不足，请清理后重试',
      );
    });

    test('其他类型：下载失败 + message', () async {
      expect(
        await runWithError(dioError(DioExceptionType.unknown, message: 'boom')),
        '下载失败: boom',
      );
    });

    test('其他类型且无 message：下载失败 + 未知错误', () async {
      expect(
        await runWithError(dioError(DioExceptionType.unknown)),
        '下载失败: 未知错误',
      );
    });

    test('非 Dio 异常：下载失败 + 异常原文', () async {
      final gateway = _FakeGateway(error: Exception('io broken'));
      final controller = UpdateDownloadController(gateway: gateway);
      await controller.start(sampleInfo());

      expect(controller.state.isError, isTrue);
      expect(controller.state.error, '下载失败: Exception: io broken');
      controller.dispose();
    });
  });

  group('install：typed 结果映射', () {
    Future<UpdateDownloadController> downloadedController(
      _FakeGateway gateway,
    ) async {
      final controller = UpdateDownloadController(gateway: gateway);
      await controller.start(sampleInfo());
      expect(controller.state.isDownloaded, isTrue);
      return controller;
    }

    test('launched：installMessage 清空', () async {
      final gateway = _FakeGateway(
        installResult: const UpdateInstallResult(UpdateInstallStatus.launched),
      );
      final controller = await downloadedController(gateway);

      await controller.install();

      expect(controller.state.isDownloaded, isTrue);
      expect(controller.state.installMessage, isNull);
      expect(gateway.installCalls, 1);
      expect(gateway.lastInstallPath, '/tmp/update.apk');
      controller.dispose();
    });

    test('permissionDenied：映射服务端 message', () async {
      final gateway = _FakeGateway(
        installResult: const UpdateInstallResult(
          UpdateInstallStatus.permissionDenied,
          message: '安装权限被拒绝',
        ),
      );
      final controller = await downloadedController(gateway);

      await controller.install();

      expect(controller.state.installMessage, '安装权限被拒绝');
      controller.dispose();
    });

    test('unsupportedPlatform：映射服务端 message', () async {
      final gateway = _FakeGateway(
        installResult: const UpdateInstallResult(
          UpdateInstallStatus.unsupportedPlatform,
          message: '当前平台不支持应用内安装',
        ),
      );
      final controller = await downloadedController(gateway);

      await controller.install();

      expect(controller.state.installMessage, '当前平台不支持应用内安装');
      controller.dispose();
    });

    test('failed 无 message：回退通用文案', () async {
      final gateway = _FakeGateway(
        installResult: const UpdateInstallResult(UpdateInstallStatus.failed),
      );
      final controller = await downloadedController(gateway);

      await controller.install();

      expect(controller.state.installMessage, '安装失败，请稍后重试');
      controller.dispose();
    });

    test('install 抛异常：回退通用文案', () async {
      final gateway = _FakeGateway(installError: Exception('open failed'));
      final controller = await downloadedController(gateway);

      await controller.install();

      expect(controller.state.installMessage, '安装失败，请稍后重试');
      controller.dispose();
    });

    test('未下载完成时 install 不动作', () async {
      final gateway = _FakeGateway();
      final controller = UpdateDownloadController(gateway: gateway);

      await controller.install();

      expect(gateway.installCalls, 0);
      controller.dispose();
    });
  });

  group('fallback：useBackup 透传', () {
    test('useBackup=false 走主链接', () async {
      final gateway = _FakeGateway();
      final controller = UpdateDownloadController(gateway: gateway);
      final info = sampleInfo();

      await controller.fallback(info);

      expect(gateway.openCalls, hasLength(1));
      expect(gateway.openCalls.single.$1, same(info));
      expect(gateway.openCalls.single.$2, isFalse);
      controller.dispose();
    });

    test('useBackup=true 走备用链接', () async {
      final gateway = _FakeGateway();
      final controller = UpdateDownloadController(gateway: gateway);

      await controller.fallback(sampleInfo(), useBackup: true);

      expect(gateway.openCalls.single.$2, isTrue);
      controller.dispose();
    });
  });

  group('dispose', () {
    test('dispose 取消进行中下载，之后 progress/完成回调不再 notify', () async {
      final gateway = _FakeGateway.pending();
      final controller = UpdateDownloadController(gateway: gateway);
      var notified = 0;
      controller.addListener(() => notified++);

      final future = controller.start(sampleInfo());
      expect(notified, 1); // downloading

      controller.dispose();
      expect(gateway.lastCancelToken!.isCancelled, isTrue);

      // dispose 后异步回调不得 notify（ChangeNotifier 会 assert）
      gateway.lastProgress?.call(10, 100);
      gateway.completeError(dioError(DioExceptionType.cancel));
      await future;
      expect(notified, 1);
    });

    test('idle 时 dispose 无副作用', () {
      final controller = UpdateDownloadController(gateway: _FakeGateway());
      controller.dispose();
    });
  });
}

/// 可驱动的下载网关替身。
class _FakeGateway implements UpdateDownloadGateway {
  _FakeGateway({
    String platform = 'android',
    this.error,
    this.installResult = const UpdateInstallResult(
      UpdateInstallStatus.launched,
    ),
    this.installError,
  }) : _platform = platform,
       _completer = null;

  _FakeGateway.pending()
    : _platform = 'android',
      installResult = const UpdateInstallResult(UpdateInstallStatus.launched),
      installError = null,
      _completer = Completer<String>();

  final String _platform;

  @override
  String get currentPlatform => _platform;

  Object? error;
  UpdateInstallResult installResult;
  Object? installError;

  int downloadCalls = 0;
  String? lastUrl;
  CancelToken? lastCancelToken;
  void Function(int received, int total)? lastProgress;
  final Completer<String>? _completer;
  int installCalls = 0;
  String? lastInstallPath;
  final List<(UpdateInfo, bool)> openCalls = [];

  @override
  Future<String> downloadUpdate({
    required String url,
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) {
    downloadCalls++;
    lastUrl = url;
    lastCancelToken = cancelToken;
    lastProgress = onProgress;
    if (error != null) {
      return Future<void>.delayed(Duration.zero).then((_) => throw error!);
    }
    final completer = _completer;
    if (completer != null) {
      return completer.future;
    }
    return Future.value('/tmp/update.apk');
  }

  @override
  Future<UpdateInstallResult> installUpdate(String filePath) async {
    installCalls++;
    lastInstallPath = filePath;
    if (installError != null) throw installError!;
    return installResult;
  }

  @override
  Future<bool> openDownloadUrl(
    UpdateInfo updateInfo, {
    bool useBackup = false,
  }) async {
    openCalls.add((updateInfo, useBackup));
    return true;
  }

  void completeError(Object error) {
    _completer?.completeError(error);
  }
}
