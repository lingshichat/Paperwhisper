import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_error_classifier.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_run_outcome.dart';

void main() {
  const classifier = SyncErrorClassifier();

  group('configurationIssueMessage', () {
    test('disabled sync reports 同步未启用', () {
      expect(classifier.configurationIssueMessage(enabled: false), '同步未启用');
    });

    test('enabled sync reports configuration issue message', () {
      expect(
        classifier.configurationIssueMessage(enabled: true),
        '配置异常，请检查账号或服务器地址',
      );
    });
  });

  group('isLikelyConfigurationFailure', () {
    test('null and empty text are not configuration failures', () {
      expect(classifier.isLikelyConfigurationFailure(null), isFalse);
      expect(classifier.isLikelyConfigurationFailure(''), isFalse);
    });

    test('auth status codes and keywords are configuration failures', () {
      const configFailures = <String>[
        'HTTP 401 Unauthorized',
        '403 Forbidden',
        'unauthorized: invalid token',
        'forbidden access',
        'InvalidAccessKey',
        'InvalidAccessKeyId',
        'SignatureDoesNotMatch',
        'Access Denied',
        'Missing Credentials',
        'The specified bucket does not exist',
        'NoSuchBucket',
      ];
      for (final text in configFailures) {
        expect(
          classifier.isLikelyConfigurationFailure(text),
          isTrue,
          reason: 'expected "$text" to be a configuration failure',
        );
      }
    });

    test('transient and unknown errors are not configuration failures', () {
      expect(
        classifier.isLikelyConfigurationFailure('SocketException'),
        isFalse,
      );
      expect(classifier.isLikelyConfigurationFailure('timeout'), isFalse);
      expect(
        classifier.isLikelyConfigurationFailure('connection refused'),
        isFalse,
      );
      expect(
        classifier.isLikelyConfigurationFailure('some other error'),
        isFalse,
      );
    });
  });

  group('buildConnectionFailureMessage', () {
    test('configuration failures keep enabled-based message', () {
      expect(
        classifier.buildConnectionFailureMessage(
          '401 Unauthorized',
          enabled: true,
        ),
        '配置异常，请检查账号或服务器地址',
      );
      expect(
        classifier.buildConnectionFailureMessage(
          '401 Unauthorized',
          enabled: false,
        ),
        '同步未启用',
      );
    });

    test('network failures report 网络异常', () {
      const networkTexts = <String>[
        'SocketException: Connection refused',
        'connection timed out',
        'timed out after 30 seconds',
        'Network is unreachable',
        'Failed host lookup: dav.example.com',
        'Connection refused',
        'connection reset by peer',
      ];
      for (final text in networkTexts) {
        expect(
          classifier.buildConnectionFailureMessage(text, enabled: true),
          '网络异常，请稍后重试',
          reason: 'expected "$text" to be a network failure',
        );
      }
    });

    test('unknown errors fall back to generic connection failure', () {
      expect(
        classifier.buildConnectionFailureMessage(
          'some other error',
          enabled: true,
        ),
        '连接失败，请稍后重试',
      );
      expect(
        classifier.buildConnectionFailureMessage(null, enabled: true),
        '连接失败，请稍后重试',
      );
    });

    test('configuration check wins over network keywords', () {
      expect(
        classifier.buildConnectionFailureMessage(
          'SocketException: 403 Forbidden',
          enabled: true,
        ),
        '配置异常，请检查账号或服务器地址',
      );
    });
  });

  group('isRemoteSourceAlreadyMissing', () {
    test('404 / NoSuchKey / copy source missing are recognized', () {
      const missingSources = <Object>[
        'HTTP 404 Not Found',
        'The specified key does not exist. (NoSuchKey)',
        'Copy Source must exist',
        'The specified source bucket and key does not exist',
      ];
      for (final error in missingSources) {
        expect(
          classifier.isRemoteSourceAlreadyMissing(error),
          isTrue,
          reason: 'expected "$error" to be a missing remote source',
        );
      }
    });

    test('case-sensitive keywords are not matched loosely', () {
      expect(classifier.isRemoteSourceAlreadyMissing('not found'), isFalse);
      expect(
        classifier.isRemoteSourceAlreadyMissing('connection refused'),
        isFalse,
      );
    });
  });

  group('buildUserSafeFailureReason', () {
    SyncRunOutcome outcomeWithErrors(List<String> errors) {
      final outcome = SyncRunOutcome();
      for (final error in errors) {
        outcome.addUploadFailure(error);
      }
      return outcome;
    }

    test('invalid configuration wins over all error text', () {
      final outcome = outcomeWithErrors(const ['SocketException: boom']);
      expect(
        classifier.buildUserSafeFailureReason(
          outcome,
          configurationInvalid: true,
          hasRequiredCredentials: true,
        ),
        '配置异常，请检查账号或服务器地址',
      );
      expect(
        classifier.buildUserSafeFailureReason(
          outcome,
          configurationInvalid: false,
          hasRequiredCredentials: false,
        ),
        '配置异常，请检查账号或服务器地址',
      );
    });

    test('401 / Unauthorized maps to configuration issue', () {
      for (final errors in <List<String>>[
        ['401 Unauthorized'],
        ['Unauthorized'],
        ['401 Unauthorized', 'SocketException'],
      ]) {
        expect(
          classifier.buildUserSafeFailureReason(
            outcomeWithErrors(errors),
            configurationInvalid: false,
            hasRequiredCredentials: true,
          ),
          '配置异常，请检查账号或服务器地址',
        );
      }
    });

    test('403 / Forbidden maps to generic sync failure', () {
      for (final errors in <List<String>>[
        ['403 Forbidden'],
        ['Forbidden'],
      ]) {
        expect(
          classifier.buildUserSafeFailureReason(
            outcomeWithErrors(errors),
            configurationInvalid: false,
            hasRequiredCredentials: true,
          ),
          '同步失败，内容仍保留在本地',
        );
      }
    });

    test('network keywords map to network message', () {
      for (final errors in <List<String>>[
        ['SocketException: failed to connect'],
        ['Network is unreachable'],
        ['TimeoutException'],
      ]) {
        expect(
          classifier.buildUserSafeFailureReason(
            outcomeWithErrors(errors),
            configurationInvalid: false,
            hasRequiredCredentials: true,
          ),
          '网络异常，请稍后重试',
        );
      }
    });

    test('skipped operations report pending work', () {
      final outcome = outcomeWithErrors(const ['some transient error']);
      outcome.skippedOperations = 5;
      expect(
        classifier.buildUserSafeFailureReason(
          outcome,
          configurationInvalid: false,
          hasRequiredCredentials: true,
        ),
        '尚有内容待同步',
      );
    });

    test('unmatched errors fall back to generic sync failure', () {
      expect(
        classifier.buildUserSafeFailureReason(
          outcomeWithErrors(const ['unknown failure']),
          configurationInvalid: false,
          hasRequiredCredentials: true,
        ),
        '同步失败，内容仍保留在本地',
      );
    });
  });
}
