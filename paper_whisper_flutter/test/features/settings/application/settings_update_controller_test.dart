import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/models/update_info.dart';
import 'package:paper_whisper_flutter/features/settings/application/settings_update_controller.dart';
import 'package:paper_whisper_flutter/features/update/application/update_check_coordinator.dart';

/// 注入替身：经 UpdateCheckCoordinator 的 gateway seam，不触碰网络 / IO。
class _FakeUpdateGateway implements UpdateCheckGateway {
  UpdateInfo? info;
  String version = '1.0.0';
  bool throwOnCheck = false;
  bool throwOnVersion = false;
  Completer<void>? gate;
  int checkCalls = 0;

  @override
  Future<UpdateInfo?> checkForUpdate() async {
    checkCalls++;
    if (gate != null) await gate!.future;
    if (throwOnCheck) throw Exception('check boom');
    return info;
  }

  @override
  Future<String> getCurrentVersion() async {
    if (throwOnVersion) throw Exception('version boom');
    return version;
  }
}

UpdateInfo _info() => UpdateInfo(
  latestVersion: '2.0.0',
  isForceUpdate: false,
  changelog: const ['fix'],
  downloadUrl: const {'android': 'https://example.com/app.apk'},
  backupUrl: const {},
);

void main() {
  group('SettingsUpdateController.manualCheck', () {
    test('available：返回 info + 当前版本，并缓存 currentVersion', () async {
      final gateway = _FakeUpdateGateway()..info = _info();
      final controller = SettingsUpdateController(
        coordinator: UpdateCheckCoordinator(gateway: gateway),
      );

      final outcome = await controller.manualCheck();

      expect(outcome, isA<SettingsUpdateAvailable>());
      final available = outcome as SettingsUpdateAvailable;
      expect(available.info.latestVersion, '2.0.0');
      expect(available.currentVersion, '1.0.0');
      expect(controller.currentVersion, '1.0.0');
      expect(controller.checking, isFalse);
    });

    test('upToDate：无新版本', () async {
      final gateway = _FakeUpdateGateway();
      final controller = SettingsUpdateController(
        coordinator: UpdateCheckCoordinator(gateway: gateway),
      );

      expect(await controller.manualCheck(), isA<SettingsUpdateUpToDate>());
      expect(controller.checking, isFalse);
    });

    test('failure：检查异常转 typed failure，finally 复位 checking', () async {
      final gateway = _FakeUpdateGateway()..throwOnCheck = true;
      final controller = SettingsUpdateController(
        coordinator: UpdateCheckCoordinator(gateway: gateway),
      );

      final outcome = await controller.manualCheck();

      expect(outcome, isA<SettingsUpdateFailure>());
      expect((outcome as SettingsUpdateFailure).error, isNotNull);
      expect(controller.checking, isFalse);
    });

    test('currentVersion 失败：转 typed failure，不缓存版本，finally 复位', () async {
      final gateway = _FakeUpdateGateway()..throwOnVersion = true;
      final controller = SettingsUpdateController(
        coordinator: UpdateCheckCoordinator(gateway: gateway),
      );

      final outcome = await controller.manualCheck();

      expect(outcome, isA<SettingsUpdateFailure>());
      expect(controller.currentVersion, isNull);
      expect(controller.checking, isFalse);
    });

    test('并发调用：进行中返回 busy typed 结果（页面禁用语义）', () async {
      final gateway = _FakeUpdateGateway()
        ..info = _info()
        ..gate = Completer();
      final controller = SettingsUpdateController(
        coordinator: UpdateCheckCoordinator(gateway: gateway),
      );

      final first = controller.manualCheck();
      await Future<void>.delayed(Duration.zero);
      expect(controller.checking, isTrue);

      final second = await controller.manualCheck();
      expect(second, isA<SettingsUpdateBusy>());

      gateway.gate!.complete();
      expect(await first, isA<SettingsUpdateAvailable>());
      expect(controller.checking, isFalse);
    });

    test('异常路径 finally：失败后 checking 复位，可再次检查', () async {
      final gateway = _FakeUpdateGateway()..throwOnCheck = true;
      final controller = SettingsUpdateController(
        coordinator: UpdateCheckCoordinator(gateway: gateway),
      );

      await controller.manualCheck();
      expect(controller.checking, isFalse);

      // 第二次检查（gateway 恢复正常）应成功，不被上次失败卡死。
      gateway.throwOnCheck = false;
      gateway.info = _info();
      expect(await controller.manualCheck(), isA<SettingsUpdateAvailable>());
    });

    test(
      'manualCheck 中途 dispose：Future 以 StateError 结束，finally 不再写 checking',
      () async {
        final gateway = _FakeUpdateGateway()
          ..info = _info()
          ..gate = Completer();
        final controller = SettingsUpdateController(
          coordinator: UpdateCheckCoordinator(gateway: gateway),
        );

        final future = controller.manualCheck();
        await Future<void>.delayed(Duration.zero);
        expect(controller.checking, isTrue);

        // 检查进行中 dispose：Future 按既定 StateError 结束。
        controller.dispose();
        gateway.gate!.complete();

        await expectLater(future, throwsStateError);
        // dispose 后 finally 不再写 checking：状态冻结在 dispose 时刻，不复活。
        expect(controller.checking, isTrue);
      },
    );

    test('dispose 后 manualCheck 抛 StateError，不产生状态变更', () async {
      final gateway = _FakeUpdateGateway();
      final controller = SettingsUpdateController(
        coordinator: UpdateCheckCoordinator(gateway: gateway),
      );

      controller.dispose();
      await expectLater(controller.manualCheck(), throwsStateError);
      expect(controller.checking, isFalse);
      expect(controller.currentVersion, isNull);
    });
  });
}
