/// 同步进度跟踪器（无 UI 依赖，可独立单测）。
///
/// 封装单文件传输统计、瞬时速度、ETA 与整体进度计算。
/// 公式、500ms 节流与文案均从 `SyncProvider` 原实现逐字迁移：
/// - `reset`               原 `_resetTransferStats`（187-200）
/// - `onFileProgress`      原 `_onTransferProgress`（202-228）
/// - `_updateSpeedAndETA`  原同名方法（230-272）
/// - `_formatSpeed`        原同名方法（274-281）
/// - `resetCurrentFile`    原 `_resetCurrentFileStats`（291-298）
/// - `totalProgress`       原 getter（149-155）
///
/// 状态变更通过 [onChanged] 回调对外通知（由 Provider 注入
/// `notifyListeners`），跟踪器本身不依赖 ChangeNotifier。
class SyncProgressTracker {
  SyncProgressTracker({void Function()? onChanged}) : _onChanged = onChanged;

  final void Function()? _onChanged;

  // 单文件传输统计
  double _currentFileProgress = 0.0;
  String _currentFileSpeed = '';
  int _lastBytesCount = 0;
  DateTime? _lastSpeedUpdate;

  // 整体进度与 ETA
  int _totalOps = 0;
  int _processedOps = 0;
  DateTime? _batchStartTime;
  String _etaMessage = '';

  double get currentFileProgress => _currentFileProgress;
  String get currentFileSpeed => _currentFileSpeed;

  /// Total Progress (0.0 - 1.0)
  /// Formula: (processed + currentFilePart) / total
  double get totalProgress {
    if (_totalOps == 0) return 0.0;
    // Cap currentFileProgress to 1.0 just in case
    final double filePart = _currentFileProgress.clamp(0.0, 1.0);
    return (_processedOps + filePart) / _totalOps;
  }

  String get etaMessage => _etaMessage;
  int get totalOps => _totalOps;
  int get processedOps => _processedOps;

  /// 重置传输统计并开始新一批操作。
  void reset(int totalOperations) {
    _currentFileProgress = 0.0;
    _currentFileSpeed = '';
    _lastBytesCount = 0;
    _lastSpeedUpdate = null;

    _totalOps = totalOperations;
    _processedOps = 0;
    _batchStartTime = DateTime.now();
    _etaMessage = '计算中...';
    _onChanged?.call();
  }

  /// 单文件进度回调（作为 upload/download 的 onProgress 传入）。
  /// 每 500ms 节流刷新速度与 ETA。
  void onFileProgress(int count, int total) {
    final now = DateTime.now();

    // Calculate Progress
    if (total > 0) {
      _currentFileProgress = count / total;
    } else {
      _currentFileProgress = 0.0;
    }

    // Initial speed display
    if (_currentFileSpeed.isEmpty) {
      _currentFileSpeed = "计算中...";
    }

    // Update Speed & ETA every 500ms
    if (_lastSpeedUpdate == null ||
        now.difference(_lastSpeedUpdate!).inMilliseconds >= 500) {
      _updateSpeedAndETA(now, count);
      _lastSpeedUpdate = now;
      _lastBytesCount = count;
      _onChanged?.call();
    }
  }

  /// 完成一个批次项时调用（仅递增计数，不触发通知，
  /// 等待下一次节流刷新或 reset 时统一通知，与原实现一致）。
  void markItemProcessed() {
    _processedOps++;
  }

  /// 重置当前文件统计（循环迭代开始时调用）。
  void resetCurrentFile() {
    _currentFileProgress = 0.0;
    _currentFileSpeed = '';
    _lastBytesCount = 0;
    _lastSpeedUpdate = null;
    _onChanged?.call();
  }

  void _updateSpeedAndETA(DateTime now, int count) {
    // 1. Calculate Instant Speed
    if (_lastSpeedUpdate != null && count > _lastBytesCount) {
      final diffMs = now.difference(_lastSpeedUpdate!).inMilliseconds;
      if (diffMs > 0) {
        final bytesDiff = count - _lastBytesCount;
        final speedBytesPerSec = (bytesDiff / diffMs) * 1000;
        _currentFileSpeed = _formatSpeed(speedBytesPerSec);
      }
    }

    // 2. Calculate ETA based on Item Count
    // (Since we don't know total bytes size for downloads)
    if (_batchStartTime != null &&
        _processedOps > 0 &&
        _totalOps > _processedOps) {
      final elapsedMs = now.difference(_batchStartTime!).inMilliseconds;
      // Time per item = elapsed / processed
      final msPerItem = elapsedMs / _processedOps; // Simple average
      final remainingItems = _totalOps - _processedOps;

      // Deduct current item progress from remaining time?
      // Let's keep it simple: ETA based on full completed items is more stable.
      // Refined: time = avg * (remaining - currentPart)
      final estimatedRemainingMs =
          msPerItem * (remainingItems - _currentFileProgress);

      if (estimatedRemainingMs > 0) {
        final duration = Duration(milliseconds: estimatedRemainingMs.toInt());
        if (duration.inHours > 0) {
          _etaMessage =
              '剩余 ${duration.inHours} 小时 ${duration.inMinutes % 60} 分';
        } else if (duration.inMinutes > 0) {
          _etaMessage =
              '剩余 ${duration.inMinutes} 分 ${duration.inSeconds % 60} 秒';
        } else {
          _etaMessage = '剩余 ${duration.inSeconds} 秒';
        }
      }
    } else if (_processedOps == 0) {
      _etaMessage = '计算中...';
    } else {
      _etaMessage = '即将完成';
    }
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024) return "${bytesPerSec.toStringAsFixed(0)} B/s";
    if (bytesPerSec < 1024 * 1024) {
      return "${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s";
    }
    return "${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s";
  }
}
