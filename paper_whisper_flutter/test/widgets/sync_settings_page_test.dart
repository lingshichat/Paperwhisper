import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:paper_whisper_flutter/config/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/models/sync_config.dart';
import 'package:paper_whisper_flutter/models/sync_trust_snapshot.dart';
import 'package:paper_whisper_flutter/pages/sync_settings_page.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/providers/sync_provider.dart';
import 'package:paper_whisper_flutter/services/manifest_service.dart';
import 'package:paper_whisper_flutter/services/moment_service.dart';
import 'package:paper_whisper_flutter/services/payment_service.dart';
import 'package:paper_whisper_flutter/services/sync_secret_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncSettingsPage', () {
    late List<Directory> tempDirs;

    setUpAll(() {
      ThemeRegistry.init();
    });

    setUp(() {
      tempDirs = <Directory>[];
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    tearDown(() async {
      for (final dir in tempDirs) {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    });

    testWidgets('sync settings shows pending count and retry action', (
      tester,
    ) async {
      final snapshot = SyncTrustSnapshot(
        state: SyncTrustState.syncFailed,
        pendingDiaryCount: 2,
        failureReason: '同步失败，内容仍保留在本地',
        lastSuccessfulSyncAt: DateTime(2026, 3, 12, 9, 30),
        lastSuccessfulSyncPlatform: 's3',
      );
      final provider = TestSyncProvider(
        snapshot: snapshot,
        tempDirs: tempDirs,
      );

      await tester.pumpWidget(buildSyncSettingsApp(provider: provider));
      await tester.pump();
      await tester.pump();

      expect(find.text('尚有 2 项待同步'), findsOneWidget);
      expect(find.text('立即同步'), findsOneWidget);
      expect(find.text('同步失败，内容仍保留在本地'), findsOneWidget);
      expect(find.text('最近一次成功同步：2026-3-12 9:30（S3）'), findsOneWidget);
    });

    testWidgets('sync settings uses field-specific validation messages', (
      tester,
    ) async {
      final provider = TestSyncProvider(
        snapshot: const SyncTrustSnapshot(
          state: SyncTrustState.notEnabled,
        ),
        tempDirs: tempDirs,
      );

      await tester.pumpWidget(buildSyncSettingsApp(provider: provider));
      await tester.pump();
      await tester.pump();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), '');
      await tester.enterText(fields.at(2), '');
      await tester.ensureVisible(find.text('测试连接'));
      await tester.tap(find.text('测试连接'));
      await tester.pump();

      expect(find.text('请输入账号'), findsOneWidget);
      expect(find.text('请输入密码或应用授权码'), findsOneWidget);
      expect(find.text('不能为空'), findsNothing);
      expect(provider.connectCallCount, 0);
    });

    testWidgets('testing connection saves config without triggering sync', (
      tester,
    ) async {
      final provider = TestSyncProvider(
        snapshot: const SyncTrustSnapshot(
          state: SyncTrustState.notEnabled,
        ),
        tempDirs: tempDirs,
      );

      await tester.pumpWidget(buildSyncSettingsApp(provider: provider));
      await tester.pump();
      await tester.pump();

      await tester.ensureVisible(find.text('测试连接'));
      await tester.tap(find.text('测试连接'));
      await tester.pump();
      await tester.pump();

      expect(provider.connectCallCount, 1);
      expect(provider.syncCallCount, 0);
    });
  });
}

Widget buildSyncSettingsApp({required SyncProvider provider}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(),
      ),
      ChangeNotifierProvider<SyncProvider>.value(value: provider),
      ChangeNotifierProvider<PaymentService>.value(value: PaymentService()),
    ],
    child: const MaterialApp(home: SyncSettingsPage()),
  );
}

class TestSyncProvider extends SyncProvider {
  TestSyncProvider({
    required SyncTrustSnapshot snapshot,
    required List<Directory> tempDirs,
    SyncConfig? config,
  }) : _snapshot = snapshot,
       _config = config ??
           SyncConfig(
         enabled: true,
         autoSync: true,
         serverUrl: 'https://dav.example.com/',
         username: 'demo',
         password: 'secret',
       ),
       super(
         momentService: _createMomentService(tempDirs),
         secretStore: SyncSecretStore.fake(),
         initializeNotifications: false,
       );

  final SyncTrustSnapshot _snapshot;
  SyncConfig _config;
  int connectCallCount = 0;
  int syncCallCount = 0;

  static MomentService _createMomentService(List<Directory> tempDirs) {
    final rootDir = Directory.systemTemp.createTempSync(
      'sync_settings_page_test',
    );
    tempDirs.add(rootDir);
    return FakeMomentService(rootDir);
  }

  @override
  SyncConfig get config => _config;

  @override
  SyncTrustSnapshot get trustSnapshot => _snapshot;

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<void> waitUntilReady() async {}

  @override
  Future<void> saveConfig(SyncConfig newConfig) async {
    _config = newConfig;
    notifyListeners();
  }

  @override
  Future<bool> connect({
    bool test = true,
    bool awaitInitialization = true,
  }) async {
    connectCallCount++;
    return true;
  }

  @override
  Future<void> sync({bool isAuto = false, BuildContext? context}) async {
    syncCallCount++;
  }
}

class FakeMomentService extends MomentService {
  FakeMomentService(this.rootDir);

  final Directory rootDir;
  final ManifestService _manifestService = ManifestService();
  Directory? _dataDir;
  Directory? _imagesDir;
  Directory? _audioDir;
  bool _initialized = false;

  @override
  Directory? get dataDir => _dataDir;

  @override
  Directory? get imagesDir => _imagesDir;

  @override
  Directory? get audioDir => _audioDir;

  @override
  ManifestService get manifestService => _manifestService;

  @override
  void reset() {
    _initialized = false;
    _dataDir = null;
    _imagesDir = null;
    _audioDir = null;
  }

  @override
  Future<void> init() async {
    if (_initialized) {
      return;
    }

    _dataDir = Directory(path.join(rootDir.path, 'moments_data'));
    _imagesDir = Directory(path.join(_dataDir!.path, 'images'));
    _audioDir = Directory(path.join(_dataDir!.path, 'audio'));

    await _dataDir!.create(recursive: true);
    await _imagesDir!.create(recursive: true);
    await _audioDir!.create(recursive: true);
    await _manifestService.init(
      _dataDir!,
      manifestFileName: 'local_moments_manifest.json',
    );
    _initialized = true;
  }

  @override
  Future<Set<String>> getAllReferencedImages() async => <String>{};
}
