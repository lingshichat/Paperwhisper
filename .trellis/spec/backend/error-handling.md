# Error Handling

> How errors are handled in PaperWhisper services.

---

## Overview

PaperWhisper uses a **defensive error handling** strategy. Since this is a personal diary app, data safety is the highest priority. Errors should be caught, logged, and gracefully degraded — never crash the app and risk data loss.

---

## Error Types

### No custom error classes are defined.

The project uses standard Dart exceptions:
- `FormatException` — Parsing errors (corrupted diary files)
- `IOException` / `FileSystemException` — File I/O failures
- `TimeoutException` — Network/sync timeouts
- `SocketException` — Network connectivity issues

---

## Error Handling Patterns

### Pattern 1: Try-catch with graceful default

```dart
factory DiaryEntry.fromFileContent(String filename, String rawContent, ...) {
  try {
    // 解析 META 行
    String metaLine = lines[1].trim();
    List<String> parts = metaLine.split('|');
    // ...解析逻辑...
  } catch (e) {
    // 解析失败则使用默认值，不丢失数据
  }
}
```

### Pattern 2: Timeout with fallback

```dart
// 缓存加载超时不阻塞启动
await diaryService.loadCache().timeout(
  const Duration(milliseconds: 150),
  onTimeout: () => null, // 超时返回 null，后续会重新加载
);
```

### Pattern 3: Crash reporting for fatal errors

```dart
FlutterError.onError = (FlutterErrorDetails details) {
  FlutterError.presentError(details); // 控制台输出
  AnalyticsService().trackEvent('app_crash', metadata: {
    'error': details.exceptionAsString(),
    'stack': details.stack.toString(),
    'fatal': true,
  });
};

PlatformDispatcher.instance.onError = (error, stack) {
  AnalyticsService().trackEvent('app_crash', metadata: {
    'error': error.toString(),
    'stack': stack.toString(),
    'fatal': false,
  });
  return true; // 标记已处理，防止闪退
};
```

### Pattern 4: Silent failure for non-critical operations

```dart
// 一言 API 获取失败不影响任何功能
HitokotoService().fetchHitokoto(); // Fire and forget, 不 await
```

---

## Error Propagation Rules

| Layer | Strategy |
|-------|----------|
| **Service** | Catch I/O errors, return null / empty list / false |
| **Provider** | Catch service exceptions, update UI state (loading/error state) |
| **UI** | Display user-friendly error via `SkeuomorphicToast` |

### Never do:
- ❌ Let exceptions propagate to the UI framework uncaught
- ❌ Show raw error messages to users
- ❌ Swallow errors silently without any logging

---

## API Error Responses

N/A — PaperWhisper does not have its own API server. External API calls (HitokotoService, UpdateService) handle errors individually with try-catch.

---

## Common Mistakes

1. **Not checking `mounted` after async operations** — Widget may have been disposed
2. **Crashing on null file content** — Always provide fallback parsing
3. **Not handling permission denied on Android 11+** — Use `permission_handler` to check and request
4. **Retrying indefinitely on network errors** — Set reasonable timeout and abort
5. **Showing raw `Exception` to users** — Wrap in user-friendly Chinese messages
