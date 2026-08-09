# Database / Storage Guidelines

> PaperWhisper does NOT use a traditional SQL database. Data is stored as files on the file system.

---

## Overview

Data persistence in PaperWhisper uses **three strategies**:

| Strategy | Use case | Library |
|----------|----------|---------|
| **Plain text files** | Diary entries | `dart:io` file operations |
| **JSON files** | Moments, manifests, metadata | `dart:convert` + `dart:io` |
| **Key-value** | Settings, flags, small config | `shared_preferences` |

> Note: The `pubspec.yaml` lists `sqflite` but it is not actively used. All data flows through file-system operations.

---

## File Format: Diary Entries

Each diary entry is a `.txt` file with custom format:

```
日记标题
META|weather:sunny|mood:calm|markdown:false

正文内容从这里开始...
```

- **Line 0**: Title
- **Line 1**: META line (pipe-delimited key:value pairs)
- **Line 2**: Empty
- **Line 3+**: Content body

File naming: `{yyyy-MM-dd}_{uuid}.txt`

---

## File Format: Moments

Each moment is a JSON file stored as `{uuid}.json`:

```json
{
  "uuid": "550e8400-e29b-41d4-a716-446655440000",
  "content": "今天天气真好...",
  "images": ["img_001.jpg", "img_002.jpg"],
  "createdAt": "2025-01-15T10:30:00.000",
  "weather": "sunny",
  "mood": "happy",
  "audioPath": "audio/recording_001.m4a",
  "audioDuration": 30
}
```

---

## Storage Locations

| Platform | Primary path | Fallback / legacy path |
|----------|--------------|------------------------|
| Android | `/storage/emulated/0/Documents/PaperWhisper/` | App-private documents / external app dir when permission is unavailable |
| Windows | `{Documents}/PaperWhisper/` | Portable / legacy sibling directories such as `diary_data` or `moments_data` next to the executable |

Actual sub-directories in current code:
```
PaperWhisper/
├── diary_data/
│   ├── *.txt              # Diary entries
│   ├── diary_cache.json   # Derived startup cache
│   └── book_metadata.json # Book title/subtitle/cover per year
└── moments_data/
    ├── *.json             # Moment payloads
    ├── images/            # Moment images
    └── audio/             # Moment audio recordings
```

---

## Query Patterns

### Loading all entries:

```dart
// 列出目录中所有 .txt 文件，逐个解析
Future<List<DiaryEntry>> getEntries() async {
  final dir = Directory(_diaryPath);
  final files = dir.listSync().whereType<File>()
      .where((f) => f.path.endsWith('.txt'));
  // 解析每个文件...
}
```

### Cache for fast startup:

```dart
// 保存到 JSON 缓存文件
Future<void> saveCache(List<DiaryEntry> entries) async {
  final json = entries.map((e) => e.toJson()).toList();
  await cacheFile.writeAsString(jsonEncode(json));
}

// 加载缓存 + 超时保护
await diaryService.loadCache().timeout(
  const Duration(milliseconds: 150),
  onTimeout: () => null, // 超时则跳过缓存
);
```

---

## Migrations

### Android data migration:

When upgrading, data is migrated from private app directory to public Documents directory:

```dart
Future<void> _migrateFromPrivateToPublic(Directory publicDir) async {
  // 检查旧目录 (getApplicationDocumentsDirectory)
  // 复制所有文件到新的公共目录
  // 成功后标记已迁移
}
```

---

## Naming Conventions

| Item | Convention |
|------|-----------|
| Diary files | `{yyyy-MM-dd}_{uuid}.txt` |
| Moment files | `{uuid}.json` |
| Image files | `img_{timestamp}_{uuid}.{ext}` |
| Audio files | `recording_{timestamp}.m4a` |
| Cache files | `diary_cache.json` |

---

## Sync Cache Contract

`SyncProvider` persists sync baselines in `SharedPreferences`, but these keys must be **scoped by remote target identity**, not shared globally across all sync backends.

### Files / Entry Points

- `paper_whisper_flutter/lib/providers/sync_provider.dart`
- `paper_whisper_flutter/lib/models/sync_trust_snapshot.dart`

### Required persisted fields

`sync_trust_snapshot` payload must preserve:

- `state`
- `pendingDiaryCount`
- `pendingMomentCount`
- `pendingImageCount`
- `pendingAudioCount`
- `lastSuccessfulSyncAt`
- `lastSuccessfulSyncPlatform`
- `failureReason`
- `configurationInvalid`

### Required scope keys

For each remote target, derive a scope id from the active config:

- WebDAV: `webdav|serverUrl|username`
- S3: `s3|endPoint|bucketName|accessKey|region`

Then namespace the local sync baseline keys:

- `last_known_remote_manifest_<scopeId>`
- `last_known_moments_manifest_<scopeId>`
- `last_known_remote_moment_images_<scopeId>`
- `last_known_remote_moment_audio_<scopeId>`
- `last_sync_time_scope_<scopeId>`

### Validation / Error Matrix

| Case | Expected behavior |
|------|-------------------|
| Switch from S3 to WebDAV with no WebDAV baseline | Pending count is recalculated against WebDAV scope only |
| Switch back to previously synced S3 target | Previous S3 scoped baseline is restored; do not show false pending items |
| Global `last_sync_time` exists from old app version | Migrate once into current scoped key; keep `sync_trust_snapshot.lastSuccessfulSyncAt` for history display |
| Connection fails with auth/config error | Keep scoped baseline, set trust state to `needsAttention` |
| Connection fails with transient network error | Keep scoped baseline, set trust state to `syncFailed` |

### Good / Base / Bad Cases

- Good: User syncs to S3 successfully, switches to WebDAV, then switches back to the same S3 bucket and still sees `Synced Successfully`
- Base: User has never synced to the current target before, so switching targets shows pending local work until first success
- Bad: A shared global manifest key makes WebDAV appear up to date because S3 synced earlier, or makes S3 appear pending because WebDAV never synced

---

## Scenario: Shared Manifest Mutation And Sync Ownership

### 1. Scope / Trigger

This contract applies whenever code creates a diary/moment service, mutates `local_manifest.json` or `local_moments_manifest.json`, or adds a new sync/page/statistics/storage consumer. It prevents independent in-memory snapshots from overwriting each other.

### 2. Signatures

Production manifest mutations are asynchronous and must be awaited:

```dart
Future<void> updateItem(
  String filename, {
  required bool isDeleted,
  int? timestamp,
});

Future<void> removeItem(
  String filename, {
  int? expectedVersionTimestamp,
});

Future<void> ensureConsistency(Directory dataDir);
```

Manifest-owning services are explicit dependencies:

```dart
DiaryProvider({required DiaryService service, ...});
SyncProvider({required MomentService momentService, ...});
StorageService({required MomentService momentService});
```

### 3. Contracts

- `main.dart` creates exactly one production `DiaryService` and one `MomentService(diaryService: diaryService)`.
- Every page, provider, statistics flow, storage flow, and sync runner receives those instances through Provider or constructors.
- Manifest mutations for the same absolute file path share one process-wide FIFO queue, including across different `ManifestService` instances.
- A queued mutation reloads the latest disk snapshot before applying its item-level change.
- For the same filename, the greater `versionTimestamp` wins; an older non-deleted item cannot revive a newer deletion or overwrite a newer normal item.
- `removeItem` must carry the caller-observed version when cleaning ghosts and must not remove a newer disk version or an item whose local file exists.
- If a disk snapshot exists but cannot be read or decoded, skip the mutation and preserve the file. A missing file is a valid empty baseline.
- `SyncManifest` / `SyncItem` JSON keys and timestamp semantics remain unchanged.

### 4. Validation & Error Matrix

| Condition | Required behavior |
|---|---|
| Two instances update different items concurrently | Final disk manifest contains both items |
| Newer item is followed by an older stale write | Keep the newer timestamp and fields |
| Newer deletion is followed by an older live item | Keep the deletion; never revive it |
| Ghost removal races with a newer local save | Preserve the newer item |
| Manifest JSON is unreadable/corrupt | Log and skip the write; do not replace it with an empty snapshot |
| One queued write fails | Later writes still enter and run on the queue |
| `await updateItem/removeItem` completes | The successful disk mutation is already observable from a new service instance |

### 5. Good / Base / Bad Cases

- Good: A page save and an automatic sync mutate the same manifest concurrently; both changes remain after a fresh reload.
- Base: A single service updates one item and the awaited Future completes after disk persistence.
- Bad: A page or provider constructs another `MomentService()` and later saves its stale full manifest over the composition-root instance.

### 6. Tests Required

- Two-instance different-item union, same-item timestamp winner, and deletion non-revival.
- Conditional `removeItem(expectedVersionTimestamp:)` racing a newer update.
- Corrupt JSON preservation and queue recovery after failure.
- `ensureConsistency` racing an explicit update.
- Fresh-instance disk assertions after every awaited mutation; do not assert only an instance's memory cache.
- `MomentService.exportDailySummary` must write through the injected shared `DiaryService` and register the diary manifest item.

### 7. Wrong vs Correct

#### Wrong

```dart
class MomentsPageState extends State<MomentsPage> {
  final MomentService momentService = MomentService();
}

manifestService.updateItem(filename, isDeleted: false); // not awaited
```

#### Correct

```dart
late final MomentService momentService;

@override
void initState() {
  super.initState();
  momentService = context.read<MomentService>();
}

await manifestService.updateItem(filename, isDeleted: false);
```

---

## Real Code Examples

- [`diary_service.dart`](../../paper_whisper_flutter/lib/services/diary_service.dart) — resolves `diary_data`, parses `*.txt` files with `DiaryEntry.fromFileContent(...)`, and persists `diary_cache.json`
- [`moment_service.dart`](../../paper_whisper_flutter/lib/services/moment_service.dart) — resolves `moments_data`, keeps JSON payloads at the root, and manages sibling `images/` + `audio/` folders
- [`trash_service.dart`](../../paper_whisper_flutter/lib/services/trash_service.dart) — records soft-delete metadata as JSON and falls back from rename to copy-delete when moving files across boundaries
- [`sync_scope_cache_store.dart`](../../paper_whisper_flutter/lib/features/sync/data/sync_scope_cache_store.dart) — stores scoped manifests, media-name baselines, and per-target timestamps without putting SharedPreferences access in the provider
- [`manifest_service.dart`](../../paper_whisper_flutter/lib/services/manifest_service.dart) — serializes item-level mutations by normalized manifest path and reloads the latest disk snapshot before each write

---

## Common Mistakes

1. **Not handling permission denied on Android** — File I/O must be wrapped in permission checks
2. **Assuming directory exists** — Always `createSync(recursive: true)` before writing
3. **Not normalizing line endings** — Use `.replaceAll('\r\n', '\n')` when reading/writing
4. **Losing data during migration** — Always copy first, verify, then mark migrated
5. **Reading all files synchronously** — Use async I/O for large directories
6. **Using one shared sync baseline across WebDAV and S3** — Always scope sync caches by remote target identity
7. **Creating multiple services that write the same manifest** — Create them once in the composition root and inject them
8. **Calling manifest mutations without `await`** — The returned Future is the persistence boundary and must complete before teardown or dependent work
9. **Saving a stale full manifest snapshot** — Use item-level queued mutations based on the latest disk snapshot
