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

| Platform | Base path | Method |
|----------|-----------|--------|
| Android | `/storage/emulated/0/Documents/PaperWhisper/` | Public documents (survives uninstall) |
| Windows | `{Documents}/PaperWhisper/` | Standard documents folder |

Sub-directories:
```
PaperWhisper/
├── diary/              # Diary .txt files
├── moments/
│   ├── data/           # Moment .json files
│   ├── images/         # Moment images
│   └── audio/          # Moment audio recordings
├── cache/              # JSON cache for fast startup
└── book_metadata.json  # Book title/subtitle/cover per year
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

## Common Mistakes

1. **Not handling permission denied on Android** — File I/O must be wrapped in permission checks
2. **Assuming directory exists** — Always `createSync(recursive: true)` before writing
3. **Not normalizing line endings** — Use `.replaceAll('\r\n', '\n')` when reading/writing
4. **Losing data during migration** — Always copy first, verify, then mark migrated
5. **Reading all files synchronously** — Use async I/O for large directories
6. **Using one shared sync baseline across WebDAV and S3** — Always scope sync caches by remote target identity
