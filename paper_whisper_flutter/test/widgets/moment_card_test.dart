import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/moments/application/moment_audio_controller.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment.dart';
import 'package:paper_whisper_flutter/features/moments/presentation/moment_detail_page.dart';
import 'package:paper_whisper_flutter/features/settings/application/settings_provider.dart';
import 'package:paper_whisper_flutter/features/moments/presentation/widgets/moment_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MomentCard × MomentAudioController 集成测试（阶段 4 L0 组件控制器接入）。
///
/// 契约覆盖：
/// - 无音频不渲染播放器；有音频渲染播放器，初始 play 图标与时长；
/// - 播放 → 网关 play + pause 图标 + 进度条推进；暂停 → pause + play 图标；
/// - missing → “音频文件丢失” Toast；failure → “音频播放失败” Toast 且无
///   unhandled async error；noAudio → 无任何 UI 反馈；
/// - 注入控制器不被卡片释放；owned 控制器由卡片释放（无异常）；
/// - Windows / Android 视口无 RenderFlex overflow。
///
/// 全部经 fake 网关注入，无插件、无磁盘 I/O。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ThemeRegistry.init();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Moment moment({
    String? audioPath = 'audio/a.m4a',
    int? audioDuration = 10,
    List<String> images = const [],
  }) {
    return Moment(
      uuid: 'moment-1',
      content: '测试内容',
      images: images,
      createdAt: DateTime(2026, 3, 12, 9, 30),
      audioPath: audioPath,
      audioTitle: '测试录音',
      audioDuration: audioDuration,
    );
  }

  /// 统一装配：SettingsProvider（build 依赖）+ MaterialApp
  /// （ScaffoldMessenger 供 SkeuomorphicToast）。
  ///
  /// [width]/[height] 为逻辑尺寸：physicalSize = 逻辑尺寸 × dpr
  /// （Android 360 逻辑 = 1080×2400 @ dpr 3，与质量门冒烟模式一致）。
  Future<void> pumpCard(
    WidgetTester tester, {
    required Moment moment,
    MomentAudioController? controller,
    double width = 400,
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
          theme: AppTheme.getThemeData(
            AppTheme.themeDefault,
          ).copyWith(platform: platform),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MomentCard(
                moment: moment,
                baseDir: Directory.systemTemp,
                controller: controller,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  /// 点击播放器区域（图标是 GestureDetector 的后代）。
  /// 播放中图标为 pause，暂停后为 play_arrow，由调用方指定。
  Future<void> tapPlayer(
    WidgetTester tester, {
    IconData icon = Icons.play_arrow,
  }) async {
    await tester.tap(find.byIcon(icon).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('导航：点击卡片进入详情（AppRoutes.momentDetail）', () {
    testWidgets('无图片无音频卡片：点击 push 详情页（opaque=false 语义保留）', (tester) async {
      final m = moment(images: const [], audioPath: null, audioDuration: null);
      await pumpCard(tester, moment: m, width: 400, height: 800);

      await tester.tap(find.text('测试内容'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // 经 AppRoutes.momentDetail 的 fade 工厂（opaque=false）进入详情页。
      expect(find.byType(MomentDetailPage), findsOneWidget);
      final route =
          ModalRoute.of(tester.element(find.byType(MomentDetailPage)))
              as PageRouteBuilder<void>;
      expect(route.opaque, isFalse);
      expect(tester.takeException(), isNull);

      // 收尾销毁整棵 widget 树：释放路由侧动画控制器与 Hero 状态。
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('渲染', () {
    testWidgets('无音频：不渲染播放器', (tester) async {
      await pumpCard(tester, moment: moment(audioPath: null));

      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byIcon(Icons.pause), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('有音频（owned）：渲染播放器，初始 play 图标与时长', (tester) async {
      await pumpCard(tester, moment: moment());

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.text('00:10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('有音频（injected）：渲染播放器，时长来自 initialDuration', (tester) async {
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        initialDuration: const Duration(seconds: 7),
        gateway: _FakeAudioGateway(),
      );
      addTearDown(controller.dispose);

      await pumpCard(tester, moment: moment(), controller: controller);

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.text('00:07'), findsOneWidget);
    });
  });

  group('播放 / 暂停 / 进度', () {
    testWidgets('播放：网关 play，pause 图标 + 进度推进 + 当前位置时长', (tester) async {
      final gateway = _FakeAudioGateway()..exists = true;
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        initialDuration: const Duration(seconds: 10),
        gateway: gateway,
      );
      addTearDown(controller.dispose);

      await pumpCard(tester, moment: moment(), controller: controller);
      await tapPlayer(tester);

      expect(gateway.played, hasLength(1));

      // 网关回放状态与位置 → 播放器 UI 严格跟随 controller.state。
      // （broadcast 流两级投递，测试环境需两次 pump 完成重建）
      gateway.emitState(PlayerState.playing);
      gateway.emitPosition(const Duration(seconds: 5));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.text('00:05'), findsOneWidget);

      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, closeTo(0.5, 0.001));
    });

    testWidgets('暂停：网关 pause，回到 play 图标与总时长', (tester) async {
      final gateway = _FakeAudioGateway()..exists = true;
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        initialDuration: const Duration(seconds: 10),
        gateway: gateway,
      );
      addTearDown(controller.dispose);

      await pumpCard(tester, moment: moment(), controller: controller);
      await tapPlayer(tester);
      gateway.emitState(PlayerState.playing);
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.pause), findsOneWidget);

      await tapPlayer(tester, icon: Icons.pause);

      expect(gateway.pauseCount, 1);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.text('00:10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('播放完成：complete 复位为 play 图标与 0 进度', (tester) async {
      final gateway = _FakeAudioGateway()..exists = true;
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        initialDuration: const Duration(seconds: 10),
        gateway: gateway,
      );
      addTearDown(controller.dispose);

      await pumpCard(tester, moment: moment(), controller: controller);
      await tapPlayer(tester);

      // 播放中：网关回放 playing + 位置 → pause 图标 + 非零进度。
      gateway.emitState(PlayerState.playing);
      gateway.emitPosition(const Duration(seconds: 5));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(0.5, 0.001),
      );

      // 网关 complete → 控制器复位 isPlaying=false、position=0。
      gateway.emitComplete();
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(0.0, 0.001),
      );
      // 非播放态时长文案回到总时长。
      expect(find.text('00:10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Toast 反馈', () {
    testWidgets('文件缺失：提示“音频文件丢失”，不调用 play', (tester) async {
      final gateway = _FakeAudioGateway()..exists = false;
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        initialDuration: const Duration(seconds: 10),
        gateway: gateway,
      );
      addTearDown(controller.dispose);

      await pumpCard(tester, moment: moment(), controller: controller);
      await tapPlayer(tester);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('音频文件丢失'), findsOneWidget);
      expect(gateway.played, isEmpty);

      // 放完 Toast 计时，避免 pending timer。
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('播放失败：提示“音频播放失败”，无 unhandled async error', (tester) async {
      final gateway = _FakeAudioGateway()
        ..exists = true
        ..playError = StateError('解码失败');
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        initialDuration: const Duration(seconds: 10),
        gateway: gateway,
      );
      addTearDown(controller.dispose);

      await pumpCard(tester, moment: moment(), controller: controller);
      await tapPlayer(tester);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('音频播放失败'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('无音频路径：点击无任何 UI 反馈、无异常', (tester) async {
      final gateway = _FakeAudioGateway();
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: null, // baseDir 缺失 → NoAudio
        initialDuration: const Duration(seconds: 10),
        gateway: gateway,
      );
      addTearDown(controller.dispose);

      await pumpCard(tester, moment: moment(), controller: controller);
      await tapPlayer(tester);

      expect(find.text('音频文件丢失'), findsNothing);
      expect(find.text('音频播放失败'), findsNothing);
      expect(gateway.played, isEmpty);
      expect(gateway.pauseCount, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('dispose 所有权', () {
    testWidgets('注入控制器：卡片不释放，仍可继续使用', (tester) async {
      final gateway = _FakeAudioGateway()..exists = true;
      final controller = MomentAudioController(
        audioPath: 'audio/a.m4a',
        baseDir: '/moments',
        initialDuration: const Duration(seconds: 10),
        gateway: gateway,
      );
      addTearDown(controller.dispose);

      await pumpCard(tester, moment: moment(), controller: controller);

      // 卸载卡片 → 注入的控制器不应被释放。
      await tester.pumpWidget(const SizedBox());
      expect(gateway.disposeCount, 0);
      expect(tester.takeException(), isNull);

      // 释放后仍可正常 toggle（未被卡片提前销毁）。
      final result = await controller.toggle();
      expect(result, isA<MomentAudioToggleHandled>());
    });

    testWidgets('owned 控制器：卡片卸载时释放，无异常', (tester) async {
      await pumpCard(tester, moment: moment());

      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });

  group('跨平台视口无溢出', () {
    testWidgets('Android 360×800（dpr 3）无 overflow', (tester) async {
      await pumpCard(
        tester,
        moment: moment(images: ['img/1.png', 'img/2.png']),
        width: 360,
        height: 800,
        dpr: 3,
        platform: TargetPlatform.android,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('Windows 360×800 无 overflow', (tester) async {
      await pumpCard(
        tester,
        moment: moment(images: ['img/1.png']),
        width: 360,
        height: 800,
        dpr: 1,
        platform: TargetPlatform.windows,
      );

      expect(tester.takeException(), isNull);
    });
  });
}

/// 内存版音频网关替身：记录调用计数与播放源，按 seam 抛错，无插件无 I/O。
class _FakeAudioGateway implements MomentAudioGateway {
  late final _stateController = StreamController<PlayerState>.broadcast();
  late final _durationController = StreamController<Duration>.broadcast();
  late final _positionController = StreamController<Duration>.broadcast();
  late final _completeController = StreamController<void>.broadcast();

  /// fileExists 的返回值。
  bool exists = true;

  /// 非 null 时 [play] 抛错。
  Object? playError;

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
