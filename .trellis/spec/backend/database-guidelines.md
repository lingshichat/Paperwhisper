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

## Common Mistakes

1. **Not handling permission denied on Android** — File I/O must be wrapped in permission checks
2. **Assuming directory exists** — Always `createSync(recursive: true)` before writing
3. **Not normalizing line endings** — Use `.replaceAll('\r\n', '\n')` when reading/writing
4. **Losing data during migration** — Always copy first, verify, then mark migrated
5. **Reading all files synchronously** — Use async I/O for large directories
