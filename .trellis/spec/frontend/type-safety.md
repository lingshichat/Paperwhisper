# Type Safety

> Dart type patterns and model conventions in PaperWhisper.

---

## Overview

PaperWhisper uses Dart's strong type system with null safety enabled (`sdk: ^3.10.0`, Flutter 3.44.x stable). There is no code generation (no `freezed`, `json_serializable`, or `build_runner`). Types are manually defined in `models/`.

---

## Type Organization

### Models live in `lib/models/`:

| Model | Serialization | Storage |
|-------|--------------|---------|
| `DiaryEntry` | Custom text format (META line) | Plain text file |
| `Moment` | JSON (`toJson()` / `fromJson()`) | JSON file per moment |
| `SyncConfig` | JSON | `SharedPreferences` |
| `SyncManifest` | JSON | File system manifest |
| `UpdateInfo` | JSON | Remote API |

### Theme data is in a transition state:

Typed source-of-truth lives under `config/theme/components/`, but most UI code still consumes `Map<String, dynamic>` returned by `AppTheme`:
```dart
static Map<String, dynamic> getDiaryCardTheme(String theme) =>
    ThemeRegistry.get(theme).diaryCard.toMap();
```

Rules for new theme fields:
- Add the strongly-typed property to the relevant `*ThemeData` class first
- Expose it through `.toMap()` only as a compatibility layer for existing widgets
- Prefer migrating new widgets toward typed theme objects when practical

---

## Model Conventions

### Constructor pattern:

```dart
class Moment {
  final String uuid;        // 不可变标识
  final String content;     // 不可变内容
  final DateTime createdAt; // 不可变时间戳
  final String? weather;    // 可选字段用 nullable

  Moment({
    required this.uuid,
    required this.content,
    required this.createdAt,
    this.weather,
  });
}
```

### Factory constructors:

```dart
// 创建新实例 (自动生成 UUID/timestamp)
factory Moment.create({required String content, ...}) { ... }

// 从 JSON 反序列化
factory Moment.fromJson(Map<String, dynamic> json) { ... }

// 从文件内容反序列化
factory DiaryEntry.fromFileContent(String filename, String rawContent) { ... }
```

### Serialization:

```dart
// 到 JSON (用于 API/存储)
Map<String, dynamic> toJson() { ... }

// 到文件内容 (DiaryEntry 特有的自定义格式)
String toFileContent() { ... }
```

---

## Validation

### No runtime validation library is used.

Validation is done manually in factory constructors:

```dart
factory DiaryEntry.fromFileContent(String filename, String rawContent, ...) {
  // 手动解析和默认值
  if (title.isEmpty) title = '无题';
  
  // 安全类型转换
  try {
    DateFormat('yyyy-MM-dd').parse(dateStr);
  } catch (_) {
    dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }
}
```

### Enum parsing with fallback:

```dart
static WeatherType _parseWeather(String s) {
  return WeatherType.values.firstWhere(
    (e) => e.name == s,
    orElse: () => WeatherType.sunny, // 安全默认值
  );
}
```

---

## Common Patterns

### Enums for constrained values:

```dart
enum WeatherType { sunny, cloudy, rainy, snowy, windy }
enum MoodType { happy, calm, sad, excited, tired }
```

### Nullable fields for optional data:

```dart
final String? audioPath;    // 录音文件相对路径 (可能没有)
final int? audioDuration;   // 录音时长 (可能没有)
```

### DateTime as ISO 8601 strings in JSON:

```dart
'createdAt': createdAt.toIso8601String(),
// Deserialize:
createdAt: DateTime.parse(json['createdAt'] as String),
```

---

## Real Code Examples

- [`moment.dart`](../../paper_whisper_flutter/lib/models/moment.dart) — immutable fields, `Moment.create(...)`, typed JSON casts, and ISO-8601 serialization
- [`diary_entry.dart`](../../paper_whisper_flutter/lib/models/diary_entry.dart) — custom text parser with fallback defaults for title/date/weather/mood and a separate `fromJson(...)` cache path
- [`sync_trust_snapshot.dart`](../../paper_whisper_flutter/lib/models/sync_trust_snapshot.dart) — enum-backed UI contract with `copyWith`, derived getters, and safe fallback parsing for persisted state names
- [`moment_input_theme_data.dart`](../../paper_whisper_flutter/lib/config/theme/components/moment_input_theme_data.dart) — typed theme DTO that bridges into the legacy `Map<String, dynamic>` access pattern

---

## Forbidden Patterns

### ❌ 1. Using `dynamic` when concrete type is known

```dart
// 禁止
dynamic result = await service.getData();

// 正确
List<DiaryEntry> result = await service.getData();
```

### ❌ 2. Unnecessary type casts without null check

```dart
// 禁止
final name = json['name'] as String; // 如果 null 会崩溃

// 正确
final name = json['name'] as String? ?? '默认值';
```

### ❌ 3. Using `var` for non-obvious types

```dart
// 避免: 类型不明显
var x = service.getConfig();

// 正确: 类型清晰
SyncConfig config = service.getConfig();
// 或者类型很明显时
final entries = <DiaryEntry>[];
```

### ❌ 4. Ignoring null safety

```dart
// 禁止: 强制解包
final value = nullableVar!;

// 正确: 安全处理
final value = nullableVar ?? defaultValue;
```
