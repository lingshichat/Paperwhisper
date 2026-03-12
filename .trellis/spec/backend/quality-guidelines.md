# Quality Guidelines

> Code quality standards for service-layer development.

---

## Overview

Service-layer code follows the same quality bar as frontend code. Key difference: services must prioritize **data safety** above all else.

---

## Forbidden Patterns

### ❌ 1. Direct file deletion without backup

```dart
// 禁止: 直接删除文件
file.deleteSync();

// 正确: 先移到回收站 (TrashService)
await TrashService().moveToTrash(filename);
```

### ❌ 2. Synchronous I/O on the main thread

```dart
// 禁止: 阻塞 UI
final content = file.readAsStringSync();

// 正确: 异步读取
final content = await file.readAsString();
```

### ❌ 3. Storing secrets in plain text

```dart
// 禁止: 明文存密码
prefs.setString('password', password);

// 正确: 存储哈希 (AuthService 使用 crypto 包)
final hash = sha256.convert(utf8.encode(password)).toString();
prefs.setString('password_hash', hash);
```

### ❌ 4. Service with state that doesn't use singleton

```dart
// 禁止: 每次 new 一个新实例
final service = DiaryService();  // 如果没有 singleton 模式会创建多份

// 正确: 使用单例模式 (factory + static _instance)
class DiaryService {
  static final DiaryService _instance = DiaryService._internal();
  factory DiaryService() => _instance;
  DiaryService._internal();
}
```

---

## Required Patterns

### ✅ 1. Init/Reset lifecycle

Every service that manages state must have:
```dart
Future<void> init() async { ... }  // 初始化
void reset() { ... }                // 清理状态 (用于测试/重启)
```

### ✅ 2. Defensive file creation

```dart
// 确保目录存在
directory.createSync(recursive: true);
```

### ✅ 3. Data migration safety

```dart
// 先复制再标记迁移完成，不要先删除再创建
await sourceFile.copy(targetPath);
// 验证复制成功
if (await targetFile.exists()) {
  prefs.setBool('migrated', true);
}
```

### ✅ 4. Platform-aware code

```dart
import 'dart:io' show Platform;

if (Platform.isAndroid) {
  // Android 特有逻辑 (权限, 公共目录)
} else if (Platform.isWindows) {
  // Windows 特有逻辑 (Documents 目录)
}
```

---

## Testing Requirements

- Services should be testable via their `init()` / `reset()` pattern
- File I/O services should use injectable paths for test isolation
- No automated tests are currently enforced but services should be designed to be testable

---

## Code Review Checklist

- [ ] Singleton pattern used correctly
- [ ] `init()` handles first-run vs subsequent-run scenarios
- [ ] File operations have error handling (try-catch)
- [ ] No synchronous I/O on main thread
- [ ] Platform checks where behavior differs
- [ ] Data deletion goes through TrashService
- [ ] Sensitive data uses crypto hashing
- [ ] Chinese comments for non-trivial logic
