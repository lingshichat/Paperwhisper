import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/update/application/update_check_coordinator.dart';
import 'package:paper_whisper_flutter/models/update_info.dart';

/// UpdateCheckCoordinator 行为刻画测试。
///
/// 覆盖：
/// - checkAuto 的 available / upToDate / failure 三分支与 purpose 级
///   会话去重（成功后跳过、失败回滚可重试）；
/// - delay seam 注入（原 moments 2s / splash 1s 时序可测）；
/// - checkManual 不受去重限制。
///
/// 通过注入 [UpdateCheckGateway] 与 delay seam 完全绕开网络与
/// UpdateService 单例，全部用例 context-free。
void main() {
  UpdateInfo sampleInfo() {
    return UpdateInfo(
      latestVersion: '2.0.0',
      isForceUpdate: false,
      changelog: const ['修复若干问题'],
      downloadUrl: const {'android': 'https://example.com/app.apk'},
      backupUrl: const {'android': ''},
    );
  }

  group('checkAuto 三分支', () {
    test('有新版本：返回 UpdateCheckAvailable 携带 info 与当前版本', () async {
      final gateway = _FakeGateway(info: sampleInfo(), currentVersion: '1.0.0');
      final coordinator = UpdateCheckCoordinator(
        gateway: gateway,
        sessionCheckedPurposes: <String>{},
      );

      final outcome = await coordinator.checkAuto(purpose: 'moments');

      expect(outcome, isA<UpdateCheckAvailable>());
      final available = outcome as UpdateCheckAvailable;
      expect(available.info.latestVersion, '2.0.0');
      expect(available.currentVersion, '1.0.0');
      expect(gateway.checkCalls, 1);
      expect(gateway.versionCalls, 1);
    });

    test('已是最新：返回 UpdateCheckUpToDate 且不取当前版本', () async {
      final gateway = _FakeGateway(info: null, currentVersion: '1.0.0');
      final coordinator = UpdateCheckCoordinator(
        gateway: gateway,
        sessionCheckedPurposes: <String>{},
      );

      final outcome = await coordinator.checkAuto(purpose: 'moments');

      expect(outcome, isA<UpdateCheckUpToDate>());
      expect(gateway.versionCalls, 0);
    });

    test('网络异常：返回 UpdateCheckFailure 且去重回滚（可重试）', () async {
      final gateway = _FakeGateway(
        info: null,
        currentVersion: '1.0.0',
        error: Exception('network down'),
      );
      final coordinator = UpdateCheckCoordinator(
        gateway: gateway,
        sessionCheckedPurposes: <String>{},
      );

      final first = await coordinator.checkAuto(purpose: 'moments');
      expect(first, isA<UpdateCheckFailure>());

      // 失败后去重标记已回滚：第二次仍会执行检查
      gateway.error = null;
      gateway.info = sampleInfo();
      final second = await coordinator.checkAuto(purpose: 'moments');
      expect(second, isA<UpdateCheckAvailable>());
      expect(gateway.checkCalls, 2);
    });

    test(
      'getCurrentVersion 失败：返回 UpdateCheckFailure（settings 手动检查同路径）',
      () async {
        final gateway = _FakeGateway(
          info: sampleInfo(),
          currentVersion: '1.0.0',
          versionError: Exception('version read failed'),
        );
        final coordinator = UpdateCheckCoordinator(
          gateway: gateway,
          sessionCheckedPurposes: <String>{},
        );

        final auto = await coordinator.checkAuto(purpose: 'moments');
        expect(auto, isA<UpdateCheckFailure>());

        final manual = await coordinator.checkManual();
        expect(manual, isA<UpdateCheckFailure>());
        expect(gateway.checkCalls, 2);
        expect(gateway.versionCalls, 2);
      },
    );
  });

  group('checkAuto 会话级去重', () {
    test('成功后同 purpose 再次调用返回 UpdateCheckSkipped', () async {
      final gateway = _FakeGateway(info: sampleInfo(), currentVersion: '1.0.0');
      final coordinator = UpdateCheckCoordinator(
        gateway: gateway,
        sessionCheckedPurposes: <String>{},
      );

      await coordinator.checkAuto(purpose: 'moments');
      final second = await coordinator.checkAuto(purpose: 'moments');

      expect(second, isA<UpdateCheckSkipped>());
      expect(gateway.checkCalls, 1, reason: '去重后不重复请求');
    });

    test('不同 purpose 互不遮蔽（不能漏更新）', () async {
      final gateway = _FakeGateway(info: sampleInfo(), currentVersion: '1.0.0');
      final coordinator = UpdateCheckCoordinator(
        gateway: gateway,
        sessionCheckedPurposes: <String>{},
      );

      await coordinator.checkAuto(purpose: 'splash');
      final other = await coordinator.checkAuto(purpose: 'diary-list');

      expect(other, isA<UpdateCheckAvailable>());
      expect(gateway.checkCalls, 2);
    });

    test('注入独立去重集合时互不影响（测试隔离）', () async {
      final gateway = _FakeGateway(info: null, currentVersion: '1.0.0');
      final a = UpdateCheckCoordinator(
        gateway: gateway,
        sessionCheckedPurposes: <String>{},
      );
      final b = UpdateCheckCoordinator(
        gateway: gateway,
        sessionCheckedPurposes: <String>{},
      );

      await a.checkAuto(purpose: 'moments');
      final outcomeB = await b.checkAuto(purpose: 'moments');

      expect(outcomeB, isA<UpdateCheckUpToDate>());
      expect(gateway.checkCalls, 2);
    });
  });

  group('delay seam', () {
    test('delay 在检查前执行并保留原时序参数', () async {
      final gateway = _FakeGateway(info: sampleInfo(), currentVersion: '1.0.0');
      final delays = <Duration>[];
      final coordinator = UpdateCheckCoordinator(
        gateway: gateway,
        delay: (d) async {
          delays.add(d);
        },
        sessionCheckedPurposes: <String>{},
      );

      await coordinator.checkAuto(
        purpose: 'moments',
        delay: const Duration(seconds: 2),
      );

      expect(delays, [const Duration(seconds: 2)]);
      expect(gateway.checkCalls, 1);
    });

    test('delay 为零时不调用延迟 seam', () async {
      final gateway = _FakeGateway(info: sampleInfo(), currentVersion: '1.0.0');
      var delayCalls = 0;
      final coordinator = UpdateCheckCoordinator(
        gateway: gateway,
        delay: (d) async {
          delayCalls++;
        },
        sessionCheckedPurposes: <String>{},
      );

      await coordinator.checkAuto(purpose: 'diary-list');

      expect(delayCalls, 0);
    });
  });

  group('checkManual 不受去重限制', () {
    test('自动检查成功后手动检查仍执行', () async {
      final gateway = _FakeGateway(info: null, currentVersion: '1.0.0');
      final coordinator = UpdateCheckCoordinator(
        gateway: gateway,
        sessionCheckedPurposes: <String>{},
      );

      await coordinator.checkAuto(purpose: 'moments');
      final manual = await coordinator.checkManual();

      expect(manual, isA<UpdateCheckUpToDate>());
      expect(gateway.checkCalls, 2);
    });

    test('手动检查三分支：available / upToDate / failure', () async {
      final coordinator = UpdateCheckCoordinator(
        gateway: _FakeGateway(info: sampleInfo(), currentVersion: '1.0.0'),
        sessionCheckedPurposes: <String>{},
      );
      expect(await coordinator.checkManual(), isA<UpdateCheckAvailable>());

      final upToDate = UpdateCheckCoordinator(
        gateway: _FakeGateway(info: null, currentVersion: '1.0.0'),
        sessionCheckedPurposes: <String>{},
      );
      expect(await upToDate.checkManual(), isA<UpdateCheckUpToDate>());

      final failing = UpdateCheckCoordinator(
        gateway: _FakeGateway(
          info: null,
          currentVersion: '1.0.0',
          error: Exception('boom'),
        ),
        sessionCheckedPurposes: <String>{},
      );
      expect(await failing.checkManual(), isA<UpdateCheckFailure>());
    });
  });
}

/// 可脚本化的网关替身：控制 info / 版本 / 异常与调用计数。
class _FakeGateway implements UpdateCheckGateway {
  _FakeGateway({
    required this.info,
    required this.currentVersion,
    this.error,
    this.versionError,
  });

  UpdateInfo? info;
  String currentVersion;
  Object? error;

  /// 非 null 时 [getCurrentVersion] 抛出该错误（模拟版本读取失败）。
  Object? versionError;

  int checkCalls = 0;
  int versionCalls = 0;

  @override
  Future<UpdateInfo?> checkForUpdate() async {
    checkCalls++;
    if (error != null) throw error!;
    return info;
  }

  @override
  Future<String> getCurrentVersion() async {
    versionCalls++;
    if (versionError != null) throw versionError!;
    return currentVersion;
  }
}
