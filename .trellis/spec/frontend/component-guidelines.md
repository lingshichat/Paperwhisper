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

## Scenario: Editor Session, Save, And Export Boundaries

### 1. Scope / Trigger

Apply this contract when changing editor input state, draft recovery, save/delete behavior, route preview synchronization, long-image export, or editor-specific widgets. The compatibility shell remains `pages/editor_page.dart`; new editor logic belongs under `features/editor/`.

### 2. Signatures

```dart
EditorSessionController({
  required DiaryEntry? initialEntry,
  required DraftService draftService,
});

Future<DraftRestoreInfo?> checkDraftRestore();
Future<void> performAutoSave();
Future<void> awaitPendingAutoSave();
void syncPreviewText();
void dispose();

EditorSaveCoordinator({
  required DiaryProvider diaryProvider,
  required EditorSessionController session,
});
Future<EditorSaveResult> save();
Future<EditorDeleteResult> delete(String filename);

DiaryExportChunkPlan buildChunkPlan(String text);
Future<DiaryExportResult> export({
  required DiaryExportChunkPlan plan,
  required String baseName,
  required DiaryChunkCapture capture,
});
```

### 3. Contracts

- `EditorPage` owns Widget lifecycle, route animation, dialogs/toasts/navigation, typed-result translation, GlobalKeys, and `RenderRepaintBoundary` lookup.
- `EditorSessionController` owns title/content/200-character preview controllers, editor metadata, the 2-second draft timer, in-flight draft writes, and disposal. It never holds BuildContext.
- Programmatic initialization/restoration suppresses the text listener. Restored content may make `hasChanges` true but must not schedule an immediate redundant draft write.
- On pause, persist dirty draft state immediately. On dispose, cancel timers, remove listeners, and dispose all three text controllers.
- Save/delete first cancel debounce, await an in-flight draft write, then mutate the diary. Success clears the draft; save failure preserves it.
- UI messages, sync feedback, and route reverse/pop order remain in the page and consume the context-free sync contract from `features/sync/`.
- Preview text is capped at 200 characters; content over 3000 characters keeps the Sliver performance path.
- Long-image export uses one header, 40-line body chunks, and one footer; captures at pixel ratio 3.0 and encodes JPEG quality 90.
- `DiaryExportService` may receive test directory/timestamp seams, but production defaults and file name `diary_<base>_<milliseconds>.jpg` remain unchanged.
- Export temporary state is restored in `finally`; consumed `ui.Image` objects are disposed.
- Metadata keeps the original Row at sufficient width and uses grouped wrapping below 300 logical pixels of available content width; text and controls must not be hidden or scaled.

### 4. Validation & Error Matrix

| Condition | Required behavior |
|---|---|
| Draft equals the original entry | Clear the stale draft and do not prompt |
| Draft is shorter than the original content | Return restore info with `isIncomplete=true` |
| Draft write is still in flight when Save/Delete starts | Wait for it before diary mutation and final draft clear |
| Timer-triggered draft write fails | Catch/log without content, keep dirty state for retry, and do not emit an unhandled async error |
| Diary save fails | Return `EditorSaveFailure`; preserve the draft and page state |
| Delete fails | Preserve existing exception propagation until the product contract explicitly changes |
| One export chunk cannot be captured | Skip it; continue if at least one chunk succeeds |
| All export chunks fail | Throw `DiaryExportException('No content captured')` and restore capture UI state |
| Export directory does not exist | Create it recursively before writing |
| Metadata renders in a 360×800 Android viewport | Wrap groups without RenderFlex overflow |

### 5. Good / Base / Bad Cases

- Good: A debounce write is in flight, the user taps Save, the write completes, the diary saves, and only then is the draft cleared.
- Base: A short new diary renders the full body in preview and exports as Header + one Body + Footer.
- Bad: Move `BuildContext`, Toast, Navigator, `GlobalKey`, or `RenderRepaintBoundary` into `EditorSessionController` or `DiaryExportService` to reduce page line count.

### 6. Tests Required

- Public page behavior: initialize/edit, draft restore, debounce/pause, save/delete/return confirmation, sync feedback, dispose, long-content preview, and export entry.
- Controller unit tests: 200/201 preview boundary, every tracked metadata field, restore suppression, timer reset/cancel, failed write retry, and disposed controllers.
- Save coordinator tests: every persisted `DiaryEntry` field, save/delete ordering, failure draft retention, and a Completer-gated in-flight write.
- Export service tests: 39/40/41/80/81-line boundaries, null/all-null captures, image dimensions, JPEG decode, deterministic path, and image disposal.
- Presentation widget tests: callbacks/visibility, 360×800 Android overflow checks, painter repaint fields, and export key ordering.

### 7. Wrong vs Correct

#### Wrong

```dart
Future<void> save() async {
  await draftService.clearDraft('new');
  await diaryProvider.saveEntry(entry); // failure already lost the draft
}

class DiaryExportService {
  final BuildContext context;
  final GlobalKey repaintKey;
}
```

#### Correct

```dart
session.cancelPendingAutoSave();
await session.awaitPendingAutoSave();
final result = await saveCoordinator.save();

switch (result) {
  case EditorSaveSuccess():
    await SyncUiCoordinator(context).handleSaveAutoSync(...);
  case EditorSaveFailure(:final error):
    showSafeSaveError(error);
  case EditorSaveValidation():
    break;
}
```

---

## Real Code Examples

- [`editor_page.dart`](../../paper_whisper_flutter/lib/pages/editor_page.dart) — compatibility shell that owns route/lifecycle/UI intent translation and composes editor feature boundaries
- [`editor_session_controller.dart`](../../paper_whisper_flutter/lib/features/editor/application/editor_session_controller.dart) — owns input controllers, 200-character preview, draft debounce, and disposal without BuildContext
- [`editor_export_surface.dart`](../../paper_whisper_flutter/lib/features/editor/presentation/widgets/editor_export_surface.dart) — renders keyed Header/Body/Footer capture surfaces from explicit props without performing capture or I/O
- [`skeuomorphic_container.dart`](../../paper_whisper_flutter/lib/widgets/skeuomorphic_container.dart) — base tactile primitive with named constructors like `.paper()` and `.inset()`
- [`moment_input_widget.dart`](../../paper_whisper_flutter/lib/widgets/moment_input_widget.dart) — reads `AppTheme.getMomentInputTheme(...)` and applies shadows, rounded surfaces, and themed icon colors instead of Material defaults
- [`update_dialog.dart`](../../paper_whisper_flutter/lib/widgets/update_dialog.dart) — custom stateful dialog with mounted guards, download state machine, and bespoke skeuomorphic presentation
- [`book_flip_page_route.dart`](../../paper_whisper_flutter/lib/widgets/book_flip_page_route.dart) — custom page transition that reinforces the physical-book interaction model

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
9. **滚动页面未固定 AppBar 的 scrolled-under 状态** — 在 `PageView` / `ListView` 等可滚动页面中，如果顶栏颜色需要保持恒定，必须显式设置 `surfaceTintColor`、`scrolledUnderElevation`，必要时通过 `notificationPredicate` 禁用滚动通知驱动的自动变色
