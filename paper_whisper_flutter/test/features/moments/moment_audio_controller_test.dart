import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/moments/application/moment_audio_controller.dart';
import 'package:path/path.dart' as p;

/// MomentAudioController 单元测试（阶段 4 L0 组件控制器）。
///
/// 契约覆盖（与原 `moment_card._toggleAudio / _initAudio / dispose` 逐字一致）：
/// - 构造时以 initialDuration 预置展示时长；
/// - initialize 订阅 4 条插件流（state/duration/position/complete）；
/// - toggle 决策：null 路径 → noAudio；文件缺失 → missing；播放中 → pause；
///   存在 → play(DeviceFileSource(join(baseDir, audioPath)))；
/// - complete 复位 isPlaying=false 且 position 归零；
/// - 网关抛错 → sealed Failure(error)；
/// - dispose 取消订阅、释放网关，之后不再向状态流通知。
///
/// 全部经 fake 网关，无插件、无磁盘 I/O。
void main() {
  /// 收集状态流事件。
  List<MomentAudioState> collect(MomentAudioController controller) {
    final events = <MomentAudioState>[];
    controller.stateStream.listen(events.add);
    return events;
  }

  /// 冲刷 broadcast 流的异步投递。
  Future<void> flush() => pumpEventQueue();

  group('初始状态', () {
    test('initialDuration 预置展示时长', () {
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        initialDuration: const Duration(seconds: 7),
        gateway: _FakeAudioGateway(),
      );
      addTearDown(controller.dispose);

      expect(controller.state.isPlaying, isFalse);
      expect(controller.state.position, Duration.zero);
      expect(controller.state.duration, const Duration(seconds: 7));
    });

    test('无 initialDuration 时全部归零', () {
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        gateway: _FakeAudioGateway(),
      );
      addTearDown(controller.dispose);

      expect(
        controller.state,
        const MomentAudioState(
          isPlaying: false,
          position: Duration.zero,
          duration: Duration.zero,
        ),
      );
    });
  });

  group('4 条流订阅', () {
    test('playerState → isPlaying；duration / position 同步更新', () async {
      final gateway = _FakeAudioGateway();
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        gateway: gateway,
      );
      addTearDown(controller.dispose);
      final events = collect(controller);
      controller.initialize();

      gateway.emitState(PlayerState.playing);
      gateway.emitDuration(const Duration(seconds: 30));
      gateway.emitPosition(const Duration(seconds: 12));
      await flush();

      expect(controller.state.isPlaying, isTrue);
      expect(controller.state.duration, const Duration(seconds: 30));
      expect(controller.state.position, const Duration(seconds: 12));
      expect(events.last, controller.state);

      // 暂停事件同样驱动 isPlaying。
      gateway.emitState(PlayerState.paused);
      await flush();
      expect(controller.state.isPlaying, isFalse);
    });

    test('complete 复位 isPlaying=false 且 position 归零', () async {
      final gateway = _FakeAudioGateway();
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        gateway: gateway,
      );
      addTearDown(controller.dispose);
      final events = collect(controller);
      controller.initialize();

      gateway.emitState(PlayerState.playing);
      gateway.emitPosition(const Duration(seconds: 20));
      await flush();
      expect(controller.state.isPlaying, isTrue);

      gateway.emitComplete();
      await flush();

      expect(controller.state.isPlaying, isFalse);
      expect(controller.state.position, Duration.zero);
      expect(events.last.isPlaying, isFalse);
      expect(events.last.position, Duration.zero);
    });

    test('initialize 幂等：重复调用不重复订阅，4 条流各仅 1 listener', () {
      final gateway = _FakeAudioGateway();
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        gateway: gateway,
      );
      controller.initialize();
      controller.initialize();
      controller.initialize();

      expect(gateway.stateListeners, 1);
      expect(gateway.durationListeners, 1);
      expect(gateway.positionListeners, 1);
      expect(gateway.completeListeners, 1);

      controller.dispose();
      expect(gateway.stateListeners, 0);
      expect(gateway.durationListeners, 0);
      expect(gateway.positionListeners, 0);
      expect(gateway.completeListeners, 0);
    });

    test('dispose 后 initialize 抛 StateError', () {
      final gateway = _FakeAudioGateway();
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        gateway: gateway,
      );
      controller.initialize();
      controller.dispose();

      expect(() => controller.initialize(), throwsStateError);
    });
  });

  group('toggle 播放/暂停', () {
    test('未播放且文件存在 → play(DeviceFileSource(拼接路径))', () async {
      final gateway = _FakeAudioGateway()..exists = true;
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        gateway: gateway,
        pathJoiner: p.posix.join,
      );
      addTearDown(controller.dispose);
      controller.initialize();

      final result = await controller.toggle();

      expect(result, isA<MomentAudioToggleHandled>());
      expect(gateway.played, hasLength(1));
      expect(gateway.played.single.path, '/moments/audio/a.m4a');
    });

    test('播放中 → pause() 并复位 isPlaying', () async {
      final gateway = _FakeAudioGateway();
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        gateway: gateway,
      );
      addTearDown(controller.dispose);
      final events = collect(controller);
      controller.initialize();
      gateway.emitState(PlayerState.playing);
      await flush();

      final result = await controller.toggle();
      await flush();

      expect(result, isA<MomentAudioToggleHandled>());
      expect(gateway.pauseCount, 1);
      expect(gateway.played, isEmpty);
      expect(controller.state.isPlaying, isFalse);
      expect(events.last.isPlaying, isFalse);
    });
  });

  group('无音频 / 文件缺失', () {
    test('audioPath 为 null → noAudio，不触碰网关', () async {
      final gateway = _FakeAudioGateway();
      final controller = MomentAudioController(
        audioPath: null,
        baseDir: '/moments',
        gateway: gateway,
      );
      addTearDown(controller.dispose);
      controller.initialize();

      final result = await controller.toggle();

      expect(result, isA<MomentAudioToggleNoAudio>());
      expect(gateway.played, isEmpty);
      expect(gateway.pauseCount, 0);
    });

    test('baseDir 为 null → noAudio', () async {
      final gateway = _FakeAudioGateway();
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: null,
        gateway: gateway,
      );
      addTearDown(controller.dispose);
      controller.initialize();

      final result = await controller.toggle();

      expect(result, isA<MomentAudioToggleNoAudio>());
      expect(gateway.played, isEmpty);
    });

    test('文件不存在 → missing，不调用 play', () async {
      final gateway = _FakeAudioGateway()..exists = false;
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        gateway: gateway,
      );
      addTearDown(controller.dispose);
      controller.initialize();

      final result = await controller.toggle();

      expect(result, isA<MomentAudioToggleMissing>());
      expect(gateway.played, isEmpty);
    });
  });

  group('网关错误（sealed typed）', () {
    test('play 抛错 → failure(error)', () async {
      final gateway = _FakeAudioGateway()..playError = StateError('解码失败');
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        gateway: gateway,
      );
      addTearDown(controller.dispose);
      controller.initialize();

      final result = await controller.toggle();

      expect(result, isA<MomentAudioToggleFailure>());
      expect((result as MomentAudioToggleFailure).error, isA<StateError>());
      expect(result.error.toString(), contains('解码失败'));
    });

    test('pause 抛错 → failure(error)', () async {
      final gateway = _FakeAudioGateway()..pauseError = Exception('暂停失败');
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        gateway: gateway,
      );
      addTearDown(controller.dispose);
      controller.initialize();
      gateway.emitState(PlayerState.playing);
      await flush();

      final result = await controller.toggle();

      expect(result, isA<MomentAudioToggleFailure>());
      expect(
        (result as MomentAudioToggleFailure).error.toString(),
        contains('暂停失败'),
      );
    });
  });

  group('dispose', () {
    test('取消订阅、释放网关，之后的事件不再通知', () async {
      final gateway = _FakeAudioGateway();
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        gateway: gateway,
      );
      final events = collect(controller);
      controller.initialize();
      gateway.emitState(PlayerState.playing);
      await flush();
      expect(events, isNotEmpty);

      controller.dispose();
      final countAfterDispose = events.length;

      // 订阅已取消：向 fake 网关继续发射事件不应产生任何状态通知，
      // 也不得抛出异常（broadcast 到已关闭的控制器会抛 StateError）。
      gateway.emitState(PlayerState.paused);
      gateway.emitDuration(const Duration(seconds: 9));
      gateway.emitPosition(const Duration(seconds: 1));
      gateway.emitComplete();
      await flush();

      expect(gateway.disposeCount, 1);
      expect(events.length, countAfterDispose);
      expect(controller.state.isPlaying, isTrue); // 状态冻结在 dispose 前
    });

    test('未调用 initialize 时 dispose 同样安全', () {
      final gateway = _FakeAudioGateway();
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        gateway: gateway,
      );

      expect(() => controller.dispose(), returnsNormally);
      expect(gateway.disposeCount, 1);
    });
  });

  group('路径拼接（按输入风格）', () {
    test('windows joiner → 反斜杠完整路径', () async {
      final gateway = _FakeAudioGateway();
      final controller = MomentAudioController(
        audioPath: 'audio\\a.m4a',
        baseDir: 'C:\\moments',
        gateway: gateway,
        pathJoiner: p.windows.join,
      );
      addTearDown(controller.dispose);
      controller.initialize();

      final result = await controller.toggle();

      expect(result, isA<MomentAudioToggleHandled>());
      expect(gateway.played.single.path, r'C:\moments\audio\a.m4a');
    });

    test('posix joiner → 正斜杠完整路径', () async {
      final gateway = _FakeAudioGateway();
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        gateway: gateway,
        pathJoiner: p.posix.join,
      );
      addTearDown(controller.dispose);
      controller.initialize();

      final result = await controller.toggle();

      expect(result, isA<MomentAudioToggleHandled>());
      expect(gateway.played.single.path, '/moments/audio/a.m4a');
    });
  });
}

/// 内存版音频网关替身：记录调用计数与播放源，按 seam 抛错，无插件无 I/O。
class _FakeAudioGateway implements MomentAudioGateway {
  /// 当前各条流的活跃 listener 数（用于校验 initialize 幂等）。
  int stateListeners = 0;
  int durationListeners = 0;
  int positionListeners = 0;
  int completeListeners = 0;

  late final _stateController = StreamController<PlayerState>.broadcast(
    onListen: () => stateListeners++,
    onCancel: () => stateListeners--,
  );
  late final _durationController = StreamController<Duration>.broadcast(
    onListen: () => durationListeners++,
    onCancel: () => durationListeners--,
  );
  late final _positionController = StreamController<Duration>.broadcast(
    onListen: () => positionListeners++,
    onCancel: () => positionListeners--,
  );
  late final _completeController = StreamController<void>.broadcast(
    onListen: () => completeListeners++,
    onCancel: () => completeListeners--,
  );

  /// fileExists 的返回值。
  bool exists = true;

  /// 非 null 时 [play] 抛错。
  Object? playError;

  /// 非 null 时 [pause] 抛错。
  Object? pauseError;

  /// 已播放的音频源（按顺序）。
  final List<DeviceFileSource> played = <DeviceFileSource>[];

  /// pause 调用次数。
  int pauseCount = 0;

  /// dispose 调用次数。
  int disposeCount = 0;

  @override
  Stream<PlayerState> get onPlayerStateChanged => _stateController.stream;

  @override
  Stream<Duration> get onDurationChanged => _durationController.stream;

  @override
  Stream<Duration> get onPositionChanged => _positionController.stream;

  @override
  Stream<void> get onPlayerComplete => _completeController.stream;

  @override
  Future<bool> fileExists(String path) async => exists;

  @override
  Future<void> play(DeviceFileSource source) async {
    final error = playError;
    if (error != null) throw error;
    played.add(source);
  }

  @override
  Future<void> pause() async {
    final error = pauseError;
    if (error != null) throw error;
    pauseCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }

  void emitState(PlayerState state) => _stateController.add(state);

  void emitDuration(Duration duration) => _durationController.add(duration);

  void emitPosition(Duration position) => _positionController.add(position);

  void emitComplete() => _completeController.add(null);
}
