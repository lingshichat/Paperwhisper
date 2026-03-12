# Logging & Analytics Guidelines

> How logging and analytics are handled in PaperWhisper.

---

## Overview

PaperWhisper uses two systems:
1. **`debugPrint()`** — Development-time console logging
2. **`AnalyticsService`** — Production analytics (Umami-based)

There is no structured logging framework (no `logger` package).

---

## Log Levels (Console)

| Method | When to use |
|--------|-------------|
| `debugPrint()` | General development debugging (stripped in release builds) |
| `FlutterError.presentError()` | Framework-level errors (automatic crash reporting) |

> `print()` is **forbidden** in committed code — use `debugPrint()` instead.

---

## Analytics Service

### Tracking events:

```dart
AnalyticsService().trackEvent('app_launch');

AnalyticsService().trackEvent('diary_created', metadata: {
  'weather': 'sunny',
  'mood': 'happy',
  'isMarkdown': true,
});
```

### Crash reporting:

```dart
AnalyticsService().trackEvent('app_crash', metadata: {
  'error': error.toString(),
  'stack': stack.toString(),
  'fatal': true,
});
```

### Initialization:

```dart
// 在 main() 中初始化，不阻塞启动
final analytics = AnalyticsService();
analytics.init().then((_) {
  analytics.trackEvent('app_launch');
});
```

---

## What to Log / Track

### ✅ Track these events:
- App launch / crash
- Feature usage (diary created, moment saved, sync triggered)
- Error conditions (sync failure, file parse error)
- Navigation events (page views)

### ✅ Log during development:
- Service initialization results
- Sync progress/conflicts
- Data migration steps
- Performance bottlenecks

---

## What NOT to Log

### ❌ Never log or track:
- Diary content (用户隐私)
- Personal information (names, locations)
- Authentication credentials (passwords, hashes)
- File paths containing user names
- Image data or audio data

### Rule of thumb:
> If it could identify the user or reveal their private thoughts, **do not log it**.

---

## Structured Data in Analytics

Use the `metadata` parameter for structured event data:

```dart
AnalyticsService().trackEvent('sync_completed', metadata: {
  'method': 'webdav',       // 同步方式
  'files_synced': 15,       // 同步文件数
  'duration_ms': 2340,      // 耗时
  'had_conflicts': false,   // 是否有冲突
});
```

---

## Common Mistakes

1. **Using `print()` instead of `debugPrint()`** — `print()` doesn't get stripped in release builds
2. **Logging diary content for debugging** — Privacy violation, even in development
3. **Not initializing AnalyticsService before tracking** — `trackEvent` handles this gracefully, but `init()` should be called early
4. **Blocking startup with analytics `await`** — Use fire-and-forget pattern
5. **Including PII in error metadata** — Only include error type and stack trace, never user data
