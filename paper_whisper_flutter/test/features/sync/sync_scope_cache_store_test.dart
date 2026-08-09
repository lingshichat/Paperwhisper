import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_scope_cache_store.dart';
import 'package:paper_whisper_flutter/models/sync_config.dart';
import 'package:paper_whisper_flutter/models/sync_manifest.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late SyncScopeCacheStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    store = SyncScopeCacheStore(prefsFactory: () async => prefs);
  });

  SyncConfig webdavConfig({
    String serverUrl = 'https://dav.example.com/',
    String username = 'user',
  }) {
    return SyncConfig(
      syncType: SyncType.webdav,
      serverUrl: serverUrl,
      username: username,
    );
  }

  SyncConfig s3Config({String bucket = 'mybucket'}) {
    return SyncConfig(
      syncType: SyncType.s3,
      s3EndPoint: 'oss.example.com',
      s3BucketName: bucket,
      s3AccessKey: 'AKID123',
      s3Region: 'us-east-1',
    );
  }

  group('buildSyncScopeId', () {
    test('webdav scope id is stable, padding-free and normalized', () {
      final config = webdavConfig();
      final id = store.buildSyncScopeId(config);

      expect(id, 'd2ViZGF2fGh0dHBzOi8vZGF2LmV4YW1wbGUuY29tL3x1c2Vy');
      expect(store.buildSyncScopeId(config), id);
      expect(id, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      expect(id, isNot(contains('=')));
      expect(id, isNot(contains('+')));
      expect(id, isNot(contains('/')));

      final uppercased = webdavConfig(
        serverUrl: '  HTTPS://DAV.Example.COM/  ',
        username: 'User',
      );
      expect(store.buildSyncScopeId(uppercased), id);

      expect(
        store.buildSyncScopeId(webdavConfig(username: 'other')),
        isNot(id),
      );
    });

    test('s3 scope id is stable, padding-free and distinct from webdav', () {
      final config = s3Config();
      final id = store.buildSyncScopeId(config);

      expect(
        id,
        'czN8b3NzLmV4YW1wbGUuY29tfG15YnVja2V0fGFraWQxMjN8dXMtZWFzdC0x',
      );
      expect(store.buildSyncScopeId(config), id);
      expect(id, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      expect(id, isNot(contains('=')));
      expect(id, isNot(store.buildSyncScopeId(webdavConfig())));
      expect(store.buildSyncScopeId(s3Config(bucket: 'other')), isNot(id));
    });
  });

  group('scopeStorageKey', () {
    test('appends the scope id to the base key', () {
      final config = webdavConfig();
      final key = store.scopeStorageKey(
        SyncScopeCacheStore.lastKnownRemoteManifestKey,
        config,
      );
      expect(
        key,
        'last_known_remote_manifest_${store.buildSyncScopeId(config)}',
      );
    });
  });

  group('decodeManifest', () {
    test('null and empty json fall back to empty manifest', () {
      final empty = store.decodeManifest(null);
      expect(empty.lastSyncTimestamp, 0);
      expect(empty.items, isEmpty);

      final emptyString = store.decodeManifest('');
      expect(emptyString.lastSyncTimestamp, 0);
      expect(emptyString.items, isEmpty);
    });

    test('corrupted json falls back to empty manifest', () {
      final decoded = store.decodeManifest('{not valid json');
      expect(decoded.lastSyncTimestamp, 0);
      expect(decoded.items, isEmpty);
    });

    test('valid json decodes short-key manifest fields', () {
      final manifest = SyncManifest(
        lastSyncTimestamp: 456,
        items: {
          '2024-01-01_a.txt': SyncItem(
            filename: '2024-01-01_a.txt',
            versionHash: 'v1',
            versionTimestamp: 111,
            isDeleted: true,
          ),
        },
      );

      final decoded = store.decodeManifest(jsonEncode(manifest.toJson()));

      expect(decoded.lastSyncTimestamp, 456);
      final item = decoded.items['2024-01-01_a.txt'];
      expect(item, isNotNull);
      expect(item!.filename, '2024-01-01_a.txt');
      expect(item.versionHash, 'v1');
      expect(item.versionTimestamp, 111);
      expect(item.isDeleted, isTrue);
    });
  });

  group('manifest cache', () {
    test('round trips through the scoped cache', () async {
      final config = webdavConfig();
      final manifest = SyncManifest(
        lastSyncTimestamp: 123456,
        items: {
          '2024-01-01_a.txt': SyncItem(
            filename: '2024-01-01_a.txt',
            versionHash: 'v1',
            versionTimestamp: 111,
          ),
          '2024-01-02_b.txt': SyncItem(
            filename: '2024-01-02_b.txt',
            versionHash: 'v2',
            versionTimestamp: 222,
            isDeleted: true,
          ),
        },
      );

      await store.saveCachedManifest(
        SyncScopeCacheStore.lastKnownRemoteManifestKey,
        config,
        manifest,
      );
      final loaded = await store.loadCachedManifest(
        SyncScopeCacheStore.lastKnownRemoteManifestKey,
        config,
      );

      expect(jsonEncode(loaded.toJson()), jsonEncode(manifest.toJson()));
    });

    test('scopes do not share manifest cache entries', () async {
      await store.saveCachedManifest(
        SyncScopeCacheStore.lastKnownRemoteManifestKey,
        webdavConfig(),
        SyncManifest(lastSyncTimestamp: 1, items: {}),
      );

      final other = await store.loadCachedManifest(
        SyncScopeCacheStore.lastKnownRemoteManifestKey,
        webdavConfig(username: 'other'),
      );
      expect(other.lastSyncTimestamp, 0);
      expect(other.items, isEmpty);
    });
  });

  group('nameSet cache', () {
    test('round trips and persists sorted', () async {
      final config = webdavConfig();

      await store.saveCachedNameSet(
        SyncScopeCacheStore.lastKnownMomentImagesKey,
        config,
        {'b.jpg', 'a.jpg', 'c.jpg'},
      );
      final loaded = await store.loadCachedNameSet(
        SyncScopeCacheStore.lastKnownMomentImagesKey,
        config,
      );

      expect(loaded, {'a.jpg', 'b.jpg', 'c.jpg'});
      final persisted = prefs.getStringList(
        store.scopeStorageKey(
          SyncScopeCacheStore.lastKnownMomentImagesKey,
          config,
        ),
      );
      expect(persisted, ['a.jpg', 'b.jpg', 'c.jpg']);
    });
  });

  group('last sync time', () {
    test('round trips per scope', () async {
      final config = webdavConfig();
      final time = DateTime.utc(2024, 3, 12, 9, 30);

      await store.persistCurrentScopeLastSyncTime(config, time);
      expect(await store.loadCurrentScopeLastSyncTime(config), time);

      expect(
        await store.loadCurrentScopeLastSyncTime(
          webdavConfig(username: 'other'),
        ),
        isNull,
      );
    });

    test('global last sync time round trips independently', () async {
      final time = DateTime.utc(2024, 1, 1);
      await store.writeGlobalLastSyncTime(time);
      expect(await store.readGlobalLastSyncTime(), time);
      expect(await store.loadCurrentScopeLastSyncTime(webdavConfig()), isNull);
    });
  });

  group('migrateLegacyScopeCacheIfNeeded', () {
    const legacyDiaryJson = '{"lastSync": 100, "items": {}}';
    const legacyMomentsJson = '{"lastSync": 200, "items": {}}';
    const legacyTime = '2024-01-01T10:00:00.000';

    test(
      'copies legacy global keys into scoped keys and removes legacy keys',
      () async {
        final config = webdavConfig();
        final scopedDiaryKey = store.scopeStorageKey(
          SyncScopeCacheStore.lastKnownRemoteManifestKey,
          config,
        );
        final scopedMomentsKey = store.scopeStorageKey(
          SyncScopeCacheStore.lastKnownMomentsManifestKey,
          config,
        );
        final scopedImagesKey = store.scopeStorageKey(
          SyncScopeCacheStore.lastKnownMomentImagesKey,
          config,
        );
        final scopedAudioKey = store.scopeStorageKey(
          SyncScopeCacheStore.lastKnownMomentAudioKey,
          config,
        );
        final scopedTimeKey = store.scopeStorageKey(
          SyncScopeCacheStore.currentScopeLastSyncTimeKey,
          config,
        );

        await prefs.setString(
          SyncScopeCacheStore.lastKnownRemoteManifestKey,
          legacyDiaryJson,
        );
        await prefs.setString(
          SyncScopeCacheStore.lastKnownMomentsManifestKey,
          legacyMomentsJson,
        );
        await prefs.setStringList(
          SyncScopeCacheStore.lastKnownMomentImagesKey,
          ['a.jpg', 'b.jpg'],
        );
        await prefs.setStringList(SyncScopeCacheStore.lastKnownMomentAudioKey, [
          'a.m4a',
        ]);
        await prefs.setString(
          SyncScopeCacheStore.globalLastSyncTimeKey,
          legacyTime,
        );

        await store.migrateLegacyScopeCacheIfNeeded(config);

        expect(prefs.getString(scopedDiaryKey), legacyDiaryJson);
        expect(prefs.getString(scopedMomentsKey), legacyMomentsJson);
        expect(prefs.getStringList(scopedImagesKey), ['a.jpg', 'b.jpg']);
        expect(prefs.getStringList(scopedAudioKey), ['a.m4a']);
        expect(prefs.getString(scopedTimeKey), legacyTime);

        expect(
          prefs.containsKey(SyncScopeCacheStore.lastKnownRemoteManifestKey),
          isFalse,
        );
        expect(
          prefs.containsKey(SyncScopeCacheStore.lastKnownMomentsManifestKey),
          isFalse,
        );
        expect(
          prefs.containsKey(SyncScopeCacheStore.lastKnownMomentImagesKey),
          isFalse,
        );
        expect(
          prefs.containsKey(SyncScopeCacheStore.lastKnownMomentAudioKey),
          isFalse,
        );
        expect(
          prefs.getString(SyncScopeCacheStore.globalLastSyncTimeKey),
          legacyTime,
        );
      },
    );

    test('does not overwrite an existing scoped cache', () async {
      final config = webdavConfig();
      final scopedDiaryKey = store.scopeStorageKey(
        SyncScopeCacheStore.lastKnownRemoteManifestKey,
        config,
      );

      await store.saveCachedManifest(
        SyncScopeCacheStore.lastKnownRemoteManifestKey,
        config,
        SyncManifest(lastSyncTimestamp: 999, items: {}),
      );
      await prefs.setString(
        SyncScopeCacheStore.lastKnownRemoteManifestKey,
        legacyDiaryJson,
      );

      await store.migrateLegacyScopeCacheIfNeeded(config);

      final preserved = await store.loadCachedManifest(
        SyncScopeCacheStore.lastKnownRemoteManifestKey,
        config,
      );
      expect(preserved.lastSyncTimestamp, 999);
      expect(prefs.getString(scopedDiaryKey), isNot(legacyDiaryJson));
    });

    test('is idempotent across repeated calls', () async {
      final config = webdavConfig();
      final scopedDiaryKey = store.scopeStorageKey(
        SyncScopeCacheStore.lastKnownRemoteManifestKey,
        config,
      );
      await prefs.setString(
        SyncScopeCacheStore.lastKnownRemoteManifestKey,
        legacyDiaryJson,
      );

      await store.migrateLegacyScopeCacheIfNeeded(config);
      final first = prefs.getString(scopedDiaryKey);
      await store.migrateLegacyScopeCacheIfNeeded(config);
      final second = prefs.getString(scopedDiaryKey);

      expect(first, legacyDiaryJson);
      expect(second, first);
    });

    test('only migrates into the active scope', () async {
      final config = webdavConfig();
      await prefs.setString(
        SyncScopeCacheStore.lastKnownRemoteManifestKey,
        legacyDiaryJson,
      );

      await store.migrateLegacyScopeCacheIfNeeded(config);

      expect(
        prefs.getString(
          store.scopeStorageKey(
            SyncScopeCacheStore.lastKnownRemoteManifestKey,
            webdavConfig(username: 'other'),
          ),
        ),
        isNull,
      );
    });
  });
}
