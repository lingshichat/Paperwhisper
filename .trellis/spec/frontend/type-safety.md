# Type Safety

> PaperWhisper 的 Dart 强类型约定。项目启用 null safety，不使用 freezed、json_serializable、build_runner 或其他代码生成。

---

## Type Ownership

业务模型跟随所属 feature：

| Model | Location | Persistence |
|---|---|---|
| `DiaryEntry` | `features/diary/data/` | 自定义 META 文本格式 |
| `Moment` | `features/moments/data/` | 每条记录一个 JSON 文件 |
| `SyncConfig` / `SyncManifest` / `SyncTrustSnapshot` | `features/sync/data/` | SharedPreferences / JSON manifest |
| `UpdateInfo` | `features/update/data/` | 远端 JSON |
| `TrashRecord` | `core/storage/` | 跨 Diary/Moments 的回收站记录 |

不要恢复全局 `models/`。单域模型留在 feature；只有确实跨域且不依赖业务上层的模型才进入 core。

---

## Typed Theme Contract

`ThemeRegistry` 是主题数据的唯一来源：

```dart
final themeId = AppTheme.themeIdOf(context);
final cardTheme = ThemeRegistry.get(themeId).diaryCard;

final Color titleColor = cardTheme.titleColor;
final List<BoxShadow> shadows = cardTheme.shadows;
```

必须遵守：

- UI 直接读取 `PaperWhisperTheme` 的 typed component 字段。
- 不新增 `Map<String, dynamic>` 主题 facade。
- 不恢复组件 `toMap()`，也不在 UI 里 `as Color` / `as Gradient` / `as Border`。
- nullable、Gradient、Border、Shadow 必须由字段类型表达，不能用哨兵值代替。
- `FabThemeData.backgroundColor` 和 `backgroundGradient` 恰一非空。
- `AppTheme.getThemeData(id)` 发布强类型 ThemeExtension；shared widget 通过 `AppTheme.themeIdOf(context)` 取主题 ID，不依赖 Settings feature。
- 测试 shared widget 时使用 `AppTheme.getThemeData()`，不要为裸 ThemeData 增加 fallback。

主题静态检查：

```bash
rg "AppTheme\.get[A-Za-z]+Theme\(" lib
rg "\btoMap\s*\(" lib/core/theme
rg "\bdynamic\b" lib/core/theme
rg "\bas\s+(Color|Gradient|Border|BoxShadow)" lib/core/theme lib/features lib/shared
```

---

## Models

### Immutable fields

```dart
class Moment {
  final String uuid;
  final String content;
  final DateTime createdAt;
  final String? audioPath;

  const Moment({
    required this.uuid,
    required this.content,
    required this.createdAt,
    this.audioPath,
  });
}
```

可选值用 nullable 表达；受限集合优先 enum 或 sealed outcome，不用松散字符串承载运行时状态。

### Explicit immutable collections

```dart
final List<DiaryEntry> entries = List<DiaryEntry>.unmodifiable(source);
final Map<String, SyncManifestItem> items =
    Map<String, SyncManifestItem>.unmodifiable(source);
```

显式写出泛型，避免 `List.unmodifiable` / `Map.unmodifiable` 被推断成 `dynamic`。

### Typed outcomes

页面协调器和状态机用 sealed class / enum 返回结果：

```dart
sealed class SaveSyncDecision {}
final class SaveSyncAutoSync extends SaveSyncDecision {}
final class SaveSyncPending extends SaveSyncDecision {
  SaveSyncPending(this.pendingCount);
  final int pendingCount;
}
```

application 不抛 UI 语义异常让页面猜测；页面对 typed outcome 做穷尽翻译。

---

## Serialization

持久化格式属于兼容契约，重构目录或类型时不得顺手修改：

- Diary 继续使用既有 META 文本格式。
- Moment、Manifest 和 Trust Snapshot 保持当前 JSON 字段名。
- DateTime 使用 ISO 8601 或已有毫秒时间戳规则。
- `startup_page` 只允许 `moments`、`writer`、`last`。
- 云端相对路径统一使用 `/`，不能把 Windows `\\` 写入跨平台数据。

JSON 边界可以进行必要的类型检查和兼容 fallback；typed 主题与内部应用状态不使用运行时 Map fallback。

```dart
final name = json['name'] as String? ?? '默认值';
final timestamp = json['timestamp'] as int?;
```

---

## Null Safety

- 只有已经由控制流、构造断言或框架契约证明非空时才使用 `!`。
- 对外部 JSON、文件、插件返回值先判空，再进入业务层。
- `BuildContext.mounted` 和 StatefulWidget `mounted` 在异步 UI 回调后必须检查。
- nullable theme field 不得在迁移时擅自改成默认色；逐主题补齐 typed 数据或保留 nullable 分支。

---

## Forbidden Patterns

### Known concrete type written as dynamic

```dart
// Wrong
final dynamic result = await service.load();

// Correct
final List<DiaryEntry> result = await service.load();
```

### Runtime theme casts

```dart
// Wrong
final color = themeMap['titleColor'] as Color;

// Correct
final color = ThemeRegistry.get(themeId).diaryCard.titleColor;
```

### Untyped UI results

```dart
// Wrong
return {'ok': false, 'message': error.toString()};

// Correct
return SaveFailure(error);
```

### Raw generic collections

```dart
// Wrong
return List.unmodifiable(items);

// Correct
return List<SyncManifestItem>.unmodifiable(items);
```

---

## Real Examples

- [`diary_entry.dart`](../../../paper_whisper_flutter/lib/features/diary/data/diary_entry.dart)：自定义文本解析与 typed enum。
- [`sync_trust_snapshot.dart`](../../../paper_whisper_flutter/lib/features/sync/data/sync_trust_snapshot.dart)：enum 状态、copyWith 和持久化兼容。
- [`paper_whisper_theme.dart`](../../../paper_whisper_flutter/lib/core/theme/paper_whisper_theme.dart)：七主题的 typed 聚合对象。
- [`fab_theme_data.dart`](../../../paper_whisper_flutter/lib/core/theme/components/fab_theme_data.dart)：互斥 nullable 字段建模。
- [`sync_run_result.dart`](../../../paper_whisper_flutter/lib/features/sync/application/sync_run_result.dart)：context-free typed result。
