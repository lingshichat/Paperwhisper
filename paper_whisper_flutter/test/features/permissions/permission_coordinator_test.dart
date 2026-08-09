import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/permissions/application/permission_coordinator.dart';
import 'package:permission_handler/permission_handler.dart';

/// PermissionCoordinator 行为刻画测试。
///
/// 覆盖：
/// - `checkAll` 三权限快照：grantedCount 计数（photos 含 limited）、
///   isAllGranted 与 summary 文案（settings 原语义逐字）；
/// - `isStorageGranted` 分支；
/// - `requestPermission` 三分支：granted / denied / permanentlyDenied；
/// - 鸿蒙判定 seam 委托。
///
/// 全部通过注入 status / request / isHarmonyOS seam 驱动，无平台依赖。
void main() {
  group('checkAll 快照', () {
    test('全授权：grantedCount=3、isAllGranted=true、summary 文案', () async {
      final coordinator = PermissionCoordinator(
        statusOf: (_) async => PermissionStatus.granted,
      );

      final snapshot = await coordinator.checkAll();

      expect(snapshot.grantedCount, 3);
      expect(snapshot.isAllGranted, isTrue);
      expect(snapshot.summary, '权限状态: 3 / 3 已获取');
    });

    test('photos 为 limited 时计入 grantedCount', () async {
      final coordinator = PermissionCoordinator(
        statusOf: (p) async {
          if (p == Permission.photos) return PermissionStatus.limited;
          return PermissionStatus.granted;
        },
      );

      final snapshot = await coordinator.checkAll();

      expect(snapshot.grantedCount, 3);
      expect(snapshot.photos.isLimited, isTrue);
    });

    test('storage 未授权：isAllGranted=false（settings 核心权限语义）', () async {
      final coordinator = PermissionCoordinator(
        statusOf: (p) async {
          if (p == Permission.manageExternalStorage) {
            return PermissionStatus.denied;
          }
          return PermissionStatus.granted;
        },
      );

      final snapshot = await coordinator.checkAll();

      expect(snapshot.grantedCount, 2);
      expect(snapshot.isAllGranted, isFalse);
      expect(snapshot.summary, '权限状态: 2 / 3 已获取');
    });
  });

  group('isStorageGranted', () {
    test('storage granted 返回 true', () async {
      final coordinator = PermissionCoordinator(
        statusOf: (_) async => PermissionStatus.granted,
      );

      expect(await coordinator.isStorageGranted(), isTrue);
    });

    test('storage denied 返回 false', () async {
      final coordinator = PermissionCoordinator(
        statusOf: (_) async => PermissionStatus.denied,
      );

      expect(await coordinator.isStorageGranted(), isFalse);
    });
  });

  group('requestPermission 三分支', () {
    test('granted → PermissionRequestOutcome.granted', () async {
      final coordinator = PermissionCoordinator(
        request: (_) async => PermissionStatus.granted,
      );

      final outcome = await coordinator.requestPermission(
        Permission.manageExternalStorage,
      );

      expect(outcome, PermissionRequestOutcome.granted);
    });

    test('denied → PermissionRequestOutcome.denied', () async {
      final coordinator = PermissionCoordinator(
        request: (_) async => PermissionStatus.denied,
      );

      final outcome = await coordinator.requestPermission(
        Permission.manageExternalStorage,
      );

      expect(outcome, PermissionRequestOutcome.denied);
    });

    test(
      'limited → PermissionRequestOutcome.denied（真实契约：limited 不算 granted）',
      () async {
        final coordinator = PermissionCoordinator(
          request: (_) async => PermissionStatus.limited,
        );

        final outcome = await coordinator.requestPermission(
          Permission.manageExternalStorage,
        );

        expect(outcome, PermissionRequestOutcome.denied);
      },
    );

    test(
      'permanentlyDenied → PermissionRequestOutcome.permanentlyDenied',
      () async {
        final coordinator = PermissionCoordinator(
          request: (_) async => PermissionStatus.permanentlyDenied,
        );

        final outcome = await coordinator.requestPermission(
          Permission.manageExternalStorage,
        );

        expect(outcome, PermissionRequestOutcome.permanentlyDenied);
      },
    );
  });

  group('isHarmonyOS seam', () {
    test('委托注入的判定函数', () async {
      final coordinator = PermissionCoordinator(isHarmonyOS: () async => true);

      expect(await coordinator.isHarmonyOS(), isTrue);
    });

    test('默认鸿蒙 false（非 Android 分支语义）', () async {
      final coordinator = PermissionCoordinator(isHarmonyOS: () async => false);

      expect(await coordinator.isHarmonyOS(), isFalse);
    });
  });
}
