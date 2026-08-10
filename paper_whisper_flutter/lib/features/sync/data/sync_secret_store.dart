import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class SyncSecretStore {
  factory SyncSecretStore.secure({FlutterSecureStorage? storage}) =
      FlutterSyncSecretStore;
  factory SyncSecretStore.fake() = MemorySyncSecretStore;

  Future<void> writeWebDavPassword(String value);
  Future<void> writeS3SecretKey(String value);
  Future<String?> readWebDavPassword();
  Future<String?> readS3SecretKey();
  Future<void> clear();
}

class FlutterSyncSecretStore implements SyncSecretStore {
  FlutterSyncSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _webDavPasswordKey = 'sync_webdav_password';
  static const String _s3SecretKey = 'sync_s3_secret_key';

  final FlutterSecureStorage _storage;

  @override
  Future<void> writeWebDavPassword(String value) async {
    await _writeOrDelete(_webDavPasswordKey, value);
  }

  @override
  Future<void> writeS3SecretKey(String value) async {
    await _writeOrDelete(_s3SecretKey, value);
  }

  @override
  Future<String?> readWebDavPassword() async {
    return _storage.read(key: _webDavPasswordKey);
  }

  @override
  Future<String?> readS3SecretKey() async {
    return _storage.read(key: _s3SecretKey);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _webDavPasswordKey);
    await _storage.delete(key: _s3SecretKey);
  }

  Future<void> _writeOrDelete(String key, String value) async {
    if (value.trim().isEmpty) {
      await _storage.delete(key: key);
      return;
    }
    await _storage.write(key: key, value: value);
  }
}

class MemorySyncSecretStore implements SyncSecretStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> writeWebDavPassword(String value) async {
    _writeOrDelete('webdav', value);
  }

  @override
  Future<void> writeS3SecretKey(String value) async {
    _writeOrDelete('s3', value);
  }

  @override
  Future<String?> readWebDavPassword() async {
    return _values['webdav'];
  }

  @override
  Future<String?> readS3SecretKey() async {
    return _values['s3'];
  }

  @override
  Future<void> clear() async {
    _values.clear();
  }

  void _writeOrDelete(String key, String value) {
    if (value.trim().isEmpty) {
      _values.remove(key);
      return;
    }
    _values[key] = value;
  }
}

Future<void> migrateLegacySyncSecrets(
  SharedPreferences prefs,
  SyncSecretStore store,
) async {
  final jsonStr = prefs.getString('sync_config');
  if (jsonStr == null || jsonStr.isEmpty) {
    return;
  }

  try {
    final configJson = jsonDecode(jsonStr) as Map<String, dynamic>;
    bool changed = false;

    final legacyPassword = configJson['password']?.toString();
    if (legacyPassword != null) {
      if (legacyPassword.trim().isNotEmpty) {
        await store.writeWebDavPassword(legacyPassword);
      }
      configJson.remove('password');
      changed = true;
    }

    final legacyS3Secret = configJson['s3SecretKey']?.toString();
    if (legacyS3Secret != null) {
      if (legacyS3Secret.trim().isNotEmpty) {
        await store.writeS3SecretKey(legacyS3Secret);
      }
      configJson.remove('s3SecretKey');
      changed = true;
    }

    if (changed) {
      await prefs.setString('sync_config', jsonEncode(configJson));
    }
  } catch (e) {
    debugPrint('Sync secret migration skipped: $e');
  }
}
