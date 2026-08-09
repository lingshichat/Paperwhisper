import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

/// 自动同步调度决策结果。
enum AutoSyncDecision {
  /// force 分支：立即触发同步（跳过防抖与冷却）。
  triggeredNow,

  /// 已排定 30s 防抖定时器。
  scheduled,

  /// 生命周期触发但处于 5 分钟冷却期内，被抑制。
  suppressed,
}

/// 自动同步调度器（无 UI 依赖，可独立单测）。
///
/// 封装 30s 防抖、5 分钟生命周期冷却与 force 分支决策，并负责
/// Timer 生命周期（dispose 取消）。不接收 BuildContext；实际同步
/// 执行由 Provider 注入的 [onTrigger] 回调承担。
///
/// 迁移来源（原 `sync_provider.dart`）：
/// - `requestAutoSync` 调度部分（908-974）：force 分支 / 冷却 / 防抖。
class AutoSyncScheduler {
  AutoSyncScheduler({
    required Future<void> Function() onTrigger,
    DateTime Function()? clock,
  }) : _onTrigger = onTrigger,
       _clock = clock ?? DateTime.now;

  final Future<void> Function() _onTrigger;
  final DateTime Function() _clock;
  Timer? _timer;

  /// 防抖窗口（原实现 30 秒）。
  static const Duration debounceDuration = Duration(seconds: 30);

  /// 生命周期触发冷却（原实现 5 分钟）。
  static const Duration lifecycleCooldown = Duration(minutes: 5);

  /// 是否存在尚未触发的防抖定时器。
  bool get isPending => _timer?.isActive ?? false;

  /// 请求一次自动同步。
  ///
  /// [fromLifecycle] 是否由生命周期（如切前台）触发，受冷却限制。
  /// [force] 是否强制立即同步（忽略防抖和冷却）。
  /// [lastSuccessfulSyncAt] 当前作用域上次成功同步时间，冷却判断用。
  ///
  /// 返回决策结果；触发执行（force 立即 / 防抖到期）由 [onTrigger] 承担。
  AutoSyncDecision request({
    required bool fromLifecycle,
    required bool force,
    DateTime? lastSuccessfulSyncAt,
  }) {
    // Force Sync: Skip checks, run immediately（先取消待执行防抖定时器）
    if (force) {
      cancel();
      debugPrint('Force Sync requested. Skipping debounce and cooldown.');
      unawaited(_onTrigger());
      return AutoSyncDecision.triggeredNow;
    }

    // Cooldown verification for lifecycle events
    // 冷却命中时保留已排定的防抖 timer（如保存后的 30s 定时同步），不取消。
    if (fromLifecycle && lastSuccessfulSyncAt != null) {
      final diff = _clock().difference(lastSuccessfulSyncAt);
      if (diff.inMinutes < lifecycleCooldown.inMinutes) {
        debugPrint(
          'AutoSync suppressed (Cooldown: ${lifecycleCooldown.inMinutes - diff.inMinutes}m remaining)',
        );
        return AutoSyncDecision.suppressed;
      }
    }

    debugPrint('AutoSync requested. Debouncing...');
    cancel();
    _timer = Timer(debounceDuration, () {
      debugPrint('AutoSync triggered!');
      // Context might be stale here if widget disposed, so we don't pass
      // context from a delayed timer: pure auto sync is silent.
      unawaited(_onTrigger());
    });
    return AutoSyncDecision.scheduled;
  }

  /// 取消待执行的防抖定时器。
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// 释放调度器（取消定时器），供 Provider dispose 调用。
  void dispose() => cancel();
}
