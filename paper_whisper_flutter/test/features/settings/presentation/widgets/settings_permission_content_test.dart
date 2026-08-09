import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:paper_whisper_flutter/features/permissions/application/permission_coordinator.dart';
import 'package:paper_whisper_flutter/features/settings/application/settings_permission_controller.dart';
import 'package:paper_whisper_flutter/features/settings/presentation/widgets/settings_permission_content.dart';

void main() {
  setUp(() {
    // 测试环境禁用运行时字体拉取，避免网络请求与字体加载噪音。
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const textColor = Color(0xFF3E3A36);
  const dividerColor = Color(0xFFE0D5C3);

  Widget wrap(Widget child, {double width = 800, double height = 600}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );
  }

  Widget buildContent(
    PermissionSnapshot snapshot, {
    ValueChanged<SettingsPermissionKind>? onRequest,
  }) {
    return SettingsPermissionContent(
      snapshot: snapshot,
      textColor: textColor,
      dividerColor: dividerColor,
      onRequest: onRequest ?? (_) {},
    );
  }

  const granted = PermissionStatus.granted;
  const denied = PermissionStatus.denied;
  const limited = PermissionStatus.limited;

  group('SettingsPermissionContent', () {
    testWidgets('全部授权时三行显示「已获取」且无「去授权」按钮', (tester) async {
      final snapshot = PermissionSnapshot(
        storage: granted,
        photos: granted,
        notification: granted,
      );
      await tester.pumpWidget(wrap(buildContent(snapshot)));

      expect(find.text('文件存储 (核心)'), findsOneWidget);
      expect(find.text('用于日记数据的读取与备份'), findsOneWidget);
      expect(find.text('相册访问'), findsOneWidget);
      expect(find.text('通知提醒'), findsOneWidget);
      expect(find.text('已获取'), findsNWidgets(3));
      expect(find.text('去授权'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('全部未授权时三行显示「去授权」按钮', (tester) async {
      final snapshot = PermissionSnapshot(
        storage: denied,
        photos: denied,
        notification: denied,
      );
      await tester.pumpWidget(wrap(buildContent(snapshot)));

      expect(find.text('已获取'), findsNothing);
      expect(find.text('去授权'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('photos 部分允许时按原行为显示「去授权」', (tester) async {
      final snapshot = PermissionSnapshot(
        storage: granted,
        photos: limited,
        notification: granted,
      );
      await tester.pumpWidget(wrap(buildContent(snapshot)));

      // 原实现 trailing 仅 granted 分支渲染状态文字；limited 仍走去授权分支。
      expect(find.text('已获取'), findsNWidgets(2));
      expect(find.text('去授权'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('点击各「去授权」按对应 kind 触发 onRequest', (tester) async {
      final snapshot = PermissionSnapshot(
        storage: granted,
        photos: denied,
        notification: denied,
      );
      final requested = <SettingsPermissionKind>[];
      await tester.pumpWidget(
        wrap(buildContent(snapshot, onRequest: requested.add)),
      );

      // storage 已授权，无按钮；photos / notification 各一个。
      await tester.tap(find.text('去授权').first);
      await tester.pump();
      await tester.tap(find.text('去授权').last);
      await tester.pump();

      expect(requested, [
        SettingsPermissionKind.photos,
        SettingsPermissionKind.notification,
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('全部授权态（isAllGranted）可被上层读取', (tester) async {
      final snapshot = PermissionSnapshot(
        storage: granted,
        photos: granted,
        notification: granted,
      );
      expect(snapshot.isAllGranted, isTrue);
      expect(snapshot.summary, '权限状态: 3 / 3 已获取');

      final partial = PermissionSnapshot(
        storage: granted,
        photos: denied,
        notification: denied,
      );
      expect(partial.isAllGranted, isFalse);
      expect(partial.summary, '权限状态: 1 / 3 已获取');

      // 组件在两种快照下均正常渲染。
      await tester.pumpWidget(wrap(buildContent(partial)));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '权限行样式契约：contentPadding 4/4、leading 8+alpha0.05+radius8+icon20、title15 bold、subtitle11、trailing 12 bold',
      (tester) async {
        final snapshot = PermissionSnapshot(
          storage: denied,
          photos: denied,
          notification: denied,
        );
        await tester.pumpWidget(wrap(buildContent(snapshot)));

        // 每行均为 ListTile，contentPadding 与原 `_buildPermissionRow` 一致。
        final tiles = tester
            .widgetList<ListTile>(find.byType(ListTile))
            .toList();
        expect(tiles, hasLength(3));
        for (final tile in tiles) {
          expect(
            tile.contentPadding,
            const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            reason: '权限行 contentPadding 应为 4/4',
          );
        }

        // leading：8 padding 容器 + alpha0.05 背景 + radius8，图标 size20 原色。
        final leadingBoxes = tester
            .widgetList<Container>(
              find.byWidgetPredicate(
                (w) => w is Container && w.padding == const EdgeInsets.all(8),
              ),
            )
            .toList();
        expect(leadingBoxes, hasLength(3));
        for (final box in leadingBoxes) {
          final deco = box.decoration! as BoxDecoration;
          expect(deco.color, textColor.withValues(alpha: 0.05));
          expect(deco.borderRadius, BorderRadius.circular(8));
        }
        for (final icon in [
          Icons.folder_copy_outlined,
          Icons.photo_library_outlined,
          Icons.notifications_outlined,
        ]) {
          final iconWidget = tester.widget<Icon>(find.byIcon(icon));
          expect(iconWidget.size, 20);
          expect(iconWidget.color, textColor);
        }

        // title 15 bold 原色；subtitle 11 alpha0.6。
        final titles = ['文件存储 (核心)', '相册访问', '通知提醒'];
        for (final t in titles) {
          final titleText = tester.widget<Text>(find.text(t));
          expect(titleText.style?.fontSize, 15);
          expect(titleText.style?.fontWeight, FontWeight.bold);
          expect(titleText.style?.color, textColor);
        }
        final subtitles = ['用于日记数据的读取与备份', '用于在日记中插入图片', '显示数据同步进度与状态'];
        for (final s in subtitles) {
          final subText = tester.widget<Text>(find.text(s));
          expect(subText.style?.fontSize, 11);
          expect(subText.style?.color, textColor.withValues(alpha: 0.6));
        }

        // trailing 去授权按钮文案 12 bold。
        final grantText = tester.widget<Text>(find.text('去授权').first);
        expect(grantText.style?.fontSize, 12);
        expect(grantText.style?.fontWeight, FontWeight.bold);
      },
    );

    testWidgets('置于带背景 DecoratedBox 内不触发 ListTile 断言（透明 Material 包裹）', (
      tester,
    ) async {
      final snapshot = PermissionSnapshot(
        storage: denied,
        photos: denied,
        notification: denied,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFFF9F5EC)),
              child: buildContent(snapshot),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Windows 与 Android 360 宽度下无 overflow', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final snapshot = PermissionSnapshot(
        storage: denied,
        photos: denied,
        notification: denied,
      );

      for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: Center(
                child: SizedBox(width: 360, child: buildContent(snapshot)),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });
}
