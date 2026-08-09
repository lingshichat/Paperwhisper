import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/sync_settings/application/sync_settings_form_controller.dart';
import 'package:paper_whisper_flutter/models/sync_config.dart';

/// 内存 fake gateway：记录调用参数，不触碰真实 IO / 插件。
class _FakeGateway implements SyncProviderGateway {
  _FakeGateway({required this.config});

  @override
  SyncConfig config;

  @override
  String lastError = '';

  bool connectResult = true;
  int saveCount = 0;
  int connectCount = 0;
  final List<SyncConfig> saved = [];
  bool throwOnSave = false;

  @override
  Future<void> saveConfig(SyncConfig newConfig) async {
    saveCount++;
    if (throwOnSave) {
      throw Exception('boom');
    }
    saved.add(newConfig);
    config = newConfig;
  }

  @override
  Future<bool> connect() async {
    connectCount++;
    return connectResult;
  }
}

void main() {
  group('hydrate / build roundtrip', () {
    test('8 字段与开关从 config 填充', () {
      final config = SyncConfig(
        autoSync: true,
        enabled: true,
        compressImages: false,
        syncType: SyncType.s3,
        serverUrl: 'https://dav.example.com/dav/',
        username: 'user',
        password: 'pass',
        s3EndPoint: 'ep.example.com',
        s3AccessKey: 'ak',
        s3SecretKey: 'sk',
        s3BucketName: 'bucket',
        s3Region: 'us-east-1',
      );
      final c = SyncSettingsFormController(config: config);

      expect(c.serverController.text, 'https://dav.example.com/dav/');
      expect(c.usernameController.text, 'user');
      expect(c.passwordController.text, 'pass');
      expect(c.s3EndPointController.text, 'ep.example.com');
      expect(c.s3AccessKeyController.text, 'ak');
      expect(c.s3SecretKeyController.text, 'sk');
      expect(c.s3BucketController.text, 'bucket');
      expect(c.s3RegionController.text, 'us-east-1');
      expect(c.autoSync, isTrue);
      expect(c.compressImages, isFalse);
      expect(c.syncType, SyncType.s3);
    });

    test('build 后 roundtrip 与输入一致（enabled 由参数控制）', () {
      final config = SyncConfig(
        autoSync: true,
        compressImages: false,
        syncType: SyncType.s3,
        serverUrl: 'https://dav.example.com/dav/',
        username: 'user',
        password: 'pass',
        s3EndPoint: 'ep.example.com',
        s3AccessKey: 'ak',
        s3SecretKey: 'sk',
        s3BucketName: 'bucket',
        s3Region: 'us-east-1',
      );
      final c = SyncSettingsFormController(config: config);
      c.serverController.text = '  https://new.example.com/dav/  ';
      c.autoSync = false;

      final rebuilt = c.buildConfig(base: config, enabled: true);

      expect(rebuilt.serverUrl, 'https://new.example.com/dav/');
      expect(rebuilt.username, 'user');
      expect(rebuilt.password, 'pass');
      expect(rebuilt.s3EndPoint, 'ep.example.com');
      expect(rebuilt.s3AccessKey, 'ak');
      expect(rebuilt.s3SecretKey, 'sk');
      expect(rebuilt.s3BucketName, 'bucket');
      expect(rebuilt.s3Region, 'us-east-1');
      expect(rebuilt.autoSync, isFalse);
      expect(rebuilt.compressImages, isFalse);
      expect(rebuilt.syncType, SyncType.s3);
      expect(rebuilt.enabled, isTrue);
    });

    test('空 region 归一为 null；未覆盖字段保留 base 默认值/secret 语义', () {
      final base = SyncConfig(); // 全默认
      final c = SyncSettingsFormController(config: base);

      final rebuilt = c.buildConfig(base: base, enabled: true);

      // 默认值语义：serverUrl 保持默认，password 空串原样透传
      expect(rebuilt.serverUrl, SyncConfig.defaultServerUrl);
      expect(rebuilt.password, '');
      expect(rebuilt.s3Region, isNull);
      expect(rebuilt.s3EndPoint, '');
      expect(rebuilt.syncType, SyncType.webdav);
      expect(rebuilt.compressImages, isTrue);
      expect(rebuilt.autoSync, isFalse);
      expect(rebuilt.enabled, isTrue);
    });

    test('base 中被覆盖字段之外的 secret 原样透传（storage key 语义）', () {
      final base = SyncConfig(
        enabled: true,
        s3SecretKey: 'persisted-sk',
        password: 'persisted-pw',
      );
      final c = SyncSettingsFormController(config: base);
      c.s3EndPointController.text = 'ep.example.com';
      c.s3AccessKeyController.text = 'ak';
      c.s3BucketController.text = 'bucket';

      final rebuilt = c.buildConfig(base: base, enabled: false);

      expect(rebuilt.s3SecretKey, 'persisted-sk');
      expect(rebuilt.password, 'persisted-pw');
      expect(rebuilt.enabled, isFalse);
    });

    test('hydrate 重新填充全部状态（bootstrap 刷新场景）', () {
      final c = SyncSettingsFormController(config: SyncConfig());
      c.serverController.text = 'draft';
      c.autoSync = true;

      c.hydrate(
        SyncConfig(
          syncType: SyncType.s3,
          serverUrl: 'https://hydrated.example.com',
          username: 'hu',
          password: 'hp',
          s3EndPoint: 'hep',
          s3AccessKey: 'hak',
          s3SecretKey: 'hsk',
          s3BucketName: 'hb',
          s3Region: 'cn-north-1',
          autoSync: true,
          compressImages: false,
        ),
      );

      expect(c.serverController.text, 'https://hydrated.example.com');
      expect(c.usernameController.text, 'hu');
      expect(c.passwordController.text, 'hp');
      expect(c.s3EndPointController.text, 'hep');
      expect(c.s3AccessKeyController.text, 'hak');
      expect(c.s3SecretKeyController.text, 'hsk');
      expect(c.s3BucketController.text, 'hb');
      expect(c.s3RegionController.text, 'cn-north-1');
      expect(c.syncType, SyncType.s3);
      expect(c.autoSync, isTrue);
      expect(c.compressImages, isFalse);
    });
  });

  group('WebDAV / S3 凭证', () {
    test('WebDAV 草稿构建后 hasRequiredCredentials 成立', () {
      final base = SyncConfig();
      final c = SyncSettingsFormController(config: base);
      c.serverController.text = 'https://dav.example.com/dav/';
      c.usernameController.text = 'user';
      c.passwordController.text = 'pass';

      final rebuilt = c.buildConfig(base: base, enabled: true);

      expect(rebuilt.syncType, SyncType.webdav);
      expect(rebuilt.hasWebDavCredentials, isTrue);
      expect(rebuilt.hasRequiredCredentials, isTrue);
    });

    test('S3 草稿构建后 hasRequiredCredentials 成立（region 可选）', () {
      final base = SyncConfig(syncType: SyncType.s3);
      final c = SyncSettingsFormController(config: base);
      c.s3EndPointController.text = 'ep.example.com';
      c.s3AccessKeyController.text = 'ak';
      c.s3SecretKeyController.text = 'sk';
      c.s3BucketController.text = 'bucket';

      final rebuilt = c.buildConfig(base: base, enabled: true);

      expect(rebuilt.syncType, SyncType.s3);
      expect(rebuilt.hasS3Credentials, isTrue);
      expect(rebuilt.hasRequiredCredentials, isTrue);
    });
  });

  group('切协议保留字段', () {
    test('setSyncType 只切协议，8 个输入与开关保留', () {
      final c = SyncSettingsFormController(config: SyncConfig());
      c.serverController.text = 'https://draft.example.com';
      c.usernameController.text = 'u';
      c.passwordController.text = 'p';
      c.s3EndPointController.text = 'ep';
      c.s3AccessKeyController.text = 'ak';
      c.s3SecretKeyController.text = 'sk';
      c.s3BucketController.text = 'bucket';
      c.s3RegionController.text = 'us-west-2';
      c.autoSync = true;
      c.compressImages = false;

      c.setSyncType(SyncType.s3);

      expect(c.syncType, SyncType.s3);
      expect(c.serverController.text, 'https://draft.example.com');
      expect(c.usernameController.text, 'u');
      expect(c.passwordController.text, 'p');
      expect(c.s3EndPointController.text, 'ep');
      expect(c.s3AccessKeyController.text, 'ak');
      expect(c.s3SecretKeyController.text, 'sk');
      expect(c.s3BucketController.text, 'bucket');
      expect(c.s3RegionController.text, 'us-west-2');
      expect(c.autoSync, isTrue);
      expect(c.compressImages, isFalse);
    });

    test('切协议后 buildConfig 反映新协议且双协议字段都保留', () {
      final base = SyncConfig();
      final c = SyncSettingsFormController(config: base);
      c.serverController.text = 'https://draft.example.com';
      c.s3EndPointController.text = 'ep.example.com';
      c.setSyncType(SyncType.s3);

      final rebuilt = c.buildConfig(base: base, enabled: true);

      expect(rebuilt.syncType, SyncType.s3);
      expect(rebuilt.serverUrl, 'https://draft.example.com');
      expect(rebuilt.s3EndPoint, 'ep.example.com');
    });
  });

  group('URL / required 边界', () {
    test('validateServerUrl 空值与空白', () {
      final c = SyncSettingsFormController(config: SyncConfig());
      expect(c.validateServerUrl(null), '请输入服务器地址');
      expect(c.validateServerUrl(''), '请输入服务器地址');
      expect(c.validateServerUrl('   '), '请输入服务器地址');
    });

    test('validateServerUrl 前缀校验', () {
      final c = SyncSettingsFormController(config: SyncConfig());
      expect(
        c.validateServerUrl('dav.example.com'),
        '服务器地址需以 http:// 或 https:// 开头',
      );
      expect(
        c.validateServerUrl('ftp://dav.example.com'),
        '服务器地址需以 http:// 或 https:// 开头',
      );
      expect(c.validateServerUrl('http://dav.example.com'), isNull);
      expect(c.validateServerUrl('https://dav.jianguoyun.com/dav/'), isNull);
    });

    test('validateRequired 边界', () {
      final c = SyncSettingsFormController(config: SyncConfig());
      expect(c.validateRequired(null, 'm'), 'm');
      expect(c.validateRequired('', 'm'), 'm');
      expect(c.validateRequired('   ', 'm'), 'm');
      expect(c.validateRequired('x', 'm'), isNull);
    });

    test('validate() 按当前协议整体校验', () {
      // WebDAV：serverUrl 默认值合法，但账号/密码为空 → 不通过
      final webdav = SyncSettingsFormController(config: SyncConfig());
      expect(webdav.validate(), isFalse);
      webdav.usernameController.text = 'u';
      webdav.passwordController.text = 'p';
      expect(webdav.validate(), isTrue);

      // S3：只填 WebDAV 字段不通过；填齐 S3 必填字段通过
      final s3 = SyncSettingsFormController(
        config: SyncConfig(syncType: SyncType.s3),
      );
      expect(s3.validate(), isFalse);
      s3.s3EndPointController.text = 'ep';
      s3.s3AccessKeyController.text = 'ak';
      s3.s3SecretKeyController.text = 'sk';
      s3.s3BucketController.text = 'bucket';
      expect(s3.validate(), isTrue);
    });

    test('S3 校验不要求 region', () {
      final s3 = SyncSettingsFormController(
        config: SyncConfig(syncType: SyncType.s3),
      );
      s3.s3EndPointController.text = 'ep';
      s3.s3AccessKeyController.text = 'ak';
      s3.s3SecretKeyController.text = 'sk';
      s3.s3BucketController.text = 'bucket';
      expect(s3.s3RegionController.text, isEmpty);
      expect(s3.validate(), isTrue);
    });
  });

  group('toggles', () {
    test('autoSync / compressImages setter 生效并写入 buildConfig', () {
      final base = SyncConfig();
      final c = SyncSettingsFormController(config: base);
      c.autoSync = true;
      c.compressImages = false;

      final rebuilt = c.buildConfig(base: base, enabled: true);

      expect(rebuilt.autoSync, isTrue);
      expect(rebuilt.compressImages, isFalse);
    });
  });

  group('dispose', () {
    test('dispose 释放全部 8 个 controller', () {
      final c = SyncSettingsFormController(config: SyncConfig());
      c.dispose();

      // ChangeNotifier 在 dispose 后 addListener 会触发
      // debugAssertNotDisposed 断言（FlutterError）。
      for (final controller in [
        c.serverController,
        c.usernameController,
        c.passwordController,
        c.s3EndPointController,
        c.s3AccessKeyController,
        c.s3SecretKeyController,
        c.s3BucketController,
        c.s3RegionController,
      ]) {
        expect(() => controller.addListener(() {}), throwsFlutterError);
      }
    });
  });

  group('gateway 动作', () {
    test('saveAndTest：保存 enabled=true 并调用 connect', () async {
      final base = SyncConfig();
      final gateway = _FakeGateway(config: base);
      final c = SyncSettingsFormController(config: base);
      c.serverController.text = 'https://dav.example.com';
      c.usernameController.text = 'u';
      c.passwordController.text = 'p';

      final outcome = await c.saveAndTest(gateway);

      expect(outcome, isA<SyncFormActionSaved>());
      expect(gateway.saveCount, 1);
      expect(gateway.connectCount, 1);
      final saved = gateway.saved.single;
      expect(saved.enabled, isTrue);
      expect(saved.serverUrl, 'https://dav.example.com');
      expect(saved.username, 'u');
      expect(saved.password, 'p');
    });

    test('saveAndTest：connect 失败 → TestFailed 携带 lastError', () async {
      final base = SyncConfig();
      final gateway = _FakeGateway(config: base)..connectResult = false;
      gateway.lastError = 'connection refused';
      final c = SyncSettingsFormController(config: base);
      c.serverController.text = 'https://dav.example.com';
      c.usernameController.text = 'u';
      c.passwordController.text = 'p';

      final outcome = await c.saveAndTest(gateway);

      expect(outcome, isA<SyncFormActionTestFailed>());
      expect(
        (outcome as SyncFormActionTestFailed).lastError,
        'connection refused',
      );
      expect(gateway.saveCount, 1);
      expect(gateway.connectCount, 1);
    });

    test('saveAndTest：校验失败 → Invalid，gateway 零调用', () async {
      final base = SyncConfig();
      final gateway = _FakeGateway(config: base);
      final c = SyncSettingsFormController(config: base); // 空表单

      final outcome = await c.saveAndTest(gateway);

      expect(outcome, isA<SyncFormActionInvalid>());
      expect(gateway.saveCount, 0);
      expect(gateway.connectCount, 0);
    });

    test('saveAndTest：异常 → Error', () async {
      final base = SyncConfig();
      final gateway = _FakeGateway(config: base)..throwOnSave = true;
      final c = SyncSettingsFormController(config: base);
      c.serverController.text = 'https://dav.example.com';
      c.usernameController.text = 'u';
      c.passwordController.text = 'p';

      final outcome = await c.saveAndTest(gateway);

      expect(outcome, isA<SyncFormActionError>());
    });

    test('disableSync：保存 enabled=false（不做校验，与页面一致）', () async {
      final base = SyncConfig();
      final gateway = _FakeGateway(config: base);
      final c = SyncSettingsFormController(config: base); // 空表单也允许停用

      final outcome = await c.disableSync(gateway);

      expect(outcome, isA<SyncFormActionSaved>());
      expect(gateway.saveCount, 1);
      expect(gateway.connectCount, 0);
      expect(gateway.saved.single.enabled, isFalse);
    });

    test('disableSync：异常 → Error', () async {
      final base = SyncConfig();
      final gateway = _FakeGateway(config: base)..throwOnSave = true;
      final c = SyncSettingsFormController(config: base);

      final outcome = await c.disableSync(gateway);

      expect(outcome, isA<SyncFormActionError>());
    });
  });
}
