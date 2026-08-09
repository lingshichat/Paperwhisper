import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/moments/application/moment_recorder_controller.dart';

/// MomentRecorderController 单元测试（阶段 4 L6 组件控制器）。
///
/// 契约覆盖（与原 `moment_input_widget` 录音/预览段逐字一致）：
/// - start：权限拒绝 → PermissionDenied；授权 → 临时目录 +
///   `temp_record_<millis>.m4a`（clock 可注入）→ RecordConfig start；
/// - tick：可注入 tick 流每秒 recordDuration +1s，stop/cancel 后停止累计；
/// - stop 保存路径；cancel 不保存路径且时长归零、旧路径保留；
/// - deleteAudio / clearAfterSend 清理路径/标题/时长/预览标记；
/// - togglePreview：无音频静默 handled；播放中 pause，否则
///   play(DeviceFileSource(path))；previewState/complete 驱动预览标记；
/// - 网关抛错 → sealed Failure；dispose 取消 tick + 2 条预览订阅并释放
///   recorder/player/title，之后晚到事件不崩溃、不再通知状态流。
///
/// 全部经 fake 网关，无插件、无磁盘 I/O。
void main() {
  /// 收集状态流事件。
  List<MomentRecorderState> collect(MomentRecorderController controller) {
    final events = <MomentRecorderState>[];
    controller.stateStream.listen(events.add);
    return events;
  }

  /// 冲刷 broadcast 流的异步投递。
  Future<void> flush() => pumpEventQueue();

  MomentRecorderController build(
    _FakeRecorderGateway gateway, {
    Stream<void>? ticks,
    bool initialize = true,
  }) {
    final controller = MomentRecorderController(
      gateway: gateway,
      tickStream: ticks,
    );
    if (initialize) {
      controller.initialize();
    }
    addTearDown(controller.dispose);
    return controller;
  }

  group('初始状态', () {
    test('idle：全部归零', () {
      final controller = build(_FakeRecorderGateway());
      expect(controller.state, const MomentRecorderState.idle());
      expect(controller.state.isRecording, isFalse);
      expect(controller.state.audioPath, isNull);
      expect(controller.state.recordDuration, Duration.zero);
      expect(controller.state.isPreviewPlaying, isFalse);
    });
  });

  group('start', () {
    test('无权限 → PermissionDenied，不启动、状态不变', () async {
      final gateway = _FakeRecorderGateway()..permission = false;
      final controller = build(gateway);

      final result = await controller.start();

      expect(result, isA<MomentRecorderPermissionDenied>());
      expect(controller.state, const MomentRecorderState.idle());
      expect(gateway.startedPaths, isEmpty);
    });

    test('授权后 start：临时目录 + clock 毫秒时间戳拼路径', () async {
      final gateway = _FakeRecorderGateway()
        ..tempDir = '/tmp'
        ..nowValue = DateTime.fromMillisecondsSinceEpoch(123456789);
      final controller = build(gateway);
      final events = collect(controller);

      final result = await controller.start();

      expect(result, isA<MomentRecorderHandled>());
      expect(gateway.startedPaths, ['/tmp/temp_record_123456789.m4a']);
      expect(controller.state.isRecording, isTrue);
      expect(controller.state.recordDuration, Duration.zero);
      // 事件序：启动即发出 recording + duration 0（broadcast 异步投递需冲刷）
      await flush();
      expect(events.last.isRecording, isTrue);
      expect(events.last.recordDuration, Duration.zero);
    });

    test('录制中重复 start 幂等：不重复启动', () async {
      final gateway = _FakeRecorderGateway();
      final controller = build(gateway);

      await controller.start();
      final result = await controller.start();

      expect(result, isA<MomentRecorderHandled>());
      expect(gateway.startedPaths, hasLength(1));
    });

    test('权限查询抛错 → Failure', () async {
      final gateway = _FakeRecorderGateway()
        ..permissionError = StateError('boom');
      final controller = build(gateway);

      final result = await controller.start();

      expect(result, isA<MomentRecorderFailure>());
      expect((result as MomentRecorderFailure).error, isA<StateError>());
      expect(controller.state, const MomentRecorderState.idle());
    });

    test('start 抛错 → Failure，状态不变', () async {
      final gateway = _FakeRecorderGateway()..startError = Exception('io');
      final controller = build(gateway);

      final result = await controller.start();

      expect(result, isA<MomentRecorderFailure>());
      expect(controller.state, const MomentRecorderState.idle());
    });
  });

  group('tick 计时', () {
    test('start 后每个 tick duration +1s', () async {
      final gateway = _FakeRecorderGateway();
      final ticks = StreamController<void>.broadcast();
      final controller = build(gateway, ticks: ticks.stream);
      final events = collect(controller);

      await controller.start();
      ticks.add(null);
      ticks.add(null);
      ticks.add(null);
      await flush();

      expect(controller.state.recordDuration, const Duration(seconds: 3));
      expect(events.last.recordDuration, const Duration(seconds: 3));
      await ticks.close();
    });

    test('stop 后 tick 不再累计', () async {
      final gateway = _FakeRecorderGateway();
      final ticks = StreamController<void>.broadcast();
      final controller = build(gateway, ticks: ticks.stream);

      await controller.start();
      ticks.add(null);
      await flush();
      await controller.stop();
      final afterStop = controller.state.recordDuration;

      ticks.add(null);
      ticks.add(null);
      await flush();

      expect(afterStop, const Duration(seconds: 1));
      expect(controller.state.recordDuration, const Duration(seconds: 1));
      await ticks.close();
    });

    test('cancel 后 tick 不再累计', () async {
      final gateway = _FakeRecorderGateway();
      final ticks = StreamController<void>.broadcast();
      final controller = build(gateway, ticks: ticks.stream);

      await controller.start();
      ticks.add(null);
      await flush();
      await controller.cancel();

      ticks.add(null);
      await flush();

      expect(controller.state.recordDuration, Duration.zero);
      await ticks.close();
    });
  });

  group('stop / cancel', () {
    test('stop 保存路径并结束录制', () async {
      final gateway = _FakeRecorderGateway()..stopResult = '/tmp/recorded.m4a';
      final controller = build(gateway);

      await controller.start();
      final result = await controller.stop();

      expect(result, isA<MomentRecorderHandled>());
      expect(controller.state.isRecording, isFalse);
      expect(controller.state.audioPath, '/tmp/recorded.m4a');
    });

    test('stop 未在录制 → handled，无副作用', () async {
      final gateway = _FakeRecorderGateway();
      final controller = build(gateway);

      final result = await controller.stop();

      expect(result, isA<MomentRecorderHandled>());
      expect(gateway.stopCalls, 0);
    });

    test('stop 抛错 → Failure', () async {
      final gateway = _FakeRecorderGateway()..stopError = Exception('io');
      final controller = build(gateway);

      await controller.start();
      final result = await controller.stop();

      expect(result, isA<MomentRecorderFailure>());
      expect(controller.state.isRecording, isTrue);
    });

    test('cancel 不保存路径、时长归零', () async {
      final gateway = _FakeRecorderGateway();
      final controller = build(gateway);

      await controller.start();
      final result = await controller.cancel();

      expect(result, isA<MomentRecorderHandled>());
      expect(controller.state.isRecording, isFalse);
      expect(controller.state.audioPath, isNull);
      expect(controller.state.recordDuration, Duration.zero);
    });

    test('cancel 保留之前已保存的路径', () async {
      final gateway = _FakeRecorderGateway()..stopResult = '/tmp/old.m4a';
      final controller = build(gateway);

      await controller.start();
      await controller.stop();
      await controller.start();
      await controller.cancel();

      expect(controller.state.audioPath, '/tmp/old.m4a');
      expect(controller.state.recordDuration, Duration.zero);
    });
  });

  group('deleteAudio / clearAfterSend', () {
    test('deleteAudio 清空路径/标题/时长', () async {
      final gateway = _FakeRecorderGateway()..stopResult = '/tmp/recorded.m4a';
      final controller = build(gateway);

      await controller.start();
      await controller.stop();
      controller.audioTitleController.text = '标题';
      controller.deleteAudio();

      expect(controller.state.audioPath, isNull);
      expect(controller.state.recordDuration, Duration.zero);
      expect(controller.audioTitleController.text, isEmpty);
    });

    test('clearAfterSend 复刻发送后清理：audio/title/duration/preview', () async {
      final gateway = _FakeRecorderGateway()..stopResult = '/tmp/recorded.m4a';
      final controller = build(gateway);
      await controller.start();
      await controller.stop();
      controller.audioTitleController.text = '语音随记';

      // 模拟预览播放中
      gateway.emitState(PlayerState.playing);
      await flush();
      expect(controller.state.isPreviewPlaying, isTrue);

      controller.clearAfterSend();

      expect(controller.state.audioPath, isNull);
      expect(controller.state.recordDuration, Duration.zero);
      expect(controller.state.isPreviewPlaying, isFalse);
      expect(controller.audioTitleController.text, isEmpty);
    });

    test('clearAfterSend 在 idle 状态幂等', () {
      final controller = build(_FakeRecorderGateway());
      controller.clearAfterSend();
      expect(controller.state, const MomentRecorderState.idle());
    });
  });

  group('preview', () {
    test('无音频 → handled 且不播放', () async {
      final gateway = _FakeRecorderGateway();
      final controller = build(gateway);

      final result = await controller.togglePreview();

      expect(result, isA<MomentRecorderHandled>());
      expect(gateway.playCalls, isEmpty);
    });

    test('togglePreview 播放 DeviceFileSource(path)', () async {
      final gateway = _FakeRecorderGateway()..stopResult = '/tmp/recorded.m4a';
      final controller = build(gateway);
      await controller.start();
      await controller.stop();

      final result = await controller.togglePreview();

      expect(result, isA<MomentRecorderHandled>());
      expect(gateway.playCalls, ['/tmp/recorded.m4a']);
      expect(gateway.pauseCalls, 0);
    });

    test('播放中 toggle → pause', () async {
      final gateway = _FakeRecorderGateway()..stopResult = '/tmp/recorded.m4a';
      final controller = build(gateway);
      await controller.start();
      await controller.stop();
      gateway.emitState(PlayerState.playing);
      await flush();
      expect(controller.state.isPreviewPlaying, isTrue);

      final result = await controller.togglePreview();

      expect(result, isA<MomentRecorderHandled>());
      expect(gateway.pauseCalls, 1);
      expect(gateway.playCalls, isEmpty);
    });

    test('previewState 驱动预览标记：playing → true，其它 → false', () async {
      final gateway = _FakeRecorderGateway();
      final controller = build(gateway);

      gateway.emitState(PlayerState.playing);
      await flush();
      expect(controller.state.isPreviewPlaying, isTrue);

      gateway.emitState(PlayerState.paused);
      await flush();
      expect(controller.state.isPreviewPlaying, isFalse);
    });

    test('complete 事件复位预览标记', () async {
      final gateway = _FakeRecorderGateway();
      final controller = build(gateway);

      gateway.emitState(PlayerState.playing);
      await flush();
      gateway.emitComplete();
      await flush();

      expect(controller.state.isPreviewPlaying, isFalse);
    });

    test('play 抛错 → Failure', () async {
      final gateway = _FakeRecorderGateway()
        ..stopResult = '/tmp/recorded.m4a'
        ..playError = Exception('player');
      final controller = build(gateway);
      await controller.start();
      await controller.stop();

      final result = await controller.togglePreview();

      expect(result, isA<MomentRecorderFailure>());
    });
  });

  group('initialize / dispose', () {
    test('initialize 幂等：重复调用只订阅一次', () {
      final gateway = _FakeRecorderGateway();
      final controller = build(gateway);

      controller.initialize();
      controller.initialize();

      expect(gateway.stateListenCount, 1);
      expect(gateway.completeListenCount, 1);
    });

    test('dispose 释放 recorder/player/title', () {
      final gateway = _FakeRecorderGateway();
      final controller = build(gateway);
      controller.dispose();

      expect(gateway.recorderDisposed, isTrue);
      expect(gateway.playerDisposed, isTrue);
      // title controller 已释放：再注册监听会抛错
      expect(
        () => controller.audioTitleController.addListener(() {}),
        throwsFlutterError,
      );
    });

    test('dispose 取消 tick 订阅：晚到 tick 不再累计、不崩溃', () async {
      final gateway = _FakeRecorderGateway();
      final ticks = StreamController<void>.broadcast();
      final controller = build(gateway, ticks: ticks.stream);

      await controller.start();
      final controllerCopy = controller;
      controller.dispose();

      ticks.add(null);
      ticks.add(null);
      await flush();

      expect(controllerCopy.state.recordDuration, Duration.zero);
      await ticks.close();
    });

    test('dispose 取消预览订阅：晚到 gateway 事件不崩溃、状态不变', () async {
      final gateway = _FakeRecorderGateway();
      final controller = build(gateway);
      controller.dispose();

      gateway.emitState(PlayerState.playing);
      gateway.emitComplete();
      await flush();

      expect(controller.state.isPreviewPlaying, isFalse);
    });

    test('dispose 后再次 dispose 幂等', () {
      final gateway = _FakeRecorderGateway();
      final controller = build(gateway);
      controller.dispose();
      expect(() => controller.dispose(), returnsNormally);
    });

    test('dispose 后 initialize 抛 StateError', () {
      final gateway = _FakeRecorderGateway();
      final controller = build(gateway, initialize: false);
      controller.dispose();

      expect(() => controller.initialize(), throwsStateError);
    });
  });
}

/// fake 网关：无插件、无磁盘 I/O，可编程权限/错误/时间，可主动发预览事件。
class _FakeRecorderGateway implements MomentRecorderGateway {
  bool permission = true;
  Object? permissionError;
  Object? startError;
  Object? stopError;
  Object? playError;

  String tempDir = '/tmp';
  DateTime nowValue = DateTime(2026, 1, 1, 12, 0, 0);
  String? stopResult = '/tmp/temp_record_0.m4a';

  final List<String> startedPaths = [];
  final List<String> playCalls = [];
  int pauseCalls = 0;
  int stopCalls = 0;
  int stateListenCount = 0;
  int completeListenCount = 0;
  bool recorderDisposed = false;
  bool playerDisposed = false;

  final StreamController<PlayerState> _stateCtrl =
      StreamController<PlayerState>.broadcast();
  final StreamController<void> _completeCtrl =
      StreamController<void>.broadcast();

  void emitState(PlayerState state) => _stateCtrl.add(state);

  void emitComplete() => _completeCtrl.add(null);

  @override
  Future<bool> hasPermission() async {
    if (permissionError != null) {
      throw permissionError!;
    }
    return permission;
  }

  @override
  Future<void> startRecording(String path) async {
    if (startError != null) {
      throw startError!;
    }
    startedPaths.add(path);
  }

  @override
  Future<String?> stopRecording() async {
    stopCalls += 1;
    if (stopError != null) {
      throw stopError!;
    }
    return stopResult;
  }

  @override
  Future<String> tempDirectoryPath() async => tempDir;

  @override
  DateTime now() => nowValue;

  @override
  Future<void> playPreview(String path) async {
    if (playError != null) {
      throw playError!;
    }
    playCalls.add(path);
  }

  @override
  Future<void> pausePreview() async {
    pauseCalls += 1;
  }

  @override
  Stream<PlayerState> get previewStateStream {
    stateListenCount += 1;
    return _stateCtrl.stream;
  }

  @override
  Stream<void> get previewCompleteStream {
    completeListenCount += 1;
    return _completeCtrl.stream;
  }

  @override
  Future<void> disposeRecorder() async {
    recorderDisposed = true;
  }

  @override
  Future<void> disposePlayer() async {
    playerDisposed = true;
  }
}
