import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/moments/application/moment_send_pipeline.dart';
import 'package:paper_whisper_flutter/models/moment.dart';
import 'package:paper_whisper_flutter/services/moment_service.dart';

/// 内存版 MomentService 替身：记录调用计数，按 seam 抛错。
class _FakeMomentService extends MomentService {
  final List<Moment> _moments = <Moment>[];

  /// 非 null 时 [saveImage] 抛错。
  Object? imageSaveError;

  /// 非 null 时 [saveMoment] 抛错。
  Object? saveError;

  /// true 时 [saveAudio] 抛错（验证原「记录后继续」容忍行为）。
  bool failAudio = false;

  int saveImageCallCount = 0;
  int saveAudioCallCount = 0;
  int saveMomentCallCount = 0;
  Moment? lastSaved;

  @override
  Future<String> saveImage(File sourceFile) async {
    saveImageCallCount++;
    if (imageSaveError != null) throw imageSaveError!;
    return 'images/fake_$saveImageCallCount.jpg';
  }

  @override
  Future<String> saveAudio(String sourcePath) async {
    saveAudioCallCount++;
    if (failAudio) throw Exception('audio fail');
    return 'audio/fake_audio.m4a';
  }

  @override
  Future<void> saveMoment(Moment moment) async {
    saveMomentCallCount++;
    lastSaved = moment;
    if (saveError != null) throw saveError!;
    _moments.add(moment);
  }
}

/// MomentSendPipeline 单元测试（阶段 4 Wave A）。
///
/// 契约覆盖（与 `moments_page._handleSend` 原编排逐字一致）：
/// - 免费额度：非会员且当日 ≥ 3 条 → QuotaExceeded，不落盘、不保存；
/// - 会员绕过额度；免费未达上限正常发送；
/// - 成功路径：图片落盘 → 音频落盘 → Moment 保存（createdAt 为 now）；
/// - 音频失败容忍（原 debugPrint + 继续），不影响发送；
/// - 图片 / Moment 保存失败 → typed MomentSendFailure，不再未处理，
///   失败不产生部分持久化（除已落盘媒体外）；
/// - 管线不持输入状态：content/images/audio 仅为 [send] 参数，管线不触碰
///   调用方；输入清空由 MomentInputWidget 触发发送后按原行为同步完成；
/// - 失败仅返回 typed 结果（避免未处理异步错误），由页面显示 Toast。
void main() {
  MomentSendPipeline buildPipeline(
    _FakeMomentService service, {
    bool pro = false,
    int todayCount = 0,
  }) {
    return MomentSendPipeline(
      momentService: service,
      canUseProFeatures: () => pro,
      todayMomentCount: () => todayCount,
    );
  }

  test('免费用户当日未达上限：正常发送并落盘图片与音频', () async {
    final service = _FakeMomentService();
    final result = await buildPipeline(service).send(
      content: '今天的心情',
      images: [File('a.jpg'), File('b.jpg')],
      audioPath: 'recording.m4a',
      audioTitle: '语音随记',
      audioDuration: 12,
    );

    expect(result, isA<MomentSendSuccess>());
    final moment = (result as MomentSendSuccess).moment;
    expect(moment.content, '今天的心情');
    expect(moment.images, ['images/fake_1.jpg', 'images/fake_2.jpg']);
    expect(moment.audioPath, 'audio/fake_audio.m4a');
    expect(moment.audioTitle, '语音随记');
    expect(moment.audioDuration, 12);
    expect(service.saveImageCallCount, 2);
    expect(service.saveAudioCallCount, 1);
    expect(service.saveMomentCallCount, 1);
  });

  test('免费用户当日达上限：返回 QuotaExceeded，不落盘不保存', () async {
    final service = _FakeMomentService();
    final result = await buildPipeline(
      service,
      todayCount: 3,
    ).send(content: '超限内容', images: [File('a.jpg')]);

    expect(result, isA<MomentSendQuotaExceeded>());
    expect(service.saveImageCallCount, 0);
    expect(service.saveMomentCallCount, 0);
  });

  test('会员用户当日已达上限：绕过额度正常发送', () async {
    final service = _FakeMomentService();
    final result = await buildPipeline(
      service,
      pro: true,
      todayCount: 5,
    ).send(content: '会员内容', images: [File('a.jpg')]);

    expect(result, isA<MomentSendSuccess>());
    expect(service.saveMomentCallCount, 1);
  });

  test('图片保存失败：返回 typed failure，不保存 Moment', () async {
    final service = _FakeMomentService()..imageSaveError = Exception('磁盘满');
    final result = await buildPipeline(
      service,
    ).send(content: '带图内容', images: [File('a.jpg')]);

    expect(result, isA<MomentSendFailure>());
    expect((result as MomentSendFailure).error, isA<Exception>());
    expect(service.saveMomentCallCount, 0);
  });

  test('Moment 保存失败：返回 typed failure，管线不触碰输入状态', () async {
    final service = _FakeMomentService()..saveError = Exception('写入失败');
    final result = await buildPipeline(
      service,
    ).send(content: '会失败的内容', images: [File('a.jpg')]);

    expect(result, isA<MomentSendFailure>());
    expect((result as MomentSendFailure).error, isA<Exception>());
    // 图片已落盘、Moment 尝试保存过一次，但未持久化
    expect(service.saveImageCallCount, 1);
    expect(service.saveMomentCallCount, 1);
    expect(service.lastSaved!.content, '会失败的内容');
  });

  test('音频保存失败：原行为容忍（记录后继续），Moment 正常保存', () async {
    final service = _FakeMomentService()..failAudio = true;
    final result = await buildPipeline(
      service,
    ).send(content: '带语音内容', audioPath: 'recording.m4a');

    expect(result, isA<MomentSendSuccess>());
    final moment = (result as MomentSendSuccess).moment;
    expect(moment.audioPath, isNull);
    expect(service.saveAudioCallCount, 1);
    expect(service.saveMomentCallCount, 1);
  });

  test('空内容 + 无媒体也走保存路径（发送守卫在输入组件层）', () async {
    final service = _FakeMomentService();
    final result = await buildPipeline(service).send(content: '', images: []);

    expect(result, isA<MomentSendSuccess>());
    expect(service.saveMomentCallCount, 1);
  });

  test('freeDailyLimit 常量 = 3（与「免费版每日 3 条」文案一致）', () {
    expect(MomentSendPipeline.freeDailyLimit, 3);
  });
}
