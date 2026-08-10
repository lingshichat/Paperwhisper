import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/sync/presentation/sync_status_formatter.dart';
import 'package:paper_whisper_flutter/features/sync_settings/presentation/widgets/sync_settings_widgets.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_config.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_trust_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('SyncSettingsSectionTitle', () {
    testWidgets('渲染标题文本', (tester) async {
      await tester.pumpWidget(
        wrap(
          const SyncSettingsSectionTitle(
            title: 'WebDAV 服务器配置',
            color: Colors.black,
          ),
        ),
      );
      expect(find.text('WebDAV 服务器配置'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SyncSettingsTextField', () {
    testWidgets('渲染 label/hint/icon 且输入可见', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        wrap(
          SyncSettingsTextField(
            controller: controller,
            label: '服务器地址',
            hint: '例如: https://dav.jianguoyun.com/dav/',
            icon: Icons.link,
            textColor: Colors.black,
            borderColor: Colors.grey,
            fillColor: Colors.white,
          ),
        ),
      );
      expect(find.text('服务器地址'), findsOneWidget);
      expect(find.text('例如: https://dav.jianguoyun.com/dav/'), findsOneWidget);
      expect(find.byIcon(Icons.link), findsOneWidget);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).obscureText,
        isFalse,
      );
    });

    testWidgets('obscureText 生效', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        wrap(
          SyncSettingsTextField(
            controller: controller,
            label: '密码 / 应用授权码',
            hint: '坚果云请使用"第三方应用密码"',
            icon: Icons.lock_outline,
            textColor: Colors.black,
            borderColor: Colors.grey,
            fillColor: Colors.white,
            obscureText: true,
          ),
        ),
      );
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).obscureText,
        isTrue,
      );
    });

    testWidgets('validator 在 Form 校验时被调用', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final formKey = GlobalKey<FormState>();
      String? validatorResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: SyncSettingsTextField(
                controller: controller,
                label: '账号',
                hint: '请输入',
                icon: Icons.person_outline,
                textColor: Colors.black,
                borderColor: Colors.grey,
                fillColor: Colors.white,
                validator: (v) {
                  validatorResult = v == null || v.isEmpty ? '不能为空' : null;
                  return validatorResult;
                },
              ),
            ),
          ),
        ),
      );
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('不能为空'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('不能为空'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('SyncSettingsActionButton', () {
    testWidgets('渲染 label 并触发 onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          SyncSettingsActionButton(
            label: '立即同步',
            onTap: () => taps++,
            isPrimary: true,
            primaryGradient: null,
            primaryBtnColor: Colors.blue,
            primaryShadowColor: Colors.black38,
            secondaryBtnColor: Colors.grey.shade200,
            secondaryBtnTextColor: Colors.black87,
            secondaryBorderColor: Colors.grey,
          ),
        ),
      );
      expect(find.text('立即同步'), findsOneWidget);
      await tester.tap(find.text('立即同步'));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('onTap 为 null 时禁用点击', (tester) async {
      await tester.pumpWidget(
        wrap(
          SyncSettingsActionButton(
            label: '测试连接',
            onTap: null,
            isPrimary: false,
            primaryGradient: null,
            primaryBtnColor: null,
            primaryShadowColor: Colors.black38,
            secondaryBtnColor: Colors.grey.shade200,
            secondaryBtnTextColor: Colors.black87,
            secondaryBorderColor: Colors.grey,
          ),
        ),
      );
      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.onTap, isNull);
      await tester.tap(find.text('测试连接'), warnIfMissed: false);
      expect(tester.takeException(), isNull);
    });
  });

  group('SyncTrustStatusCard', () {
    final cases = <SyncTrustSnapshot, (String, String)>{
      const SyncTrustSnapshot(state: SyncTrustState.notEnabled): (
        '同步未启用',
        '启用后即可把本地内容同步到云端',
      ),
      const SyncTrustSnapshot(
        state: SyncTrustState.localChangesPending,
        pendingDiaryCount: 2,
      ): (
        '本地仍有内容待同步',
        '尚有 2 项待同步',
      ),
      SyncTrustSnapshot(
        state: SyncTrustState.syncedSuccessfully,
        lastSuccessfulSyncAt: DateTime(2026, 3, 12, 9, 30),
        lastSuccessfulSyncPlatform: 's3',
      ): (
        '同步状态正常',
        '最近一次成功同步：2026-3-12 9:30（S3）',
      ),
      const SyncTrustSnapshot(state: SyncTrustState.syncFailed): (
        '同步失败',
        '可使用下方“立即同步”重试',
      ),
      const SyncTrustSnapshot(state: SyncTrustState.needsAttention): (
        '需要检查同步配置',
        '需要检查同步配置',
      ),
    };

    for (final entry in cases.entries) {
      testWidgets('状态文案：${entry.key.state.name}', (tester) async {
        final cardText = const SyncStatusFormatter().buildStatusCard(entry.key);
        await tester.pumpWidget(
          wrap(
            SyncTrustStatusCard(
              cardText: cardText,
              icon: Icons.cloud_off_outlined,
              accentColor: Colors.teal,
              backgroundColor: Colors.white,
              borderColor: Colors.grey.shade300,
              textColor: Colors.black,
            ),
          ),
        );
        expect(find.text(entry.value.$1), findsOneWidget);
        expect(find.text(entry.value.$2), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('无行文案时仅渲染标题', (tester) async {
      const cardText = SyncStatusCardText(title: '同步状态正常', lines: []);
      await tester.pumpWidget(
        wrap(
          const SyncTrustStatusCard(
            cardText: cardText,
            icon: Icons.verified_outlined,
            accentColor: Colors.teal,
            backgroundColor: Colors.white,
            borderColor: Colors.grey,
            textColor: Colors.black,
          ),
        ),
      );
      expect(find.text('同步状态正常'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SyncSettingsTips', () {
    testWidgets('WebDAV 分支文案', (tester) async {
      await tester.pumpWidget(
        wrap(
          const SyncSettingsTips(
            textColor: Colors.black,
            backgroundColor: Colors.white,
            syncType: SyncType.webdav,
          ),
        ),
      );
      expect(find.text('小贴士'), findsOneWidget);
      expect(find.textContaining('坚果云 WebDAV 服务'), findsOneWidget);
      expect(find.textContaining('第三方应用密码'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('S3 分支文案', (tester) async {
      await tester.pumpWidget(
        wrap(
          const SyncSettingsTips(
            textColor: Colors.black,
            backgroundColor: Colors.white,
            syncType: SyncType.s3,
          ),
        ),
      );
      expect(find.textContaining('MinIO, AWS S3'), findsOneWidget);
      expect(find.textContaining('图片压缩'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SyncSettingsSwitchLabel', () {
    testWidgets('点击触发回调', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          Row(
            children: [
              SyncSettingsSwitchLabel(
                text: 'WebDAV',
                isActive: true,
                activeColor: Colors.white,
                inactiveColor: Colors.grey,
                onTap: () => taps++,
              ),
            ],
          ),
        ),
      );
      expect(find.text('WebDAV'), findsOneWidget);
      await tester.tap(find.text('WebDAV'));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('组合冒烟', () {
    testWidgets('Windows 桌面与 Android 360 逻辑宽度下无溢出', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final cardText = const SyncStatusFormatter().buildStatusCard(
        const SyncTrustSnapshot(state: SyncTrustState.syncedSuccessfully),
      );

      final views = <(Size, double, TargetPlatform)>[
        (const Size(1280, 720), 1.0, TargetPlatform.windows),
        (const Size(1080, 2400), 3.0, TargetPlatform.android),
      ];

      for (final (size, dpr, platform) in views) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = dpr;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SyncSettingsSectionTitle(
                      title: 'WebDAV 服务器配置',
                      color: Colors.black,
                    ),
                    SyncSettingsTextField(
                      controller: controller,
                      label: '服务器地址',
                      hint: '例如: https://dav.jianguoyun.com/dav/',
                      icon: Icons.link,
                      textColor: Colors.black,
                      borderColor: Colors.grey,
                      fillColor: Colors.white,
                    ),
                    SyncTrustStatusCard(
                      cardText: cardText,
                      icon: Icons.verified_outlined,
                      accentColor: Colors.teal,
                      backgroundColor: Colors.white,
                      borderColor: Colors.grey.shade300,
                      textColor: Colors.black,
                    ),
                    const SyncSettingsTips(
                      textColor: Colors.black,
                      backgroundColor: Colors.white,
                      syncType: SyncType.webdav,
                    ),
                    SyncSettingsActionButton(
                      label: '立即同步',
                      onTap: () {},
                      isPrimary: true,
                      primaryGradient: null,
                      primaryBtnColor: Colors.blue,
                      primaryShadowColor: Colors.black38,
                      secondaryBtnColor: Colors.grey.shade200,
                      secondaryBtnTextColor: Colors.black87,
                      secondaryBorderColor: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
