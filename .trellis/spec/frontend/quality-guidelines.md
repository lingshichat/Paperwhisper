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

// 正确: 读取 ThemeRegistry 的 typed component data
final themeId = AppTheme.themeIdOf(context);
final syncTheme = ThemeRegistry.get(themeId).syncSettings;
Container(color: syncTheme.textColor);
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

AI agents should **NOT** execute `git commit` by default. Only commit after the user explicitly authorizes it and required checks have completed.

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

## Real Code Examples

- [`bootstrap.dart`](../../../paper_whisper_flutter/lib/app/bootstrap.dart) — parallelizes startup with `Future.wait(...)`, installs crash reporting hooks, and keeps non-critical preload work behind timeouts / fire-and-forget calls
- [`moment_input_widget.dart`](../../../paper_whisper_flutter/lib/features/moments/presentation/widgets/moment_input_widget.dart) — disposes every controller/player/timer it owns and reads typed `MomentInputThemeData`
- [`settings_page.dart`](../../../paper_whisper_flutter/lib/features/settings/presentation/settings_page.dart) — translates typed controller outcomes and scopes membership rebuilds with `Consumer`
- [`sync_settings_page.dart`](../../../paper_whisper_flutter/lib/features/sync_settings/presentation/sync_settings_page.dart) — reads typed settings/sync component data instead of runtime theme maps
- [`architecture-boundaries.md`](./architecture-boundaries.md) — defines static dependency gates for app/core/features/shared

---

## Testing Requirements

- Run `flutter analyze` before committing — it must report **0 issues** and exit with code 0
- Run the complete `flutter test` suite after each change batch; focused tests do not replace the full suite
- Add observable behavior characterization tests before moving provider, service, persistence, or page orchestration code
- Manually test UI changes on both **Windows** and **Android** when real devices are available
- For platform-sensitive widgets, add a repeatable widget smoke test using `AppTheme.getThemeData(...).copyWith(platform: ...)`, representative desktop/mobile viewports, interaction assertions, and `tester.takeException()` checks

### Cross-Platform Widget Smoke

```dart
testWidgets('renders on desktop and mobile platforms', (tester) async {
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.getThemeData(
        AppTheme.themeDefault,
      ).copyWith(platform: TargetPlatform.android),
      home: const TargetPage(),
    ),
  );

  expect(tester.takeException(), isNull);
});
```

The test must restore global view state even when an assertion fails. It complements, but does not replace, real-device visual inspection.

### Formatting Scope

Dart SDK formatter changes can rewrite an entire legacy file. For narrow fixes:

1. Format only files owned by the current batch.
2. Keep formatter churn in a reviewable checkpoint separate from later architecture changes.
3. Review semantic changes with `git diff -w` when formatter output is large.
4. Never format unrelated files merely to make the repository globally uniform.

---

## Code Review Checklist

- [ ] No scattered theme branches — uses typed `ThemeRegistry` component data
- [ ] No dynamic theme facade, `toMap()`, or runtime theme cast
- [ ] core/shared/data/application dependency direction passes static checks
- [ ] No Material default widgets in custom UI
- [ ] All controllers are disposed in `dispose()`
- [ ] `mounted` guard on all async `setState` calls
- [ ] Chinese comments for non-trivial logic
- [ ] Works on both Windows and Android (responsive layout)
- [ ] Skeuomorphic shadows and gradients present on new visual elements
- [ ] No `print()` statements left in code
