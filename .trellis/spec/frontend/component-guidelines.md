# Component (Widget) Guidelines

> How widgets are built in PaperWhisper.

---

## Overview

PaperWhisper uses a **skeuomorphic design language** — all UI components must feel physical and tactile. Widgets are standard Flutter `StatelessWidget` / `StatefulWidget` classes.

---

## Widget Structure

### Standard layout of a widget file:

```dart
import 'package:flutter/material.dart';
// 其它依赖

class SkeuomorphicFoo extends StatelessWidget {
  // 1. 字段声明 (final)
  final Widget child;
  final double? width;
  final VoidCallback? onTap;

  // 2. 构造函数
  const SkeuomorphicFoo({
    super.key,
    required this.child,
    this.width,
    this.onTap,
  });

  // 3. 命名工厂构造函数（用于变体）
  factory SkeuomorphicFoo.variant({...}) { ... }

  // 4. build 方法
  @override
  Widget build(BuildContext context) { ... }
}
```

### Key conventions:
- Use `const` constructors wherever possible
- Group related parameters logically
- Use `super.key` (not `Key? key`)

---

## Props Conventions

1. **Use `required` for essential props** — don't silently default important values
2. **Use nullable types for optional props** — `double? width`, not `double width = 0`
3. **Callbacks use `VoidCallback` or typed `Function`** — e.g., `VoidCallback? onTap`
4. **Named factory constructors for presets** — see `SkeuomorphicContainer.paper()`, `SkeuomorphicContainer.inset()`

---

## Styling Patterns

### Theme-driven styling (preferred):

All colors, gradients, and shadows come from `AppTheme` static methods:

```dart
final theme = AppTheme.getDiaryCardTheme(settings.currentTheme);
// Returns a Map with keys like 'backgroundColor', 'textColor', 'shadow', etc.
```

### Skeuomorphic requirements for every visual component:

| Element | Required | Example |
|---------|----------|---------|
| `BoxShadow` (drop shadow) | ✅ Always | `BoxShadow(blurRadius: 20, offset: Offset(0, 10))` |
| Inner shadow / border highlight | ✅ For "pressed" states | `Border.all(color: Colors.white24)` top highlight |
| Gradient (simulating light) | ✅ For surfaces | `LinearGradient` top-light to bottom-dark |
| Texture overlay | 📝 When appropriate | Paper grain, wood grain from `assets/textures/` |
| Border radius | ✅ Small values (4-12px) | Physical objects have subtle rounding |

### Forbidden:
- ❌ Flat solid colors without any shadow
- ❌ Sharp rectangular corners (unless representing paper edges)
- ❌ Material Design `ElevatedButton`, `Card` — use custom skeuomorphic replacements

---

## Custom Page Transitions

The app uses handcrafted page transitions instead of default Material transitions:

| Transition | File | Usage |
|-----------|------|-------|
| Book flip | `book_flip_page_route.dart` | Diary reading mode |
| Paper fold | `paper_fold_page_route.dart` | General navigation |
| Slide | `slide_page_route.dart` | Settings sub-pages |
| Unfold | `unfold_page_route.dart` | Editor opening |
| Smooth cover | `smooth_cover_page_route.dart` | Modal-like pages |

Global default transition is `_SkeuomorphicPageTransitionsBuilder` in `app_theme.dart` — a fade + slide-up with `easeOutQuart` curve.

---

## Accessibility

- Use `Semantics` widget for screen reader labels on custom interactive elements
- Ensure sufficient color contrast even with skeuomorphic textures
- All interactive elements must have a minimum 48x48dp hit area

---

## Common Mistakes

1. **Using `Theme.of(context)` Material colors directly** — Always go through `AppTheme.getXxxTheme()` methods instead
2. **Forgetting dark theme support** — Every component must look correct in "午夜星尘" (midnight) theme
3. **Hardcoding colors inline** — Extract to `AppTheme` static methods
4. **Creating new widgets without shadows** — Appears flat and breaks the visual language
5. **Not testing on both Windows and Android** — Layout differences between desktop and mobile
6. **新增页面主题方法后未覆盖所有主题** — `AppTheme.getXxxTheme()` 必须包含全部 7 种主题 case（含 `default` fallback），并在本地切换全部主题验证无视觉断层
7. **工具栏按钮添加不必要的边框/背景** — 底栏图标按钮应使用 `GestureDetector + Padding + Icon` 的简洁模式，不要用 `Container + Border.all` 包裹，否则违反拟物化简洁风格
8. **AppTheme 方法中用 boolean 变量 + if-else 判断主题** — 应使用 `switch(theme)` 语句，不要声明 `isMidnight`/`isTwilight` 等布尔变量再用 if-else 链
