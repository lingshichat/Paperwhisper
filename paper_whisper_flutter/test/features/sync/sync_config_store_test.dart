import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_config_store.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_config.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late MemorySyncSecretStore secretStore;
  late SyncConfigStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    secretStore = MemorySyncSecretStore();
    store = SyncConfigStore(
      secretStore: secretStore,
      prefsFactory: () async => prefs,
    );
  });

  Future<void> seedPrefs(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
    store = SyncConfigStore(
      secretStore: secretStore,
      prefsFactory: () async => prefs,
    );
  }

  test('load returns default config when nothing is persisted', () async {
    final config = await store.load();

    expect(config.enabled, isFalse);
    expect(config.autoSync, isFalse);
    expect(config.syncType, SyncType.webdav);
    expect(config.serverUrl, SyncConfig.defaultServerUrl);
    expect(config.username, isEmpty);
    expect(config.password, isEmpty);
    expect(config.s3SecretKey, isEmpty);
  });

  test('load tolerates corrupted sync_config JSON', () async {
    await seedPrefs(<String, Object>{'sync_config': '{not valid json'});

    final config = await store.load();

    expect(config.enabled, isFalse);
    expect(config.syncType, SyncType.webdav);
  });

  test('load hydrates secrets from secret store', () async {
    await secretStore.writeWebDavPassword('pw-from-store');
    await secretStore.writeS3SecretKey('s3-secret-from-store');
    await seedPrefs(<String, Object>{
      'sync_config': jsonEncode(<String, Object?>{
        'enabled': true,
        'syncType': 1,
        's3EndPoint': 'oss.example.com',
        's3BucketName': 'bucket',
        's3AccessKey': 'AKID',
      }),
    });

    final config = await store.load();

    expect(config.enabled, isTrue);
    expect(config.syncType, SyncType.s3);
    expect(config.password, 'pw-from-store');
    expect(config.s3SecretKey, 's3-secret-from-store');
  });

  test(
    'save persists config JSON without secrets and writes secrets to store',
    () async {
      final config = SyncConfig(
        enabled: true,
        autoSync: true,
        syncType: SyncType.webdav,
        serverUrl: 'https://dav.example.com/',
        username: 'user',
        password: 'secret-pw',
        s3SecretKey: 'secret-s3',
      );

      await store.save(config);

      final persisted =
          jsonDecode(prefs.getString(SyncConfigStore.syncConfigKey)!)
              as Map<String, dynamic>;
      expect(persisted['enabled'], isTrue);
      expect(persisted['autoSync'], isTrue);
      expect(persisted['serverUrl'], 'https://dav.example.com/');
      expect(persisted['username'], 'user');
      expect(persisted.containsKey('password'), isFalse);
      expect(persisted.containsKey('s3SecretKey'), isFalse);

      expect(await secretStore.readWebDavPassword(), 'secret-pw');
      expect(await secretStore.readS3SecretKey(), 'secret-s3');
    },
  );

  test('save with empty secrets clears the secret store', () async {
    await secretStore.writeWebDavPassword('old-pw');
    await secretStore.writeS3SecretKey('old-s3');

    await store.save(SyncConfig(password: '', s3SecretKey: ''));

    expect(await secretStore.readWebDavPassword(), isNull);
    expect(await secretStore.readS3SecretKey(), isNull);
  });

  test('save then load round trips all public fields', () async {
    final config = SyncConfig(
      enabled: true,
      autoSync: true,
      compressImages: false,
      syncType: SyncType.s3,
      serverUrl: 'https://dav.example.com/',
      username: 'user',
      password: 'pw',
      s3EndPoint: 'oss.example.com',
      s3AccessKey: 'AKID',
      s3SecretKey: 's3sec',
      s3BucketName: 'bucket',
      s3Region: 'us-east-1',
    );

    await store.save(config);
    final loaded = await store.load();

    expect(loaded.enabled, config.enabled);
    expect(loaded.autoSync, config.autoSync);
    expect(loaded.compressImages, config.compressImages);
    expect(loaded.syncType, config.syncType);
    expect(loaded.serverUrl, config.serverUrl);
    expect(loaded.username, config.username);
    expect(loaded.password, config.password);
    expect(loaded.s3EndPoint, config.s3EndPoint);
    expect(loaded.s3AccessKey, config.s3AccessKey);
    expect(loaded.s3SecretKey, config.s3SecretKey);
    expect(loaded.s3BucketName, config.s3BucketName);
    expect(loaded.s3Region, config.s3Region);
  });

  test('load migrates legacy secrets out of sync_config JSON', () async {
    await seedPrefs(<String, Object>{
      'sync_config': jsonEncode(<String, Object?>{
        'enabled': true,
        'serverUrl': 'https://dav.example.com/',
        'username': 'demo',
        'password': 'legacy-pw',
        's3SecretKey': 'legacy-s3',
      }),
    });

    final config = await store.load();

    final persisted =
        jsonDecode(prefs.getString(SyncConfigStore.syncConfigKey)!)
            as Map<String, dynamic>;
    expect(persisted.containsKey('password'), isFalse);
    expect(persisted.containsKey('s3SecretKey'), isFalse);
    expect(await secretStore.readWebDavPassword(), 'legacy-pw');
    expect(await secretStore.readS3SecretKey(), 'legacy-s3');
    expect(config.password, 'legacy-pw');
    expect(config.s3SecretKey, 'legacy-s3');
    expect(config.enabled, isTrue);
  });

  test('hydrateSecrets backfills empty defaults when store is empty', () async {
    await seedPrefs(<String, Object>{
      'sync_config': jsonEncode(<String, Object?>{
        'serverUrl': 'https://dav.example.com/',
      }),
    });

    final config = await store.load();

    expect(config.serverUrl, 'https://dav.example.com/');
    expect(config.password, isEmpty);
    expect(config.s3SecretKey, isEmpty);
  });
}
