import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/permissions/application/permission_coordinator.dart';
import 'package:paper_whisper_flutter/features/settings/application/settings_permission_controller.dart';
import 'package:permission_handler/permission_handler.dart';

/// 注入替身：不触碰任何 plugin / IO。
class _FakePermissionGateway implements SettingsPermissionGateway {
  PermissionSnapshot? checkAllResult;
  bool throwOnCheckAll = false;
  Completer<PermissionSnapshot>? gate;
  final requestedKinds = <SettingsPermissionKind>[];
  PermissionRequestOutcome Function(SettingsPermissionKind)? onRequest;

  @override
  Future<PermissionSnapshot> checkAll() async {
    if (gate != null) return gate!.future;
    if (throwOnCheckAll) throw Exception('checkAll boom');
    return checkAllResult!;
  }

  @override
  Future<PermissionRequestOutcome> request(SettingsPermissionKind kind) async {
    requestedKinds.add(kind);
    return onRequest!(kind);
  }
}

PermissionSnapshot _snap({
  PermissionStatus storage = PermissionStatus.granted,
  PermissionStatus photos = PermissionStatus.granted,
  PermissionStatus notification = PermissionStatus.granted,
}) => PermissionSnapshot(
  storage: storage,
  photos: photos,
  notification: notification,
);

void main() {
  group('SettingsPermissionController', () {
    test('load 成功：缓存 snapshot 并返回，loading 复位', () async {
      final gateway = _FakePermissionGateway()..checkAllResult = _snap();
      final controller = SettingsPermissionController(gateway: gateway);

      final result = await controller.load();

      expect(result, same(gateway.checkAllResult));
      expect(controller.snapshot, same(result));
      expect(controller.loading, isFalse);
    });

    test('load 进行中 loading 为 true', () async {
      final gateway = _FakePermissionGateway()..gate = Completer();
      final controller = SettingsPermissionController(gateway: gateway);

      final future = controller.load();
      await Future<void>.delayed(Duration.zero);
      expect(controller.loading, isTrue);

      gateway.gate!.complete(_snap());
      final result = await future;
      expect(result.isAllGranted, isTrue);
      expect(controller.loading, isFalse);
    });

    test('load 异常：抛出且不缓存 snapshot，loading 复位', () async {
      final gateway = _FakePermissionGateway()..throwOnCheckAll = true;
      final controller = SettingsPermissionController(gateway: gateway);

      await expectLater(controller.load(), throwsException);
      expect(controller.snapshot, isNull);
      expect(controller.loading, isFalse);
    });

    test(
      'load 中途 dispose：Future 以 StateError 结束，finally 不再写 loading',
      () async {
        final gateway = _FakePermissionGateway()..gate = Completer();
        final controller = SettingsPermissionController(gateway: gateway);

        final future = controller.load();
        await Future<void>.delayed(Duration.zero);
        expect(controller.loading, isTrue);

        // 查询进行中 dispose：快照不得写入，Future 按既定 StateError 结束。
        controller.dispose();
        gateway.gate!.complete(_snap());

        await expectLater(future, throwsStateError);
        expect(controller.snapshot, isNull);
        // dispose 后 finally 不再写 loading：状态冻结在 dispose 时刻，不复活。
        expect(controller.loading, isTrue);
      },
    );

    test('request 三态：granted / denied / permanentlyDenied 透传', () async {
      final gateway = _FakePermissionGateway()
        ..onRequest = (kind) {
          switch (kind) {
            case SettingsPermissionKind.storage:
              return PermissionRequestOutcome.granted;
            case SettingsPermissionKind.photos:
              return PermissionRequestOutcome.denied;
            case SettingsPermissionKind.notification:
              return PermissionRequestOutcome.permanentlyDenied;
          }
        };
      final controller = SettingsPermissionController(gateway: gateway);

      expect(
        await controller.request(SettingsPermissionKind.storage),
        PermissionRequestOutcome.granted,
      );
      expect(
        await controller.request(SettingsPermissionKind.photos),
        PermissionRequestOutcome.denied,
      );
      expect(
        await controller.request(SettingsPermissionKind.notification),
        PermissionRequestOutcome.permanentlyDenied,
      );
      expect(gateway.requestedKinds, [
        SettingsPermissionKind.storage,
        SettingsPermissionKind.photos,
        SettingsPermissionKind.notification,
      ]);
    });

    test('request 异常：向调用方传播（页面语义不吞）', () async {
      final gateway = _FakePermissionGateway()
        ..onRequest = (_) => throw Exception('request boom');
      final controller = SettingsPermissionController(gateway: gateway);

      await expectLater(
        controller.request(SettingsPermissionKind.storage),
        throwsException,
      );
    });

    test('适配器 kind → 插件权限映射正确（不复制判定算法）', () async {
      final requested = <Permission>[];
      final coordinator = PermissionCoordinator(
        request: (permission) async {
          requested.add(permission);
          return PermissionStatus.granted;
        },
      );
      final adapter = SettingsPermissionGatewayAdapter(coordinator);

      expect(
        await adapter.request(SettingsPermissionKind.storage),
        PermissionRequestOutcome.granted,
      );
      expect(
        await adapter.request(SettingsPermissionKind.photos),
        PermissionRequestOutcome.granted,
      );
      expect(
        await adapter.request(SettingsPermissionKind.notification),
        PermissionRequestOutcome.granted,
      );
      expect(requested, [
        Permission.manageExternalStorage,
        Permission.photos,
        Permission.notification,
      ]);
    });

    test('dispose 后 load / request 抛 StateError，不产生状态变更', () async {
      final gateway = _FakePermissionGateway()
        ..checkAllResult = _snap()
        ..onRequest = (_) => PermissionRequestOutcome.granted;
      final controller = SettingsPermissionController(gateway: gateway);

      controller.dispose();
      await expectLater(controller.load(), throwsStateError);
      await expectLater(
        controller.request(SettingsPermissionKind.storage),
        throwsStateError,
      );
      expect(controller.snapshot, isNull);
    });
  });
}
