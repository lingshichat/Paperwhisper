import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncSecretStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test(
      'legacy sync config migrates secrets out of shared preferences',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'sync_config': jsonEncode(<String, Object?>{
            'enabled': true,
            'serverUrl': 'https://dav.example.com/',
            'username': 'demo',
            'password': 'legacy-secret',
            's3SecretKey': 'legacy-s3-secret',
          }),
        });

        final prefs = await SharedPreferences.getInstance();
        final store = SyncSecretStore.fake();

        await migrateLegacySyncSecrets(prefs, store);

        final persistedConfig =
            jsonDecode(prefs.getString('sync_config')!) as Map<String, dynamic>;

        expect(persistedConfig.containsKey('password'), isFalse);
        expect(persistedConfig.containsKey('s3SecretKey'), isFalse);
        expect(await store.readWebDavPassword(), 'legacy-secret');
        expect(await store.readS3SecretKey(), 'legacy-s3-secret');
      },
    );
  });
}
