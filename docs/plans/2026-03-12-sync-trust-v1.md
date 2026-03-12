# Sync Trust V1 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement Sync Trust V1 so PaperWhisper's sync flow reports the truth, preserves recoverability, and stops treating credential and pending-state handling as best-effort details.

**Architecture:** Keep `SyncProvider` as the single orchestration entry point, but move it from transient `none/syncing/success/failed` flags to a persisted trust snapshot that tracks state, pending counts, last successful sync, and failure reason. Use manifests plus local file existence as the source of truth for pending work, move secrets out of plain `SharedPreferences`, and drive both settings/status UI and save/delete flows from the same sync contract.

**Tech Stack:** Flutter, Dart, Provider, `shared_preferences`, `dart:io`, WebDAV (`webdav_client`), S3 (`minio`), `permission_handler`, `flutter_secure_storage` (or the project's approved secure storage replacement), `flutter_test`

---

## Preconditions

Read these before Task 1:

- `.trellis/spec/frontend/state-management.md`
- `.trellis/spec/frontend/component-guidelines.md`
- `.trellis/spec/backend/database-guidelines.md`
- `.trellis/spec/backend/error-handling.md`
- `.trellis/spec/backend/logging-guidelines.md`
- `.trellis/spec/guides/cross-layer-thinking-guide.md`

Current code hotspots:

- `paper_whisper_flutter/lib/providers/sync_provider.dart`
- `paper_whisper_flutter/lib/models/sync_config.dart`
- `paper_whisper_flutter/lib/models/sync_manifest.dart`
- `paper_whisper_flutter/lib/services/manifest_service.dart`
- `paper_whisper_flutter/lib/services/diary_service.dart`
- `paper_whisper_flutter/lib/services/moment_service.dart`
- `paper_whisper_flutter/lib/services/trash_service.dart`
- `paper_whisper_flutter/lib/pages/sync_settings_page.dart`
- `paper_whisper_flutter/lib/pages/settings_page.dart`
- `paper_whisper_flutter/lib/pages/editor_page.dart`
- `paper_whisper_flutter/lib/pages/moments_page.dart`
- `paper_whisper_flutter/lib/widgets/moment_card.dart`

### Task 1: Define the sync trust contract

**Files:**
- Create: `paper_whisper_flutter/lib/models/sync_trust_snapshot.dart`
- Modify: `paper_whisper_flutter/lib/providers/sync_provider.dart`
- Modify: `paper_whisper_flutter/lib/models/sync_config.dart`
- Modify: `paper_whisper_flutter/lib/models/sync_manifest.dart`
- Test: `paper_whisper_flutter/test/models/sync_trust_snapshot_test.dart`

**Step 1: Write the failing contract test**

```dart
test('pending snapshot survives json round trip', () {
  const snapshot = SyncTrustSnapshot(
    state: SyncTrustState.localChangesPending,
    pendingDiaryCount: 2,
    pendingMomentCount: 1,
    pendingImageCount: 3,
  );

  final roundTrip = SyncTrustSnapshot.fromJson(snapshot.toJson());

  expect(roundTrip.state, SyncTrustState.localChangesPending);
  expect(roundTrip.totalPendingCount, 6);
});
```

**Step 2: Run it to verify it fails**

Run: `cd paper_whisper_flutter && flutter test test/models/sync_trust_snapshot_test.dart -r compact`
Expected: FAIL because `SyncTrustSnapshot` does not exist yet.

**Step 3: Add the minimal persisted model**

Suggested shape:

```dart
enum SyncTrustState {
  notEnabled,
  localChangesPending,
  syncing,
  syncedSuccessfully,
  syncFailed,
  needsAttention,
}

class SyncTrustSnapshot {
  final SyncTrustState state;
  final int pendingDiaryCount;
  final int pendingMomentCount;
  final int pendingImageCount;
  final int pendingAudioCount;
  final DateTime? lastSuccessfulSyncAt;
  final String? failureReason;
  final bool configurationInvalid;
}
```

**Step 4: Persist the snapshot in `SyncProvider`**

Add a `sync_trust_snapshot` key, load it during `_loadConfig()`, and stop treating `last_sync_time` as the only durable signal.

**Step 5: Run test and analysis**

Run: `cd paper_whisper_flutter && flutter test test/models/sync_trust_snapshot_test.dart -r compact`
Run: `cd paper_whisper_flutter && dart analyze lib/models/sync_trust_snapshot.dart lib/providers/sync_provider.dart lib/models/sync_config.dart lib/models/sync_manifest.dart`
Expected: PASS test, `No issues found!`.

**Step 6: Commit**

```bash
git add paper_whisper_flutter/lib/models/sync_trust_snapshot.dart paper_whisper_flutter/lib/providers/sync_provider.dart paper_whisper_flutter/lib/models/sync_config.dart paper_whisper_flutter/lib/models/sync_manifest.dart paper_whisper_flutter/test/models/sync_trust_snapshot_test.dart
git commit -m "feat(sync): add persisted sync trust snapshot"
```

### Task 2: Make auto sync a real user control

**Files:**
- Modify: `paper_whisper_flutter/lib/providers/sync_provider.dart`
- Modify: `paper_whisper_flutter/lib/pages/sync_settings_page.dart`
- Modify: `paper_whisper_flutter/lib/pages/editor_page.dart`
- Modify: `paper_whisper_flutter/lib/pages/moments_page.dart`
- Modify: `paper_whisper_flutter/lib/main.dart`
- Test: `paper_whisper_flutter/test/providers/sync_provider_test.dart`

**Step 1: Write the failing provider test**

```dart
test('requestAutoSync returns early when auto sync is disabled', () async {
  final provider = TestableSyncProvider();
  await provider.saveConfig(const SyncConfig(
    enabled: true,
    autoSync: false,
    serverUrl: 'https://dav.example.com/',
    username: 'demo',
    password: 'secret',
  ));

  await provider.requestAutoSync(fromLifecycle: true);

  expect(provider.syncCallCount, 0);
});
```

**Step 2: Run it to verify it fails**

Run: `cd paper_whisper_flutter && flutter test test/providers/sync_provider_test.dart -r compact`
Expected: FAIL because current `requestAutoSync()` only checks `enabled`.

**Step 3: Gate background sync on `config.autoSync`**

Use this rule in `sync_provider.dart` and `main.dart`:

```dart
if (!config.enabled) return;
if (!config.autoSync && !force) return;
```

**Step 4: Surface the missing switch in `SyncSettingsPage`**

Render a dedicated skeuomorphic `autoSync` switch card near the compression switch and persist it through `provider.saveConfig(...)`.

**Step 5: Fix save-flow behavior and copy**

- `editor_page.dart` and `moments_page.dart` should stop forcing background sync after every save.
- When sync is configured and `autoSync` is off, show copy like `已保存，尚有 1 项待同步`.
- Do not request notification permission when auto sync is off.

**Step 6: Run test and analysis**

Run: `cd paper_whisper_flutter && flutter test test/providers/sync_provider_test.dart -r compact`
Run: `cd paper_whisper_flutter && dart analyze lib/providers/sync_provider.dart lib/pages/sync_settings_page.dart lib/pages/editor_page.dart lib/pages/moments_page.dart lib/main.dart`
Expected: PASS test, `No issues found!`.

**Step 7: Commit**

```bash
git add paper_whisper_flutter/lib/providers/sync_provider.dart paper_whisper_flutter/lib/pages/sync_settings_page.dart paper_whisper_flutter/lib/pages/editor_page.dart paper_whisper_flutter/lib/pages/moments_page.dart paper_whisper_flutter/lib/main.dart paper_whisper_flutter/test/providers/sync_provider_test.dart
git commit -m "feat(sync): honor auto sync as a real user setting"
```

### Task 3: Make success, failure, and pending counts truthful

**Files:**
- Modify: `paper_whisper_flutter/lib/providers/sync_provider.dart`
- Modify: `paper_whisper_flutter/lib/services/manifest_service.dart`
- Modify: `paper_whisper_flutter/lib/models/sync_manifest.dart`
- Modify: `paper_whisper_flutter/lib/services/diary_service.dart`
- Modify: `paper_whisper_flutter/lib/services/moment_service.dart`
- Test: `paper_whisper_flutter/test/providers/sync_provider_test.dart`
- Test: `paper_whisper_flutter/test/services/manifest_service_test.dart`

**Step 1: Write the failing partial-failure test**

```dart
test('partial upload failure leaves sync in failed state with pending items', () async {
  final provider = TestableSyncProvider.withUploadFailure('2026-03-12_a.txt');

  await provider.sync();

  expect(provider.trustSnapshot.state, SyncTrustState.syncFailed);
  expect(provider.trustSnapshot.totalPendingCount, greaterThan(0));
  expect(provider.lastSyncTime, isNull);
});
```

**Step 2: Run it to verify it fails**

Run: `cd paper_whisper_flutter && flutter test test/providers/sync_provider_test.dart test/services/manifest_service_test.dart -r compact`
Expected: FAIL because current sync still records success after partial failures.

**Step 3: Add a per-run outcome accumulator**

Suggested shape:

```dart
class SyncRunOutcome {
  int failedUploads = 0;
  int failedDownloads = 0;
  int failedDeletes = 0;
  final List<String> errors = <String>[];

  bool get hasFailures =>
      failedUploads > 0 || failedDownloads > 0 || failedDeletes > 0;
}
```

Only set `lastSuccessfulSyncAt` and `syncedSuccessfully` when `hasFailures == false` and `totalPendingCount == 0`.

**Step 4: Recalculate pending counts from manifests plus disk reality**

Track pending work for:

- diary files awaiting upload or archive move
- moment JSON files awaiting upload or archive move
- images and audio missing remote confirmation
- tombstones that have not finished both local and remote archive handling

Do not write merged manifest entries for transient failures.

**Step 5: Keep failure messaging user-safe**

Map provider failures into short Chinese reasons such as:

- `配置异常，请检查账号或服务器地址`
- `同步失败，内容仍保留在本地`
- `网络异常，请稍后重试`

Do not surface raw storage exceptions in UI.

**Step 6: Run tests and analysis**

Run: `cd paper_whisper_flutter && flutter test test/providers/sync_provider_test.dart test/services/manifest_service_test.dart -r compact`
Run: `cd paper_whisper_flutter && dart analyze lib/providers/sync_provider.dart lib/services/manifest_service.dart lib/models/sync_manifest.dart lib/services/diary_service.dart lib/services/moment_service.dart`
Expected: PASS tests, `No issues found!`.

**Step 7: Commit**

```bash
git add paper_whisper_flutter/lib/providers/sync_provider.dart paper_whisper_flutter/lib/services/manifest_service.dart paper_whisper_flutter/lib/models/sync_manifest.dart paper_whisper_flutter/lib/services/diary_service.dart paper_whisper_flutter/lib/services/moment_service.dart paper_whisper_flutter/test/providers/sync_provider_test.dart paper_whisper_flutter/test/services/manifest_service_test.dart
git commit -m "fix(sync): make pending and success states truthful"
```

### Task 4: Build a persistent sync status surface

**Files:**
- Modify: `paper_whisper_flutter/lib/pages/sync_settings_page.dart`
- Modify: `paper_whisper_flutter/lib/pages/settings_page.dart`
- Modify: `paper_whisper_flutter/lib/config/theme/components/sync_settings_theme_data.dart`
- Modify: `paper_whisper_flutter/lib/config/theme/components/settings_theme_data.dart`
- Test: `paper_whisper_flutter/test/widgets/sync_settings_page_test.dart`

**Step 1: Write the failing widget test**

```dart
testWidgets('sync settings shows pending count and retry action', (tester) async {
  await tester.pumpWidget(buildSyncSettingsApp(
    snapshot: const SyncTrustSnapshot(
      state: SyncTrustState.syncFailed,
      pendingDiaryCount: 2,
      failureReason: '同步失败，内容仍保留在本地',
    ),
  ));

  expect(find.text('尚有 2 项待同步'), findsOneWidget);
  expect(find.text('立即重试'), findsOneWidget);
  expect(find.text('同步失败，内容仍保留在本地'), findsOneWidget);
});
```

**Step 2: Run it to verify it fails**

Run: `cd paper_whisper_flutter && flutter test test/widgets/sync_settings_page_test.dart -r compact`
Expected: FAIL because current UI only shows transient progress and toast feedback.

**Step 3: Add a dedicated status card to `SyncSettingsPage`**

Render a persistent block above the action buttons that always answers:

- current trust state
- pending count
- last successful sync time
- failure or configuration warning
- retry now / open settings action

Keep styling theme-driven and skeuomorphic.

**Step 4: Upgrade the settings summary subtitle**

Replace `_getSyncStatusText()` in `settings_page.dart` with snapshot-driven copy:

```dart
if (!snapshot.isEnabled) return '未启用';
if (snapshot.state == SyncTrustState.localChangesPending) {
  return '尚有 ${snapshot.totalPendingCount} 项待同步';
}
if (snapshot.state == SyncTrustState.syncFailed) {
  return '同步失败，内容仍保留在本地';
}
if (snapshot.lastSuccessfulSyncAt != null) {
  return '最近一次成功同步：${formatTime(snapshot.lastSuccessfulSyncAt!)}';
}
```

**Step 5: Fix setup validation while you are in the page**

- Do not validate every field with `不能为空`.
- Keep S3 `region` optional.
- Distinguish setup errors from runtime sync failures.

**Step 6: Run widget test and analysis**

Run: `cd paper_whisper_flutter && flutter test test/widgets/sync_settings_page_test.dart -r compact`
Run: `cd paper_whisper_flutter && dart analyze lib/pages/sync_settings_page.dart lib/pages/settings_page.dart lib/config/theme/components/sync_settings_theme_data.dart lib/config/theme/components/settings_theme_data.dart`
Expected: PASS widget test, `No issues found!`.

**Step 7: Commit**

```bash
git add paper_whisper_flutter/lib/pages/sync_settings_page.dart paper_whisper_flutter/lib/pages/settings_page.dart paper_whisper_flutter/lib/config/theme/components/sync_settings_theme_data.dart paper_whisper_flutter/lib/config/theme/components/settings_theme_data.dart paper_whisper_flutter/test/widgets/sync_settings_page_test.dart
git commit -m "feat(sync): add persistent sync trust status UI"
```

### Task 5: Align delete semantics with recoverable archive behavior

**Files:**
- Create: `paper_whisper_flutter/lib/models/trash_record.dart`
- Modify: `paper_whisper_flutter/lib/services/trash_service.dart`
- Modify: `paper_whisper_flutter/lib/services/diary_service.dart`
- Modify: `paper_whisper_flutter/lib/services/moment_service.dart`
- Modify: `paper_whisper_flutter/lib/pages/trash_page.dart`
- Modify: `paper_whisper_flutter/lib/pages/editor_page.dart`
- Modify: `paper_whisper_flutter/lib/pages/moments_page.dart`
- Modify: `paper_whisper_flutter/lib/widgets/moment_card.dart`
- Test: `paper_whisper_flutter/test/services/trash_service_test.dart`
- Test: `paper_whisper_flutter/test/services/moment_service_test.dart`

**Step 1: Write the failing archive test**

```dart
test('deleteMoment archives json and media instead of hard deleting', () async {
  final service = await buildMomentServiceWithTempFiles();

  await service.deleteMoment(moment.uuid);

  expect(await service.trashService.hasRecord('moment_${moment.uuid}.json'), isTrue);
  expect(await File(originalJsonPath).exists(), isFalse);
});
```

**Step 2: Run it to verify it fails**

Run: `cd paper_whisper_flutter && flutter test test/services/trash_service_test.dart test/services/moment_service_test.dart -r compact`
Expected: FAIL because moments are hard-deleted today and `TrashService` only understands diary files.

**Step 3: Add typed trash records**

Create `trash_record.dart` and store small JSON metadata in `trash_data/records/`:

```dart
enum TrashRecordType { diary, moment }

class TrashRecord {
  final TrashRecordType type;
  final String primaryFilename;
  final List<String> relatedFiles;
  final DateTime deletedAt;
}
```

Use it so a deleted moment can restore its JSON, copied images, and copied audio.

**Step 4: Switch moment delete to archive-first**

Update `moment_service.dart` so `deleteMoment()` moves the JSON, images, and audio into trash storage, then marks the manifest tombstone. Do not hard-delete user media during normal delete.

**Step 5: Update recovery UI and copy**

- Remove irreversible wording from `editor_page.dart`, `moments_page.dart`, and `moment_card.dart` when the action is recoverable.
- Extend `trash_page.dart` to show both diary and moment records and expose restore/permanent delete per record type.

**Step 6: Run tests and analysis**

Run: `cd paper_whisper_flutter && flutter test test/services/trash_service_test.dart test/services/moment_service_test.dart -r compact`
Run: `cd paper_whisper_flutter && dart analyze lib/models/trash_record.dart lib/services/trash_service.dart lib/services/diary_service.dart lib/services/moment_service.dart lib/pages/trash_page.dart lib/pages/editor_page.dart lib/pages/moments_page.dart lib/widgets/moment_card.dart`
Expected: PASS tests, `No issues found!`.

**Step 7: Commit**

```bash
git add paper_whisper_flutter/lib/models/trash_record.dart paper_whisper_flutter/lib/services/trash_service.dart paper_whisper_flutter/lib/services/diary_service.dart paper_whisper_flutter/lib/services/moment_service.dart paper_whisper_flutter/lib/pages/trash_page.dart paper_whisper_flutter/lib/pages/editor_page.dart paper_whisper_flutter/lib/pages/moments_page.dart paper_whisper_flutter/lib/widgets/moment_card.dart paper_whisper_flutter/test/services/trash_service_test.dart paper_whisper_flutter/test/services/moment_service_test.dart
git commit -m "feat(sync): make delete flows recoverable by default"
```

### Task 6: Move sync secrets out of plain SharedPreferences

**Files:**
- Modify: `paper_whisper_flutter/pubspec.yaml`
- Create: `paper_whisper_flutter/lib/services/sync_secret_store.dart`
- Modify: `paper_whisper_flutter/lib/models/sync_config.dart`
- Modify: `paper_whisper_flutter/lib/providers/sync_provider.dart`
- Modify: `paper_whisper_flutter/lib/pages/sync_settings_page.dart`
- Test: `paper_whisper_flutter/test/services/sync_secret_store_test.dart`

**Step 1: Write the failing migration test**

```dart
test('legacy sync config migrates secrets out of shared preferences', () async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('sync_config', jsonEncode({
    'enabled': true,
    'serverUrl': 'https://dav.example.com/',
    'username': 'demo',
    'password': 'legacy-secret',
  }));

  final store = SyncSecretStore.fake();
  await migrateLegacySyncSecrets(prefs, store);

  expect((jsonDecode(prefs.getString('sync_config')!) as Map)['password'], isNull);
  expect(await store.readWebDavPassword(), 'legacy-secret');
});
```

**Step 2: Run it to verify it fails**

Run: `cd paper_whisper_flutter && flutter test test/services/sync_secret_store_test.dart -r compact`
Expected: FAIL because there is no secure secret store yet.

**Step 3: Add the secure secret store**

```dart
abstract class SyncSecretStore {
  Future<void> writeWebDavPassword(String value);
  Future<void> writeS3SecretKey(String value);
  Future<String?> readWebDavPassword();
  Future<String?> readS3SecretKey();
  Future<void> clear();
}
```

Back it with `flutter_secure_storage` or the project-approved equivalent and add the dependency in `pubspec.yaml`.

**Step 4: Strip secrets out of `SyncConfig` persistence**

After this change, `sync_config` should keep non-secret metadata only. `password` and `s3SecretKey` must stop round-tripping through `SyncConfig.toJson()`.

**Step 5: Add one-time migration and form hydration**

- Migrate legacy secrets from `sync_config` into the secure store on app load.
- Delete the legacy secret fields from `SharedPreferences`.
- Hydrate `SyncSettingsPage` controllers from the secure store before editing.

**Step 6: Run test and analysis**

Run: `cd paper_whisper_flutter && flutter test test/services/sync_secret_store_test.dart -r compact`
Run: `cd paper_whisper_flutter && dart analyze lib/services/sync_secret_store.dart lib/models/sync_config.dart lib/providers/sync_provider.dart lib/pages/sync_settings_page.dart`
Expected: PASS test, `No issues found!`.

**Step 7: Commit**

```bash
git add paper_whisper_flutter/pubspec.yaml paper_whisper_flutter/lib/services/sync_secret_store.dart paper_whisper_flutter/lib/models/sync_config.dart paper_whisper_flutter/lib/providers/sync_provider.dart paper_whisper_flutter/lib/pages/sync_settings_page.dart paper_whisper_flutter/test/services/sync_secret_store_test.dart
git commit -m "feat(sync): move sync secrets into secure storage"
```

### Task 7: Run the trust regression checklist before release

**Files:**
- Verify: `paper_whisper_flutter/lib/providers/sync_provider.dart`
- Verify: `paper_whisper_flutter/lib/pages/sync_settings_page.dart`
- Verify: `paper_whisper_flutter/lib/pages/settings_page.dart`
- Verify: `paper_whisper_flutter/lib/services/diary_service.dart`
- Verify: `paper_whisper_flutter/lib/services/moment_service.dart`
- Verify: `paper_whisper_flutter/lib/services/trash_service.dart`
- Verify: `paper_whisper_flutter/lib/services/webdav_sync_service.dart`
- Verify: `paper_whisper_flutter/lib/services/s3_sync_service.dart`
- Verify: `paper_whisper_flutter/test/`
- Verify: `docs/plans/2026-03-12-sync-trust-v1-prd.md`

**Step 1: Run focused automated coverage**

Run: `cd paper_whisper_flutter && flutter test test/models/sync_trust_snapshot_test.dart test/providers/sync_provider_test.dart test/services/manifest_service_test.dart test/services/trash_service_test.dart test/services/moment_service_test.dart test/services/sync_secret_store_test.dart test/widgets/sync_settings_page_test.dart -r compact`
Expected: all PASS.

**Step 2: Run final analysis**

Run: `cd paper_whisper_flutter && dart analyze lib test`
Expected: `No issues found!`

**Step 3: Manual Android checklist**

- save diary with auto sync off, app shows pending state instead of silently syncing
- save diary with auto sync on, status moves through `Syncing` and ends in truthful state
- disconnect network during upload, app shows failure and keeps pending count
- delete diary, confirm it appears in trash and restores correctly
- delete moment with images/audio, confirm it restores correctly
- deny notification permission, confirm manual retry copy stays safe and non-destructive

**Step 4: Manual Windows checklist**

- startup and resume do not trigger auto sync when the switch is off
- settings page subtitle shows pending count / last success / failure reason correctly
- WebDAV and S3 setup validation only blocks truly required fields
- secure-storage migration preserves existing credentials on upgrade

**Step 5: Update PRD acceptance checklist and commit**

Mark the acceptance items in `docs/plans/2026-03-12-sync-trust-v1-prd.md` as verified only after both manual checklists pass.

Suggested commit:

```bash
git add docs/plans/2026-03-12-sync-trust-v1-prd.md paper_whisper_flutter/lib paper_whisper_flutter/test
git commit -m "chore(sync): complete sync trust v1 validation"
```
