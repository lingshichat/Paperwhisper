# Widget Lifecycle & Mixin Guidelines

> This file replaces "Hook Guidelines" — Flutter does not have hooks; it uses Widget lifecycle methods and Mixins.

---

## Overview

PaperWhisper uses standard Flutter `StatefulWidget` lifecycle and mixins for shared behavior. There are no React-style hooks. All stateful logic is managed through:

1. **`StatefulWidget` lifecycle** (`initState`, `dispose`, `didChangeDependencies`)
2. **Mixins** (`WidgetsBindingObserver`, `SingleTickerProviderStateMixin`, etc.)
3. **Provider** for cross-widget state sharing

---

## Widget Lifecycle Conventions

### Initialization order in `initState()`:

```dart
@override
void initState() {
  super.initState();
  // 1. 注册观察者
  WidgetsBinding.instance.addObserver(this);
  // 2. 初始化控制器
  _controller = AnimationController(vsync: this, ...);
  // 3. postFrameCallback 中执行需要 context 的操作
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadData();
  });
}
```

### Cleanup in `dispose()`:

```dart
@override
void dispose() {
  // 必须按注册的逆序释放
  WidgetsBinding.instance.removeObserver(this);
  _controller.dispose();
  _scrollController.dispose();
  super.dispose();
}
```

---

## Common Mixins in Use

| Mixin | Purpose | Used in |
|-------|---------|---------|
| `WidgetsBindingObserver` | App lifecycle events | `_MyAppState` — handles lock/unlock on resume/pause |
| `SingleTickerProviderStateMixin` | Single animation `vsync` | Various animated widgets |
| `TickerProviderStateMixin` | Multiple animation `vsync` | Complex animation pages |
| `AutomaticKeepAliveClientMixin` | Keep page alive in PageView | Tab-based pages |

---

## Data Fetching Patterns

### From Service singletons:

```dart
// 在 initState 或 postFrameCallback 中调用
final entries = await DiaryService().getEntries();
```

### From Provider (reactive):

```dart
// build 方法中响应式获取
final diaryProvider = context.watch<DiaryProvider>();
final entries = diaryProvider.entries;
```

### Fire-and-forget:

```dart
// 不阻塞启动流程的操作
HitokotoService().fetchHitokoto(); // 不 await
```

---

## Naming Conventions

| Item | Convention |
|------|-----------|
| Animation controllers | `_xxxController` (e.g., `_fadeController`) |
| Scroll controllers | `_scrollController` |
| Private helper methods | `_buildXxx()` for build helpers, `_loadXxx()` for data loading |
| Callbacks passed to children | `onXxx` (e.g., `onTap`, `onSaved`, `onDeleted`) |

---

## Common Mistakes

1. **Not disposing controllers** — Causes memory leaks. Every `AnimationController`, `ScrollController`, `TextEditingController` MUST be disposed.
2. **Using `context` in `initState`** — Use `WidgetsBinding.instance.addPostFrameCallback` instead.
3. **Calling `setState` after `dispose`** — Guard with `if (mounted) setState(...)`.
4. **Heavy work in `build()`** — Move data processing to `initState` or dedicated methods, not recalculated every frame.
5. **Not using `const` constructors** — Missed rebuild optimization.
