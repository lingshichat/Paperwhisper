# Quality Guidelines

> Code quality standards for PaperWhisper Flutter development.

---

## Overview

PaperWhisper uses `flutter_lints` (included via `analysis_options.yaml`) as its baseline linting configuration. Code comments are written in **Chinese (中文)**.

---

## Lint Configuration

```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml
```

Run analysis:
```bash
flutter analyze
```

---

## Forbidden Patterns

### ❌ 1. Using Material Design defaults

```dart
// 禁止: 使用 Material 的 ElevatedButton
ElevatedButton(onPressed: ..., child: Text('Save'))

// 正确: 使用自定义拟物按钮或 GestureDetector + 自定义容器
GestureDetector(
  onTap: ...,
  child: SkeuomorphicContainer.paper(child: Text('Save')),
)
```

### ❌ 2. Hardcoded colors / 嵌套三元表达式判断主题

```dart
// 禁止 (1): 内联硬编码颜色值
Container(color: Color(0xFFF4ECD8))

// 禁止 (2): 在 Widget 层进行多重三元表达式判断主题
Container(
  color: isSeaFlower 
      ? Color(0xFFAD1457) 
      : (isMidnight ? Color(0xFFc9d1d9) : Color(0xFFD7CCC8))
)

// 正确: 提取到 AppTheme，通过专有的 Theme 方法获取整个颜色配置 Map 或单个 Color
final themeConfig = AppTheme.getSyncSettingsTheme(settings.currentTheme);
Container(color: themeConfig['textColor'])
// 或
Container(color: AppTheme.getPaperColor(settings.currentTheme))
```

### ❌ 3. `print()` for debugging in committed code

```dart
// 禁止: print 会留在生产代码中
print('Debug: $value');

// 正确: 使用 debugPrint 或 analytics
debugPrint('Debug: $value');
// 或者使用 AnalyticsService
AnalyticsService().trackEvent('event_name', metadata: {...});
```

### ❌ 4. Blocking the main thread during startup

```dart
// 禁止: 串行 await 所有 init
await serviceA.init();
await serviceB.init();
await serviceC.init();

// 正确: Future.wait 并行初始化
await Future.wait([
  serviceA.init(),
  serviceB.init(),
  serviceC.init(),
]);
```

### ❌ 5. Git commit by AI

AI agents should **NOT** execute `git commit`. Only humans commit code.

---

## Required Patterns

### ✅ 1. `mounted` check before `setState`

```dart
if (mounted) {
  setState(() { _isLoading = false; });
}
```

### ✅ 2. Const constructors

```dart
const SkeuomorphicContainer({super.key, required this.child, ...});
```

### ✅ 3. Error boundaries for crash reporting

```dart
FlutterError.onError = (FlutterErrorDetails details) {
  FlutterError.presentError(details);
  AnalyticsService().trackEvent('app_crash', metadata: { ... });
};
```

### ✅ 4. Graceful timeout for non-critical operations

```dart
await diaryService.loadCache().timeout(
  const Duration(milliseconds: 150),
  onTimeout: () => null,
);
```

### ✅ 5. Chinese comments in code

```dart
// 并行初始化：极限压缩启动时间
final results = await Future.wait([...]);
```

---

## Testing Requirements

- Run `flutter analyze` before committing — must pass with zero errors
- Manual testing on both **Windows** and **Android** for UI changes
- No automated unit tests are currently enforced (test directory exists but is minimal)

---

## Code Review Checklist

- [ ] No hardcoded colors — uses `AppTheme` methods
- [ ] No Material default widgets in custom UI
- [ ] All controllers are disposed in `dispose()`
- [ ] `mounted` guard on all async `setState` calls
- [ ] Chinese comments for non-trivial logic
- [ ] Works on both Windows and Android (responsive layout)
- [ ] Skeuomorphic shadows and gradients present on new visual elements
- [ ] No `print()` statements left in code
