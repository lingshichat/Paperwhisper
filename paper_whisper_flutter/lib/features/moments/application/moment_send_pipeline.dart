import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:paper_whisper_flutter/features/moments/data/moment.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment_service.dart';

/// 发送随心记结果（sealed typed outcome，context-free）。
///
/// 由页面消费并翻译为用户反馈（额度弹窗 / 保存成功同步 / 失败 Toast）；
/// 本类型不携带任何 UI 依赖。
sealed class MomentSendResult {
  const MomentSendResult();
}

/// 免费用户当日条数已达上限（原 `todayCount >= 3` 分支）。
class MomentSendQuotaExceeded extends MomentSendResult {
  const MomentSendQuotaExceeded();
}

/// 发送成功。
class MomentSendSuccess extends MomentSendResult {
  const MomentSendSuccess({required this.moment});

  final Moment moment;
}

/// 发送失败（图片落盘 / Moment 保存抛错）。管线自身不持输入状态、
/// 不触碰调用方：输入清空由 MomentInputWidget 在触发发送后按原行为
/// 同步完成，与成败无关；失败 typed 结果仅用于避免未处理异步错误，
/// 由页面决定是否提示重试。音频保存失败沿用原行为：记录后继续。
class MomentSendFailure extends MomentSendResult {
  const MomentSendFailure({required this.error});

  final Object error;
}

/// 随心记发送管线（context-free）。
///
/// 依次执行：免费额度 → 图片落盘 → 音频落盘（容忍失败）→ Moment 保存，
/// 与 `moments_page._handleSend` 原编排逐字一致；失败一律返回 typed
/// [MomentSendFailure]，不再成为未处理异步错误。
///
/// 依赖经构造注入：
/// - [momentService]：共享 MomentService（composition root 注入）；
/// - [canUseProFeatures]：会员额度 seam（页面注入 `PaymentService` 状态）；
/// - [todayMomentCount]：当日条数 seam（页面注入当前索引统计）。
///
/// 不持有 BuildContext，不弹 Toast/Dialog/Navigator，UI 反馈由页面负责。
/// 管线不持有任何输入状态（content/images/audio 均为 [send] 参数），
/// 也不触碰调用方：输入清空由 MomentInputWidget 在触发发送后同步完成，
/// 失败 typed 结果仅避免未处理异步错误并交由页面显示 Toast。
class MomentSendPipeline {
  MomentSendPipeline({
    required this.momentService,
    required this.canUseProFeatures,
    required this.todayMomentCount,
  });

  /// 免费用户每日条数上限（原 `todayCount >= 3`）。
  static const int freeDailyLimit = 3;

  final MomentService momentService;
  final bool Function() canUseProFeatures;
  final int Function() todayMomentCount;

  /// 发送一条随心记。
  ///
  /// [images] 为待落盘的原始图片文件（页面由 `XFile` 转换而来）；
  /// 返回 typed 结果。管线不触碰调用方输入状态；失败仅表示未持久化，
  /// 输入清空由调用方（MomentInputWidget）触发发送后按原行为同步完成。
  Future<MomentSendResult> send({
    required String content,
    List<File> images = const [],
    String? audioPath,
    String? audioTitle,
    int? audioDuration,
  }) async {
    // 1. 免费额度：非会员且当日已达上限
    if (!canUseProFeatures() &&
        todayMomentCount() >= MomentSendPipeline.freeDailyLimit) {
      return const MomentSendQuotaExceeded();
    }

    try {
      // 2. 图片落盘
      final savedPaths = <String>[];
      for (final image in images) {
        savedPaths.add(await momentService.saveImage(image));
      }

      // 3. 音频落盘（原行为：失败仅记录并继续，不影响发送）
      String? savedAudioPath;
      if (audioPath != null) {
        try {
          savedAudioPath = await momentService.saveAudio(audioPath);
        } catch (e) {
          debugPrint("Error saving audio: $e");
        }
      }

      // 4. 保存 Moment（createdAt 为 now，与「随心记即收件箱」语义一致）
      final newMoment = Moment.create(
        content: content,
        images: savedPaths,
        audioPath: savedAudioPath,
        audioTitle: audioTitle,
        audioDuration: audioDuration,
      );
      await momentService.saveMoment(newMoment);
      return MomentSendSuccess(moment: newMoment);
    } catch (e) {
      return MomentSendFailure(error: e);
    }
  }
}
