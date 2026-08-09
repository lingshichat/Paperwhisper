import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_run_outcome.dart';

void main() {
  group('SyncRunOutcome', () {
    test('starts with zero counters and no errors', () {
      final outcome = SyncRunOutcome();
      expect(outcome.failedUploads, 0);
      expect(outcome.failedDownloads, 0);
      expect(outcome.failedDeletes, 0);
      expect(outcome.skippedOperations, 0);
      expect(outcome.errors, isEmpty);
      expect(outcome.hasFailures, isFalse);
      expect(outcome.hasUnresolvedWork, isFalse);
    });

    test('failure counters and errors accumulate per category', () {
      final outcome = SyncRunOutcome();
      outcome.addUploadFailure('upload 1 failed');
      outcome.addUploadFailure('upload 2 failed');
      outcome.addDownloadFailure('download failed');
      outcome.addDeleteFailure('delete failed');

      expect(outcome.failedUploads, 2);
      expect(outcome.failedDownloads, 1);
      expect(outcome.failedDeletes, 1);
      expect(outcome.errors, [
        'upload 1 failed',
        'upload 2 failed',
        'download failed',
        'delete failed',
      ]);
    });

    test('hasFailures reflects any failure counter', () {
      final upload = SyncRunOutcome()..addUploadFailure('x');
      expect(upload.hasFailures, isTrue);
      expect(upload.hasUnresolvedWork, isTrue);

      final download = SyncRunOutcome()..addDownloadFailure('x');
      expect(download.hasFailures, isTrue);

      final delete = SyncRunOutcome()..addDeleteFailure('x');
      expect(delete.hasFailures, isTrue);
    });

    test('skipped operations alone count as unresolved work, not failures', () {
      final outcome = SyncRunOutcome();
      outcome.skippedOperations = 1;
      expect(outcome.hasFailures, isFalse);
      expect(outcome.hasUnresolvedWork, isTrue);
    });

    test('errors list is append-only and preserves message order', () {
      final outcome = SyncRunOutcome();
      outcome.addDeleteFailure('first');
      outcome.addDownloadFailure('second');
      expect(outcome.errors, ['first', 'second']);
      expect(outcome.failedDeletes, 1);
      expect(outcome.failedDownloads, 1);
    });
  });
}
