/// 单次同步运行的结果汇总（原定义于 sync_provider.dart，随同步域拆分迁出）。
/// 计数与错误语义保持不变，后续由 [SyncRunner] 持有。
class SyncRunOutcome {
  int failedUploads = 0;
  int failedDownloads = 0;
  int failedDeletes = 0;
  int skippedOperations = 0;
  final List<String> errors = <String>[];

  bool get hasFailures =>
      failedUploads > 0 || failedDownloads > 0 || failedDeletes > 0;

  bool get hasUnresolvedWork => hasFailures || skippedOperations > 0;

  void addUploadFailure(String message) {
    failedUploads++;
    errors.add(message);
  }

  void addDownloadFailure(String message) {
    failedDownloads++;
    errors.add(message);
  }

  void addDeleteFailure(String message) {
    failedDeletes++;
    errors.add(message);
  }
}
