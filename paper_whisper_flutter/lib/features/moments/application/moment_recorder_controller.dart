import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// 录音状态（typed，context-free，immutable）。
///
/// 与原 `moment_input_widget` 的
/// `_isRecording / _audioPath / _recordDuration / _isPreviewPlaying`
/// 四个字段一一对应，只读不可变。
class MomentRecorderState {
  const MomentRecorderState({
    required this.isRecording,
    required this.audioPath,
    required this.recordDuration,
    required this.isPreviewPlaying,
  });

  const MomentRecorderState.idle()
    : isRecording = false,
      audioPath = null,
      recordDuration = Duration.zero,
      isPreviewPlaying = false;

  final bool isRecording;

  /// 已保存的录音文件路径；null 表示当前无可用音频。
  final String? audioPath;

  final Duration recordDuration;

  final bool isPreviewPlaying;

  MomentRecorderState copyWith({
    bool? isRecording,
    Object? audioPath = _unset,
    Duration? recordDuration,
    bool? isPreviewPlaying,
  }) {
    return MomentRecorderState(
      isRecording: isRecording ?? this.isRecording,
      audioPath: identical(audioPath, _unset)
          ? this.audioPath
          : audioPath as String?,
      recordDuration: recordDuration ?? this.recordDuration,
      isPreviewPlaying: isPreviewPlaying ?? this.isPreviewPlaying,
    );
  }

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) =>
      other is MomentRecorderState &&
      other.isRecording == isRecording &&
      other.audioPath == audioPath &&
      other.recordDuration == recordDuration &&
      other.isPreviewPlaying == isPreviewPlaying;

  @override
  int get hashCode =>
      Object.hash(isRecording, audioPath, recordDuration, isPreviewPlaying);
}

/// 录音动作结果（sealed typed outcome）。
///
/// 由页面消费并翻译为用户反馈（权限 Toast 等）；本类型不携带任何
/// UI 依赖。对应原 `moment_input_widget` 的三个出口：
/// - 无权限 → [MomentRecorderPermissionDenied]（原 "请授予麦克风权限" Toast）；
/// - 正常执行 → [MomentRecorderHandled]；
/// - 网关抛错 → [MomentRecorderFailure]（原 `debugPrint` 分支）。
sealed class MomentRecorderResult {
  const MomentRecorderResult();
}

/// 麦克风权限被拒绝：页面应展示权限提示。
class MomentRecorderPermissionDenied extends MomentRecorderResult {
  const MomentRecorderPermissionDenied();
}

/// 动作已执行（含"无音频可预览"等静默场景）。
class MomentRecorderHandled extends MomentRecorderResult {
  const MomentRecorderHandled();
}

/// 网关调用失败。
class MomentRecorderFailure extends MomentRecorderResult {
  const MomentRecorderFailure(this.error);

  final Object error;
}

/// 录音/预览/临时目录/时钟网关（窄适配层，隔离插件 API）。
///
/// [MomentRecorderController] 只依赖本接口；测试注入 fake 即可覆盖全部
/// 行为（无插件、无磁盘 I/O）。生产实现 [MomentRecorderGatewayImpl]
/// 逐字复用 `moment_input_widget` 的调用方式：
/// `AudioRecorder.start(RecordConfig(), path)`、
/// `AudioPlayer.play(DeviceFileSource(path))`、`getTemporaryDirectory()`。
abstract interface class MomentRecorderGateway {
  /// 麦克风权限（原 `_audioRecorder.hasPermission()`）。
  Future<bool> hasPermission();

  /// 以 `temp_record_<millis>.m4a` 路径开始录音。
  Future<void> startRecording(String path);

  /// 停止录音并返回已写入的文件路径。
  Future<String?> stopRecording();

  /// 临时目录路径（原 `getTemporaryDirectory()`）。
  Future<String> tempDirectoryPath();

  /// 当前时间（文件名毫秒时间戳来源，测试可注入固定值）。
  DateTime now();

  Future<void> playPreview(String path);

  Future<void> pausePreview();

  Stream<PlayerState> get previewStateStream;

  Stream<void> get previewCompleteStream;

  Future<void> disposeRecorder();

  Future<void> disposePlayer();
}

/// 生产网关：直接适配 [AudioRecorder] / [AudioPlayer] / path_provider。
class MomentRecorderGatewayImpl implements MomentRecorderGateway {
  MomentRecorderGatewayImpl({
    AudioRecorder? recorder,
    AudioPlayer? player,
    DateTime Function()? clock,
  }) : _recorder = recorder ?? AudioRecorder(),
       _player = player ?? AudioPlayer(),
       _clock = clock ?? DateTime.now;

  final AudioRecorder _recorder;
  final AudioPlayer _player;
  final DateTime Function() _clock;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> startRecording(String path) =>
      _recorder.start(const RecordConfig(), path: path);

  @override
  Future<String?> stopRecording() => _recorder.stop();

  @override
  Future<String> tempDirectoryPath() async =>
      (await getTemporaryDirectory()).path;

  @override
  DateTime now() => _clock();

  @override
  Future<void> playPreview(String path) => _player.play(DeviceFileSource(path));

  @override
  Future<void> pausePreview() => _player.pause();

  @override
  Stream<PlayerState> get previewStateStream => _player.onPlayerStateChanged;

  @override
  Stream<void> get previewCompleteStream => _player.onPlayerComplete;

  @override
  Future<void> disposeRecorder() => _recorder.dispose();

  @override
  Future<void> disposePlayer() => _player.dispose();
}

/// 随心记录音控制器（context-free）。
///
/// 持有录音/预览状态机与音频标题输入，不持有 BuildContext、不直接构建
/// Widget、不做 Toast/Dialog/动画：
/// - [start]：权限 → 临时目录拼 `temp_record_<millis>.m4a` → 开始录音，
///   并订阅可注入的 tick 流每秒 `recordDuration + 1s`；
/// - [stop]：取回路径并停止计时；[cancel]：停止但不保存路径、时长归零；
/// - [deleteAudio] / [clearAfterSend]：清理路径/标题/时长（后者同时复位
///   预览标记，复刻原 `_handleSend` 的清理段）；
/// - [togglePreview]：`play(DeviceFileSource(path))` / `pause()`，播放状态
///   由 [previewStateStream] 与 [previewCompleteStream] 驱动；
/// - [initialize] 幂等订阅预览两条插件流；[dispose] 取消 tick 与两条预览
///   订阅，释放 recorder/player/title，此后不再向状态流通知。
///
/// 原 `moment_input_widget` 录音/预览部分的纯逻辑，UI（按钮、磁带动画、
/// 权限 Toast）留在展示层消费状态流与 sealed 结果。
class MomentRecorderController {
  MomentRecorderController({
    MomentRecorderGateway? gateway,
    Stream<void>? tickStream,
  }) : _gateway = gateway ?? MomentRecorderGatewayImpl(),
       _tickStream =
           tickStream ??
           Stream<void>.periodic(const Duration(seconds: 1), (_) {});

  final MomentRecorderGateway _gateway;

  /// 每秒触发一次的计时流（生产默认 [Stream.periodic]，测试注入 fake）。
  final Stream<void> _tickStream;

  /// 音频标题输入（原 `_audioTitleController`；属主归本控制器，dispose 释放）。
  final TextEditingController audioTitleController = TextEditingController();

  MomentRecorderState _state = const MomentRecorderState.idle();
  bool _disposed = false;
  bool _initialized = false;

  StreamSubscription<void>? _tickSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;

  final StreamController<MomentRecorderState> _stateController =
      StreamController<MomentRecorderState>.broadcast();

  /// 当前录音状态（同步可读，不依赖流事件）。
  MomentRecorderState get state => _state;

  /// 状态变化流（broadcast，dispose 后不再发出任何事件）。
  Stream<MomentRecorderState> get stateStream => _stateController.stream;

  /// 订阅预览两条插件流。调用方在页面生命周期内调用一次；重复调用幂等，
  /// dispose 后再调用抛 [StateError]。
  void initialize() {
    if (_disposed) {
      throw StateError('MomentRecorderController 已释放，不能再次 initialize');
    }
    if (_initialized) {
      return;
    }
    _initialized = true;
    _stateSub = _gateway.previewStateStream.listen((playerState) {
      _emit(
        _state.copyWith(isPreviewPlaying: playerState == PlayerState.playing),
      );
    });
    _completeSub = _gateway.previewCompleteStream.listen((_) {
      _emit(_state.copyWith(isPreviewPlaying: false));
    });
  }

  /// 开始录音。权限被拒 → [MomentRecorderPermissionDenied]；
  /// 已在录制中 → [MomentRecorderHandled] 且不重复启动。
  Future<MomentRecorderResult> start() async {
    if (_state.isRecording) {
      return const MomentRecorderHandled();
    }
    try {
      if (!await _gateway.hasPermission()) {
        return const MomentRecorderPermissionDenied();
      }
      final dir = await _gateway.tempDirectoryPath();
      final path =
          '$dir/temp_record_${_gateway.now().millisecondsSinceEpoch}.m4a';
      await _gateway.startRecording(path);

      _emit(_state.copyWith(isRecording: true, recordDuration: Duration.zero));
      _tickSub?.cancel();
      _tickSub = _tickStream.listen((_) {
        _emit(
          _state.copyWith(
            recordDuration: _state.recordDuration + const Duration(seconds: 1),
          ),
        );
      });
      return const MomentRecorderHandled();
    } catch (e) {
      debugPrint('Start recording error: $e');
      return MomentRecorderFailure(e);
    }
  }

  /// 停止录音并保存路径。未在录制中 → [MomentRecorderHandled]。
  Future<MomentRecorderResult> stop() async {
    if (!_state.isRecording) {
      return const MomentRecorderHandled();
    }
    try {
      final path = await _gateway.stopRecording();
      _tickSub?.cancel();
      _tickSub = null;
      _emit(_state.copyWith(isRecording: false, audioPath: path));
      return const MomentRecorderHandled();
    } catch (e) {
      debugPrint('Stop recording error: $e');
      return MomentRecorderFailure(e);
    }
  }

  /// 取消录音：停止但不保存本次路径、时长归零；已有 audioPath 保持不变。
  Future<MomentRecorderResult> cancel() async {
    if (!_state.isRecording) {
      return const MomentRecorderHandled();
    }
    try {
      await _gateway.stopRecording();
      _tickSub?.cancel();
      _tickSub = null;
      _emit(_state.copyWith(isRecording: false, recordDuration: Duration.zero));
      return const MomentRecorderHandled();
    } catch (e) {
      debugPrint('Cancel recording error: $e');
      return MomentRecorderFailure(e);
    }
  }

  /// 删除当前音频：清空路径、标题与时长（复刻原 `_deleteAudio`）。
  void deleteAudio() {
    audioTitleController.clear();
    _emit(_state.copyWith(audioPath: null, recordDuration: Duration.zero));
  }

  /// 切换预览播放/暂停。无音频路径 → [MomentRecorderHandled] 且不播放。
  Future<MomentRecorderResult> togglePreview() async {
    final path = _state.audioPath;
    if (path == null) {
      return const MomentRecorderHandled();
    }
    try {
      if (_state.isPreviewPlaying) {
        await _gateway.pausePreview();
      } else {
        await _gateway.playPreview(path);
      }
      return const MomentRecorderHandled();
    } catch (e) {
      debugPrint('Preview toggle error: $e');
      return MomentRecorderFailure(e);
    }
  }

  /// 发送后清理（复刻原 `_handleSend` 的音频清理段）：
  /// 清标题、路径、时长与预览标记。
  void clearAfterSend() {
    audioTitleController.clear();
    _emit(
      _state.copyWith(
        audioPath: null,
        recordDuration: Duration.zero,
        isPreviewPlaying: false,
      ),
    );
  }

  /// 取消 tick 与两条预览订阅，释放 recorder/player/title 并关闭状态流。
  /// 此后不再向状态流通知（晚到事件因订阅已取消而自然丢弃）。
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _tickSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    _gateway.disposeRecorder();
    _gateway.disposePlayer();
    audioTitleController.dispose();
    _stateController.close();
  }

  void _emit(MomentRecorderState next) {
    if (_stateController.isClosed) {
      return;
    }
    _state = next;
    _stateController.add(next);
  }
}
