import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paper_whisper_flutter/config/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/moments/application/moment_recorder_controller.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/widgets/moment_input_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MomentInputWidget × MomentRecorderController 集成测试
/// （阶段 4 L6 组件控制器接入）。
///
/// 契约覆盖：
/// - 权限拒绝 → "请授予麦克风权限" Toast，不进入录音；
/// - 录音：start 进入磁带界面（mic → stop 图标）、tick 每秒累计时长、
///   stop 落盘路径并回到输入界面；
/// - cancel 不保存路径、时长归零；deleteAudio 清路径与标题；
/// - 预览：play(DeviceFileSource(path)) / pause，播放状态与 complete
///   经网关事件驱动图标切换；
/// - 发送：文本仅发文本；带音频时默认标题 "语音随记"、content 缺省补
///   标题、audioDuration 秒；发送后 content/images/audio 全部清空；
/// - owned 控制器由页面释放；injected 控制器页面不释放；
/// - Windows / Android 360 逻辑像素视口无 RenderFlex overflow。
///
/// 全部经 fake 网关注入，无插件、无磁盘 I/O。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ThemeRegistry.init();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GoogleFonts.config.allowRuntimeFetching = false;
    // 磁带纹理是 NetworkImage：预置 imageCache，避免测试内 HTTP 400 异常。
    _seedCassetteTexture();
  });

  /// 注入控制器 + fake 网关 + 可编程 tick 流。
  (
    MomentRecorderController controller,
    StreamController<void> ticks,
    _FakeRecorderGateway gateway,
  )
  buildRecorder({bool permission = true, String? stopResult}) {
    final gateway = _FakeRecorderGateway()
      ..permission = permission
      ..stopResult = stopResult ?? '/tmp/recorded.m4a';
    final ticks = StreamController<void>.broadcast();
    final controller = MomentRecorderController(
      gateway: gateway,
      tickStream: ticks.stream,
    );
    addTearDown(() {
      controller.dispose();
      ticks.close();
    });
    return (controller, ticks, gateway);
  }

  Future<void> pumpInput(
    WidgetTester tester, {
    MomentRecorderController? recorder,
    required _SendCapture capture,
    double width = 360,
    double height = 800,
    double dpr = 1,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    tester.view.physicalSize = Size(width * dpr, height * dpr);
    tester.view.devicePixelRatio = dpr;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(),
        child: MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: MomentInputWidget(
                onSend: capture.call,
                recorder: recorder,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  /// 点击录音按钮（未录制为 mic_none，录制中为 stop_circle_outlined）。
  Future<void> tapMic(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.mic_none));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapStop(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.stop_circle_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('渲染与权限', () {
    testWidgets('owned：默认渲染无异常，mic + send 按钮存在', (tester) async {
      await pumpInput(tester, capture: _SendCapture());

      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('权限拒绝：Toast 提示"请授予麦克风权限"，不进入录音', (tester) async {
      final (controller, _, _) = buildRecorder(permission: false);
      await pumpInput(tester, capture: _SendCapture(), recorder: controller);

      await tapMic(tester);

      expect(find.text('请授予麦克风权限'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
      // 放完 Toast 计时，避免 pending timer。
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('Windows 360 视口：无 RenderFlex overflow', (tester) async {
      await pumpInput(
        tester,
        capture: _SendCapture(),
        width: 360,
        platform: TargetPlatform.windows,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('Android 360 视口（录制中磁带界面）：无 overflow', (tester) async {
      final (controller, ticks, _) = buildRecorder();
      await pumpInput(tester, capture: _SendCapture(), recorder: controller);

      await tapMic(tester);
      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tapStop(tester);
      await ticks.close();
    });
  });

  group('录音 start / tick / stop', () {
    testWidgets('start：进入磁带界面（mic → stop），tick 累计时长', (tester) async {
      final (controller, ticks, gateway) = buildRecorder();
      await pumpInput(tester, capture: _SendCapture(), recorder: controller);

      await tapMic(tester);

      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsNothing);
      expect(find.text('00:00'), findsOneWidget);
      expect(gateway.startedPaths, ['/tmp/temp_record_123456789.m4a']);

      ticks.add(null);
      ticks.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('00:02'), findsOneWidget);
    });

    testWidgets('stop：落盘路径并回到输入界面（mini cassette 出现）', (tester) async {
      final (controller, ticks, gateway) = buildRecorder(
        stopResult: '/tmp/recorded.m4a',
      );
      await pumpInput(tester, capture: _SendCapture(), recorder: controller);

      await tapMic(tester);
      await tapStop(tester);

      expect(gateway.stopCalls, 1);
      expect(controller.state.isRecording, isFalse);
      expect(controller.state.audioPath, '/tmp/recorded.m4a');
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    });

    testWidgets('stop 后 tick 不再累计', (tester) async {
      final (controller, ticks, _) = buildRecorder();
      await pumpInput(tester, capture: _SendCapture(), recorder: controller);

      await tapMic(tester);
      ticks.add(null);
      await tester.pump();
      await tapStop(tester);

      final before = controller.state.recordDuration;
      ticks.add(null);
      await tester.pump();

      expect(before, const Duration(seconds: 1));
      expect(controller.state.recordDuration, const Duration(seconds: 1));
      await ticks.close();
    });
  });

  group('cancel / delete', () {
    testWidgets('cancel：不保存路径、时长归零、回到输入界面', (tester) async {
      final (controller, _, _) = buildRecorder();
      await pumpInput(tester, capture: _SendCapture(), recorder: controller);

      await tapMic(tester);
      await tester.tap(find.text('取消'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(controller.state.isRecording, isFalse);
      expect(controller.state.audioPath, isNull);
      expect(controller.state.recordDuration, Duration.zero);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_fill), findsNothing);
    });

    testWidgets('deleteAudio：清空路径与标题', (tester) async {
      final (controller, _, _) = buildRecorder();
      await pumpInput(tester, capture: _SendCapture(), recorder: controller);

      await tapMic(tester);
      await tapStop(tester);
      await tester.enterText(find.byType(TextField).at(1), '我的录音');
      await tester.pump();
      expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(controller.state.audioPath, isNull);
      expect(controller.audioTitleController.text, isEmpty);
      expect(find.byIcon(Icons.play_circle_fill), findsNothing);
    });
  });

  group('预览', () {
    testWidgets('播放 → play(path)；playing 事件切 pause 图标', (tester) async {
      final (controller, _, gateway) = buildRecorder();
      await pumpInput(tester, capture: _SendCapture(), recorder: controller);

      await tapMic(tester);
      await tapStop(tester);

      await tester.tap(find.byIcon(Icons.play_circle_fill));
      await tester.pump();

      expect(gateway.playCalls, ['/tmp/recorded.m4a']);
      expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);

      gateway.emitState(PlayerState.playing);
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget);
    });

    testWidgets('播放中再点 → pause；complete 复位 play 图标', (tester) async {
      final (controller, _, gateway) = buildRecorder();
      await pumpInput(tester, capture: _SendCapture(), recorder: controller);

      await tapMic(tester);
      await tapStop(tester);
      await tester.tap(find.byIcon(Icons.play_circle_fill));
      await tester.pump();
      gateway.emitState(PlayerState.playing);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.pause_circle_filled));
      await tester.pump();

      expect(gateway.pauseCalls, 1);
      gateway.emitState(PlayerState.paused);
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);

      gateway.emitComplete();
      await tester.pump();
      await tester.pump();
      expect(controller.state.isPreviewPlaying, isFalse);
      expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    });
  });

  group('发送', () {
    testWidgets('纯文本：payload 正确、音频字段为 null', (tester) async {
      final capture = _SendCapture();
      await pumpInput(tester, capture: capture);

      await tester.enterText(find.byType(TextField), '你好世界');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(capture.callCount, 1);
      expect(capture.content, '你好世界');
      expect(capture.images, isEmpty);
      expect(capture.audioPath, isNull);
      expect(capture.audioTitle, isNull);
      expect(capture.audioDuration, isNull);
      // 发送后清空输入
      expect(find.text('你好世界'), findsNothing);
    });

    testWidgets('带音频：默认标题"语音随记"、缺省 content、audioDuration 秒', (tester) async {
      final (controller, ticks, _) = buildRecorder();
      final capture = _SendCapture();
      await pumpInput(tester, capture: capture, recorder: controller);

      await tapMic(tester);
      ticks.add(null);
      ticks.add(null);
      ticks.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tapStop(tester);

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(capture.callCount, 1);
      expect(capture.content, '语音随记');
      expect(capture.audioPath, '/tmp/recorded.m4a');
      expect(capture.audioTitle, '语音随记');
      expect(capture.audioDuration, 3);
      // 发送后 audio 全部清空
      expect(controller.state.audioPath, isNull);
      expect(controller.state.recordDuration, Duration.zero);
      expect(controller.audioTitleController.text, isEmpty);
      expect(find.byIcon(Icons.play_circle_fill), findsNothing);
      await ticks.close();
    });

    testWidgets('带音频 + 自定义标题：保留标题、content 缺省补标题', (tester) async {
      final (controller, _, _) = buildRecorder();
      final capture = _SendCapture();
      await pumpInput(tester, capture: capture, recorder: controller);

      await tapMic(tester);
      await tapStop(tester);
      await tester.enterText(find.byType(TextField).at(1), '我的语音');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(capture.content, '我的语音');
      expect(capture.audioTitle, '我的语音');
      expect(capture.audioPath, '/tmp/recorded.m4a');
      expect(controller.audioTitleController.text, isEmpty);
    });
  });

  group('dispose', () {
    testWidgets('owned：页面释放自建控制器，无异常', (tester) async {
      await pumpInput(tester, capture: _SendCapture(), recorder: null);

      // 销毁整棵树触发 State.dispose（owned 控制器随页面释放）。
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('injected：页面不释放注入控制器，外部负责', (tester) async {
      final (controller, _, gateway) = buildRecorder();
      await pumpInput(tester, capture: _SendCapture(), recorder: controller);
      await tapMic(tester);
      await tapStop(tester);

      // 销毁整棵树：页面只取消订阅，不 dispose 注入控制器。
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(gateway.recorderDisposed, isFalse);
      expect(gateway.playerDisposed, isFalse);
      // 控制器仍可用（未被页面释放）。
      expect(controller.state.audioPath, '/tmp/recorded.m4a');
    });
  });
}

/// 发送回调捕获。
class _SendCapture {
  String? content;
  List<XFile>? images;
  String? audioPath;
  String? audioTitle;
  int? audioDuration;
  int callCount = 0;

  void call(
    String content,
    List<XFile> images, {
    String? audioPath,
    String? audioTitle,
    int? audioDuration,
  }) {
    callCount += 1;
    this.content = content;
    this.images = images;
    this.audioPath = audioPath;
    this.audioTitle = audioTitle;
    this.audioDuration = audioDuration;
  }
}

/// 1×1 透明 PNG（磁带纹理预置用）。
const List<int> _kTransparentPng = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

/// 预置磁带纸纹 NetworkImage 的 imageCache，避免测试内发起真实 HTTP。
void _seedCassetteTexture() {
  final key = NetworkImage(
    'https://www.transparenttextures.com/patterns/paper-fibers.png',
  );
  final completer = OneFrameImageStreamCompleter(
    decodeImageFromList(
      Uint8List.fromList(_kTransparentPng),
    ).then((image) => ImageInfo(image: image)),
  );
  imageCache.putIfAbsent(key, () => completer);
}

/// fake 网关：无插件、无磁盘 I/O，可编程权限/结果/时间，可主动发预览事件。
class _FakeRecorderGateway implements MomentRecorderGateway {
  bool permission = true;
  Object? startError;
  Object? stopError;
  Object? playError;

  String tempDir = '/tmp';
  DateTime nowValue = DateTime.fromMillisecondsSinceEpoch(123456789);
  String? stopResult;

  final List<String> startedPaths = [];
  final List<String> playCalls = [];
  int pauseCalls = 0;
  int stopCalls = 0;
  bool recorderDisposed = false;
  bool playerDisposed = false;

  final StreamController<PlayerState> _stateCtrl =
      StreamController<PlayerState>.broadcast();
  final StreamController<void> _completeCtrl =
      StreamController<void>.broadcast();

  void emitState(PlayerState state) => _stateCtrl.add(state);

  void emitComplete() => _completeCtrl.add(null);

  @override
  Future<bool> hasPermission() async => permission;

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
  Stream<PlayerState> get previewStateStream => _stateCtrl.stream;

  @override
  Stream<void> get previewCompleteStream => _completeCtrl.stream;

  @override
  Future<void> disposeRecorder() async {
    recorderDisposed = true;
  }

  @override
  Future<void> disposePlayer() async {
    playerDisposed = true;
  }
}
