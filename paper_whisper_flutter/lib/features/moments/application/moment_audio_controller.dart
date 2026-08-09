import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;

/// 音频播放状态（typed，context-free）。
///
/// 与原 `moment_card._isPlaying / _audioPosition / _audioDuration`
/// 三个字段一一对应，只读不可变。
class MomentAudioState {
  const MomentAudioState({
    required this.isPlaying,
    required this.position,
    required this.duration,
  });

  const MomentAudioState.idle()
    : isPlaying = false,
      position = Duration.zero,
      duration = Duration.zero;

  final bool isPlaying;
  final Duration position;
  final Duration duration;

  MomentAudioState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
  }) {
    return MomentAudioState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

/// 切换播放结果（sealed typed outcome）。
///
/// 由页面消费并翻译为用户反馈（音频文件丢失 Toast 等）；本类型不携带
/// 任何 UI 依赖。
sealed class MomentAudioToggleResult {
  const MomentAudioToggleResult();
}

/// 无音频（audioPath 或 baseDir 缺失）：不播放也不提示。
class MomentAudioToggleNoAudio extends MomentAudioToggleResult {
  const MomentAudioToggleNoAudio();
}

/// 音频文件不存在（原 "音频文件丢失" Toast 场景）。
class MomentAudioToggleMissing extends MomentAudioToggleResult {
  const MomentAudioToggleMissing();
}

/// 播放/暂停已执行。
class MomentAudioToggleHandled extends MomentAudioToggleResult {
  const MomentAudioToggleHandled();
}

/// 网关调用失败（play / pause / exists 抛错）。
class MomentAudioToggleFailure extends MomentAudioToggleResult {
  const MomentAudioToggleFailure(this.error);

  final Object error;
}

/// 音频播放网关（窄适配层，隔离 audioplayers 插件 API）。
///
/// [MomentAudioController] 只依赖本接口，测试注入 fake 即可覆盖全部
/// 行为；生产实现 [AudioPlayerGateway] 逐字复用 `moment_card` 的
/// `play(DeviceFileSource(...))` / `pause()` 调用方式。
abstract interface class MomentAudioGateway {
  Stream<PlayerState> get onPlayerStateChanged;

  Stream<Duration> get onDurationChanged;

  Stream<Duration> get onPositionChanged;

  Stream<void> get onPlayerComplete;

  /// 文件存在性判断（I/O seam，测试注入 fake 后无真实磁盘访问）。
  Future<bool> fileExists(String path);

  Future<void> play(DeviceFileSource source);

  Future<void> pause();

  Future<void> dispose();
}

/// 生产网关：直接适配 [AudioPlayer]，文件存在性走 `dart:io`。
class AudioPlayerGateway implements MomentAudioGateway {
  AudioPlayerGateway(this._player);

  final AudioPlayer _player;

  @override
  Stream<PlayerState> get onPlayerStateChanged => _player.onPlayerStateChanged;

  @override
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;

  @override
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;

  @override
  Stream<void> get onPlayerComplete => _player.onPlayerComplete;

  @override
  Future<bool> fileExists(String path) => File(path).exists();

  @override
  Future<void> play(DeviceFileSource source) => _player.play(source);

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> dispose() => _player.dispose();
}

/// 随心记音频播放控制器（context-free）。
///
/// 持有播放状态机（isPlaying / position / duration）与 4 条插件流的订阅
/// 生命周期，不持有 BuildContext、不直接构建 Widget：
/// - [initialize] 订阅 playerState / duration / position / complete；
/// - [toggle] 按"无音频 → 文件缺失 → 播放/暂停 → 失败"决策，路径经
///   `path.join` 拼接（可注入 joiner 以覆盖 Windows/posix 风格）；
/// - complete 事件将 isPlaying 复位为 false、position 归零；
/// - [dispose] 取消全部订阅并释放网关，之后不再向状态流通知。
///
/// 原 `moment_card._toggleAudio / _initAudio / _audioPlayer.dispose` 的
/// 纯逻辑部分，UI（播放按钮、进度条、Toast）留在展示层消费状态流。
class MomentAudioController {
  MomentAudioController({
    required this.audioPath,
    required this.baseDir,
    this.initialDuration,
    MomentAudioGateway? gateway,
    String Function(String baseDir, String relative)? pathJoiner,
  }) : _gateway = gateway ?? AudioPlayerGateway(AudioPlayer()),
       _join = pathJoiner ?? p.join {
    if (initialDuration != null) {
      _state = _state.copyWith(duration: initialDuration);
    }
  }

  /// 相对音频路径（如 `audio/xxx.m4a`）；null 表示无音频。
  final String? audioPath;

  /// 音频所在基目录；null 表示无法定位文件。
  final String? baseDir;

  /// 展示用初始时长（原 `Duration(seconds: moment.audioDuration!)`）。
  final Duration? initialDuration;

  final MomentAudioGateway _gateway;
  final String Function(String baseDir, String relative) _join;

  MomentAudioState _state = const MomentAudioState.idle();
  bool _disposed = false;
  bool _initialized = false;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completeSub;

  final StreamController<MomentAudioState> _stateController =
      StreamController<MomentAudioState>.broadcast();

  /// 当前播放状态（同步可读，不依赖流事件）。
  MomentAudioState get state => _state;

  /// 状态变化流（broadcast，dispose 后不再发出任何事件）。
  Stream<MomentAudioState> get stateStream => _stateController.stream;

  /// 订阅 4 条插件流。调用方负责在页面生命周期内恰当地调用一次；
  /// 重复调用幂等（第二次起不再重复订阅），dispose 后再调用抛 StateError。
  void initialize() {
    if (_disposed) {
      throw StateError('MomentAudioController 已释放，不能再次 initialize');
    }
    if (_initialized) {
      return;
    }
    _initialized = true;
    _stateSub = _gateway.onPlayerStateChanged.listen((playerState) {
      _emit(_state.copyWith(isPlaying: playerState == PlayerState.playing));
    });

    _durationSub = _gateway.onDurationChanged.listen((duration) {
      _emit(_state.copyWith(duration: duration));
    });

    _positionSub = _gateway.onPositionChanged.listen((position) {
      _emit(_state.copyWith(position: position));
    });

    _completeSub = _gateway.onPlayerComplete.listen((_) {
      // 与原 `_playerCompleteSub` 一致：完成时复位播放标记与进度。
      _emit(_state.copyWith(isPlaying: false, position: Duration.zero));
    });
  }

  /// 切换播放/暂停。
  ///
  /// 决策顺序与原 `moment_card._toggleAudio` 逐字一致：
  /// 1. audioPath / baseDir 任一为 null → [MomentAudioToggleNoAudio]；
  /// 2. 播放中 → `pause()`；
  /// 3. 文件不存在 → [MomentAudioToggleMissing]；
  /// 4. 文件存在 → `play(DeviceFileSource(完整路径))`。
  Future<MomentAudioToggleResult> toggle() async {
    final path = audioPath;
    final dir = baseDir;
    if (path == null || dir == null) {
      return const MomentAudioToggleNoAudio();
    }

    if (_state.isPlaying) {
      try {
        await _gateway.pause();
        _emit(_state.copyWith(isPlaying: false));
        return const MomentAudioToggleHandled();
      } catch (error) {
        return MomentAudioToggleFailure(error);
      }
    }

    final fullPath = _join(dir, path);
    try {
      if (!await _gateway.fileExists(fullPath)) {
        return const MomentAudioToggleMissing();
      }
      await _gateway.play(DeviceFileSource(fullPath));
      return const MomentAudioToggleHandled();
    } catch (error) {
      return MomentAudioToggleFailure(error);
    }
  }

  void _emit(MomentAudioState next) {
    _state = next;
    // dispose 后不再通知（流已关闭，add 会抛 StateError）。
    if (!_disposed && _stateController.hasListener) {
      _stateController.add(next);
    }
  }

  /// 取消 4 条订阅并释放网关；之后的状态流事件一律不再通知。
  void dispose() {
    _disposed = true;
    _stateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _completeSub?.cancel();
    _stateSub = null;
    _durationSub = null;
    _positionSub = null;
    _completeSub = null;
    _gateway.dispose();
    _stateController.close();
  }
}
