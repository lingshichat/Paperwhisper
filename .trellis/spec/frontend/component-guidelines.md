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

Colors, gradients, borders, and shadows come from typed component data:

```dart
final themeId = AppTheme.themeIdOf(context);
final diaryCard = ThemeRegistry.get(themeId).diaryCard;

Text(title, style: TextStyle(color: diaryCard.titleColor));
```

Shared widgets use the ThemeExtension published by `AppTheme.getThemeData()` and must not import `SettingsProvider`.

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

| Transition | Class | Usage |
|-----------|-------|-------|
| Book flip | `BookFlipPageRoute` | Diary reading mode |
| Letter/paper fold | `LetterFoldPageRoute` | Physical paper navigation |
| Slide | `SlidePageRoute` | Settings sub-pages |
| Unfold | `UnfoldPageRoute` | Editor opening |
| Smooth cover | `SmoothCoverPageRoute` | Modal-like pages |

All Route classes live in `app/navigation/route_transitions.dart`; cross-page factories live in `app/navigation/app_routes.dart`. Global default transition remains `_SkeuomorphicPageTransitionsBuilder` in `core/theme/app_theme.dart`.

---

## Accessibility

- Use `Semantics` widget for screen reader labels on custom interactive elements
- Ensure sufficient color contrast even with skeuomorphic textures
- All interactive elements must have a minimum 48x48dp hit area

---

## Scrollable Glass Surfaces

Wrap each scrollable glass-card collection in one `BackdropGroup`, and use
`BackdropFilter.grouped` in each glass card. Flutter can then share one backdrop
operation across visible cards.

```dart
final BackdropKey _cardsBackdropKey = BackdropKey();

BackdropGroup(
  backdropKey: _cardsBackdropKey,
  child: ListView.builder(
    itemCount: entries.length,
    itemBuilder: (context, index) => GlassCard(entries[index]),
  ),
);

if (!useGlassEffect) return child;
return BackdropFilter.grouped(
  filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
  child: child,
);
```

Required behavior:

- One independently scrolling collection owns one group. Use a stable explicit key when
  its owning `State` or tests need to verify group identity.
- Non-glass cards omit `BackdropFilter`; near-zero sigma still creates a compositing layer.
- Variable-height collections use builder-backed scrolling. Desktop masonry uses
  `MasonryGridView.builder`, not eager `SingleChildScrollView -> Row -> Column` trees.
- Preserve sorting, column thresholds, padding, spacing, callbacks, and theme visuals.
- A transient full-height `Drawer` must not blur the route while opening; a fixed desktop
  sidebar may retain blur.
- Tests cover lazy card counts, no filter in non-glass themes, shared keys, columns, and
  spacing.

---

## Scenario: Editor Session, Save, And Export Boundaries

### 1. Scope / Trigger

Apply this contract when changing editor input state, draft recovery, save/delete behavior, route preview synchronization, long-image export, or editor-specific widgets. The page lives at `features/editor/presentation/editor_page.dart`; editor data/application/presentation responsibilities stay inside that feature.

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

## Scenario: Page Coordinators And Device-State Controllers

### 1. Scope / Trigger

Apply this contract when changing 页面横切逻辑（更新检查、权限、保存后同步、导出路径、同步文案），或设置/随心记/日记列表/同步设置四个页面的协调器与控制器。页面分别位于各自 feature 的 `presentation/`；新逻辑继续落入 `features/{export,permissions,update,settings,moments,diary,sync_settings,auth,sync}/`。

### 2. Signatures

```dart
// 共享应用边界（context-free）
UpdateCheckCoordinator({
  UpdateCheckGateway? gateway,
  Future<void> Function(Duration)? delay,
  Set<String>? sessionCheckedPurposes,
});
Future<UpdateCheckOutcome> checkAuto({
  required String purpose,
  Duration delay = Duration.zero,
});
Future<UpdateCheckOutcome> checkManual({String? knownCurrentVersion});
// UpdateCheckOutcome: UpdateCheckAvailable(info, currentVersion) | UpdateCheckUpToDate |
//                    UpdateCheckFailure(error) | UpdateCheckSkipped

PermissionCoordinator({statusOf, request, isHarmonyOS});
Future<PermissionSnapshot> checkAll(); // storage/photos/notification + grantedCount/isAllGranted/summary
Future<bool> isStorageGranted();
Future<PermissionRequestOutcome> requestPermission(Permission permission);
// PermissionRequestOutcome: granted | denied | permanentlyDenied

SaveSyncCoordinator();
Future<SaveSyncDecision> decideAfterSave(SyncProvider provider);
bool shouldAutoSync(SyncProvider provider);
// SaveSyncDecision: SaveSyncAutoSync | SaveSyncPending(pendingCount) | SaveSyncSaved

ExportPathResolver({
  bool Function()? isAndroid,
  Future<bool> Function()? isManageExternalStorageGranted,
  Future<Directory> Function()? applicationDocumentsDirectory,
  Future<Directory?> Function()? externalStorageDirectory,
});
Future<Directory> resolve();

SyncStatusFormatter();
String? formatPlatform(String? platform);
String formatTime(DateTime time); // settings 风格，分钟不补零
String formatTimePadded(DateTime time); // sync_settings 风格，分钟补零
String formatLastSyncLine(DateTime at, String? platform, {required bool padMinutes});
String formatCompactStatus(SyncTrustSnapshot snapshot); // 7 状态文案
SyncStatusCardText buildStatusCard(SyncTrustSnapshot snapshot); // title + lines
```

```dart
// 页面边界控制器（owned/injected，页面负责 UI 翻译）
MomentsTimelineController({
  DateTime? initialDate,
  DateTime Function()? clock,
  void Function(VoidCallback callback)? scheduleEndJump,
});
// indexForDate（上下界钳制）/dateForIndex/pageForRulerOffset/rulerOffsetForPage
// isSameDay/selectDate/endDate/isDateInRange/isJumping/jumpToDate
// shouldProcessRulerScroll/rulerScrollEnded/shouldProcessPageScroll/pageScrollEnded
MomentIndex.build(List<Moment> moments);
// dayKey(DateTime) 未补零 yyyy-M-d
// hasContentOnDate / momentsForDate / imageCountForDate / latestMoments
MomentSendPipeline({
  required MomentService momentService,
  required bool Function() canUseProFeatures,
  required int Function() todayMomentCount,
});
Future<MomentSendResult> send({
  required String content,
  List<File> images = const [],
  String? audioPath,
  String? audioTitle,
  int? audioDuration,
});
MomentAudioController({
  required String? audioPath,
  required String? baseDir,
  Duration? initialDuration,
  MomentAudioGateway? gateway,
  String Function(String, String)? pathJoiner,
});
void initialize(); Future<MomentAudioToggleResult> toggle(); void dispose();
MomentRecorderController({MomentRecorderGateway? gateway, Stream<void>? tickStream});
void initialize();
Future<MomentRecorderResult> start();
Future<MomentRecorderResult> stop();
Future<MomentRecorderResult> cancel();
void deleteAudio();
Future<MomentRecorderResult> togglePreview();
void clearAfterSend();
void dispose();

DiaryTimelineLayoutBuilder.build({required List<DiaryTimelineInput> items, required double width});
// -> DiaryTimelineLayout(units, monthTargetMap, itemYearMap)；列数 >1100→3 / >700→2 / 其余→1
DiaryAnnouncementCoordinator({DiaryAnnouncementGateway? gateway});
Future<DiaryAnnouncementOutcome> prepare(); // Pending(currentVersion) | None | Failure
Future<DiaryAnnouncementOutcome> resolve(DiaryAnnouncementPending pending); // Show(info) | None | Failure

SyncSettingsFormController({required SyncConfig config}); // owns exactly 8 TextEditingController
void hydrate(SyncConfig config);
SyncConfig buildConfig({required SyncConfig base, required bool enabled});
bool validate();
Future<SyncFormActionOutcome> saveAndTest(SyncProviderGateway gateway);
Future<SyncFormActionOutcome> disableSync(SyncProviderGateway gateway);
// manual sync remains in SyncSettingsPage because SyncUiCoordinator owns BuildContext/UI feedback.

LockController({LockAuthGateway? gateway, LockScreenMode mode = LockScreenMode.unlock});
Future<void> initialize();
PinKeyResult appendDigit(String value);
PinKeyResult delete();
Future<LockSubmitResult> submit();
Future<LockBiometricResult> authenticateBiometric();
void setUseBiometric(bool value);
void dispose();

UpdateDownloadController({UpdateDownloadGateway? gateway});
Future<void> start(UpdateInfo info);
void cancel();
Future<void> install();
Future<bool> fallback(UpdateInfo info, {bool useBackup = false});
void dispose();
// state: UpdateDownloadState{phase, received, total, path, error, installMessage, progress}

SettingsPermissionController({SettingsPermissionGateway? gateway}); // load/request/isHarmonyOS
SettingsStorageController({required SettingsStorageGateway gateway}); // load/clean*/formatSize/dispose
SettingsUpdateController({UpdateCheckCoordinator? coordinator}); // manualCheck/currentVersion/checking/dispose
```

### 3. Contracts

- **Application 边界不持有 BuildContext。** `UpdateCheckCoordinator`、`PermissionCoordinator`、`SaveSyncCoordinator`、`ExportPathResolver`、`SyncStatusFormatter` 以及全部页面控制器只返回 typed outcome / snapshot / 状态流，不构建 Widget、不弹 Toast/Dialog、不导航。
- **页面翻译 UI intent。** Toast、Dialog、Navigator、错误动画、`openAppSettings` 等留在页面或 presentation 协调器（`SyncUiCoordinator`）。页面是薄壳：装配 section、绑定状态、翻译 typed 结果。
- **owned / injected dispose。** Widget/Page 自建的控制器由自身 `dispose()`；外部注入的控制器仍由注入方释放。控制器内部创建的 TextEditingController、Timer、AudioPlayer/Recorder、CancelToken 与订阅必须全部释放；应用级共享的 SyncProvider、UpdateService、AuthService 不由页面控制器释放。
- **Provider 不替换。** 跨页响应式状态仍在 `SyncProvider` / `DiaryProvider` / `SettingsProvider`；控制器经构造或 Provider 获取，不新增状态管理库，不为短生命周期状态新增 Provider。
- **控制器不读取主题。** Controller、Coordinator 与纯函数不读取 ThemeRegistry；typed component data 只在 presentation 使用。
- **<1000 行约束。** 页面超过 1000 行必须先拆分再增加行为。当前基线：settings 944、moments 939、diary_list 881、sync_settings 764、editor 581。
- **去重语义已定义。** `UpdateCheckCoordinator.checkAuto` 对同一 purpose 开始即置位、失败回滚；这有意修复 Moments 失败后永久跳过，并把 DiaryList 自动检查收敛为进程内一次。`SaveSyncCoordinator` 三分支与 `SyncStatusFormatter` 的全部 `SyncTrustState` 文案必须保持当前测试契约。
- 新类型直接落入所属 feature；通用类型只有出现多个真实消费方时才进入 shared/core（本阶段 `ExportPathResolver` 为 `features/export/`，无新 shared 层）。

### 4. Validation & Error Matrix

| Condition | Required behavior |
|---|---|
| 自动更新检查期间重复触发同一 purpose | 返回 `UpdateCheckSkipped`，不重复网络请求 |
| 自动更新检查网络异常 | 返回 `UpdateCheckFailure` 并回滚去重标记，不永久锁死后续检查 |
| 手动检查不受去重限制 | `checkManual` 总是执行并返回 `UpdateCheckUpToDate` / `UpdateCheckAvailable` / `UpdateCheckFailure` |
| 权限请求被永久拒绝 | 返回 `permanentlyDenied`，页面提示跳系统设置 |
| 权限请求被拒绝（可再请求） | 返回 `denied`，页面保留重试入口 |
| 保存后启用自动同步 | 返回 `SaveSyncAutoSync`，页面展示准备文案并走通知权限 + `requestAutoSync` |
| 保存后未启用自动同步但 pending>0 | 返回 `SaveSyncPending(pendingCount)`，页面提示 N 项待同步 |
| 保存后无待同步内容 | 返回 `SaveSyncSaved`，仅提示保存成功 |
| Android 且存储已授权 | 导出目录为 `/storage/emulated/0/Pictures/PaperWhisper` |
| Android 未授权 | 外部目录 `Exports`，无则 documents `Exports` 兜底 |
| 非 Android | documents `PaperWhisper_Exports` |
| PIN setup 两次不一致 | `LockMismatch`，重置回 setup 模式并清空输入 |
| 下载中取消 | 回 idle 并取消 CancelToken，后台工作不越过 dialog 生命周期 |
| 录音被拒权限 | `MomentRecorderPermissionDenied`，页面提示，不崩溃 |
| 播放文件缺失 | `MomentAudioToggleMissing`，页面提示 `音频文件丢失`，不抛未处理异步异常 |
| UpdateDialog 错误态且 changelog 很长 | 操作区可滚动，360×600 视口不得 RenderFlex overflow |

### 5. Good / Base / Bad Cases

- Good: 用户在设置页手动检查更新 → `checkManual` 返回 `UpdateCheckAvailable` → 页面打开 `UpdateDialog` → 下载阶段经 `UpdateDownloadController` 状态流驱动进度条，取消后回 idle。
- Base: 随心记发送成功后 `MomentSendPipeline` 返回成功 → 页面刷新列表并调用 `SaveSyncCoordinator.decideAfterSave` → 按三分支展示对应 Toast。
- Bad: 把 `BuildContext`、Toast、Navigator、`GlobalKey` 移入协调器/控制器以压缩页面行数；或页面直接 new `UpdateService()` 绕过注入。

### 6. Tests Required

- 协调器/纯函数单元测试：`test/features/{update,permissions,sync,export}/` — 去重回滚、权限三分支、SaveSync 三分支、导出路径三分支、Formatter 全部状态文案。
- 页面控制器测试：`test/features/{moments,diary,sync_settings,auth,settings}/` — 日期换算、index 分组、send pipeline 额度、表单校验、Lock PIN 状态机、录音/播放状态流。
- 页面行为刻画测试：`test/pages/{settings,moments,diary_list}_page_test.dart` + `test/widgets/sync_settings_page_test.dart` — 主链路交互断言。
- 双平台 widget smoke：14 个文件覆盖 `TargetPlatform.android` 与桌面视口，断言 `tester.takeException()` 为 null。

### 7. Wrong vs Correct

#### Wrong

```dart
// 协调器里弹 Toast / 持有 context
class UpdateCheckCoordinator {
  final BuildContext context; // ❌
  Future<void> check() async {
    final info = await UpdateService().checkForUpdate();
    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(...); // ❌
    }
  }
}
```

#### Correct

```dart
await Future<void>.delayed(const Duration(seconds: 2));
if (!mounted) return; // delay 后、网络请求前检查页面生命周期

final outcome = await updateCoordinator.checkAuto(purpose: 'moments');
if (!mounted) return;
switch (outcome) {
  case UpdateCheckAvailable(:final info, :final currentVersion):
    showUpdateDialog(context, info, currentVersion); // 页面翻译
  case UpdateCheckUpToDate():
  case UpdateCheckFailure():
  case UpdateCheckSkipped():
    break;
}
```

---

## Real Code Examples

- [`editor_page.dart`](../../../paper_whisper_flutter/lib/features/editor/presentation/editor_page.dart) — owns route/lifecycle/UI intent translation and composes editor feature boundaries
- [`editor_session_controller.dart`](../../../paper_whisper_flutter/lib/features/editor/application/editor_session_controller.dart) — owns input controllers, 200-character preview, draft debounce, and disposal without BuildContext
- [`editor_export_surface.dart`](../../../paper_whisper_flutter/lib/features/editor/presentation/widgets/editor_export_surface.dart) — renders keyed Header/Body/Footer capture surfaces from explicit props without performing capture or I/O
- [`skeuomorphic_container.dart`](../../../paper_whisper_flutter/lib/shared/widgets/skeuomorphic_container.dart) — cross-feature tactile primitive with named constructors like `.paper()` and `.inset()`
- [`moment_input_widget.dart`](../../../paper_whisper_flutter/lib/features/moments/presentation/widgets/moment_input_widget.dart) — reads typed `MomentInputThemeData` and owns its media UI lifecycle
- [`moments_month_calendar.dart`](../../../paper_whisper_flutter/lib/features/moments/presentation/widgets/moments_month_calendar.dart) — inline occupancy calendar; Sunday-first grid; locked 296px panel
- [`moments_timeline_controller.dart`](../../../paper_whisper_flutter/lib/features/moments/application/moments_timeline_controller.dart) — `jumpToDate` + injectable `scheduleEndJump`
- [`update_dialog.dart`](../../../paper_whisper_flutter/lib/features/update/presentation/update_dialog.dart) — custom stateful dialog with mounted guards, download state machine, and bespoke skeuomorphic presentation
- [`route_transitions.dart`](../../../paper_whisper_flutter/lib/app/navigation/route_transitions.dart) — centralized physical page transitions

---

## Common Mistakes

1. **Using generic Material colors for a themed component** — Read the matching typed component data from `ThemeRegistry`
2. **Forgetting dark theme support** — Every component must look correct in "午夜星尘" (midnight) theme
3. **Hardcoding theme branches inline** — Add a typed field to the relevant `*ThemeData` class
4. **Creating new widgets without shadows** — Appears flat and breaks the visual language
5. **Not testing on both Windows and Android** — Layout differences between desktop and mobile
6. **新增主题字段后只填写部分主题** — 必须逐一填写 7 个主题，并做双平台视觉回归；不得用 default fallback 掩盖漏项
7. **工具栏按钮添加不必要的边框/背景** — 底栏图标按钮应使用 `GestureDetector + Padding + Icon` 的简洁模式，不要用 `Container + Border.all` 包裹，否则违反拟物化简洁风格
8. **AppTheme 方法中用 boolean 变量 + if-else 判断主题** — 应使用 `switch(theme)` 语句，不要声明 `isMidnight`/`isTwilight` 等布尔变量再用 if-else 链
9. **滚动页面未固定 AppBar 的 scrolled-under 状态** — 在 `PageView` / `ListView` 等可滚动页面中，如果顶栏颜色需要保持恒定，必须显式设置 `surfaceTintColor`、`scrolledUnderElevation`，必要时通过 `notificationPredicate` 禁用滚动通知驱动的自动变色
10. **卸载仍需 `jumpToItem` 的尺子** — `RulerDatePicker` 外部 `controller` 的 `initState` 不会按 `selectedDate` 自跳。日历打开时必须 `AnimatedAlign(heightFactor: 0)` 保持挂载，禁止 `if (!open) Ruler`。
11. **用 `selectedDate` 属性断言尺子对齐** — `selectDate` 会改 prop，但 `jumpToItem` 被跳过时轮子仍停在旧日。对齐 oracle 必须是 `controller.selectedItem`。
12. **默认 48px `IconButton`/`TextButton` 塞进锁定高度的月历头** — 头栏必须 `SizedBox(height: 40)` + `tapTargetSize: shrinkWrap` 或 `GestureDetector`，否则 296px 面板 overflow。
13. **`extendBodyBehindAppBar` 后再垫 `kToolbarHeight`** — body 的 `MediaQuery.padding.top` 已是 AppBar 全高，`SafeArea` 足够让月历紧贴顶栏。再垫 56px 会在顶栏和月历之间留出空隙。
14. **月历标题放进不对称 `Row` 的 `Expanded`** — 左 40px chevron、右「今天」+40px，标题会偏左。标题必须单独铺满宽度居中，控件用 `Stack` 叠在两侧；中间 `IgnorePointer`，否则挡掉横向滑动。

---

## Scenario: Moments Month Calendar

### 1. Scope / Trigger

随心记顶栏展开月历、占用圆点、远跳时间线、或改 `MomentIndex` / `MomentsTimelineController` / `RulerDatePicker` 挂载方式时适用。日历只服务 moments 域，放 `features/moments/presentation/widgets/`，禁止 `shared/widgets`、禁止日历第三方库、禁止改 Moment JSON。

### 2. Signatures

```dart
static String MomentIndex.dayKey(DateTime date); // 未补零 yyyy-M-d
bool MomentIndex.hasContentOnDate(DateTime date); // containsKey(dayKey)

MomentsTimelineController({
  DateTime? initialDate,
  DateTime Function()? clock,
  void Function(VoidCallback callback)? scheduleEndJump,
});
DateTime get endDate;
bool isDateInRange(DateTime date);
bool get isJumping;
void jumpToDate(DateTime date); // jumpToPage + jumpToItem；seam 清 isJumping

class MomentsMonthCalendar {
  final DateTime selectedDate;
  final DateTime startDate;
  final DateTime endDate;
  final bool Function(DateTime date) hasContentOnDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback? onJumpToToday;
}
```

### 3. Contracts

- 占用只读内存索引，不扫盘。ValueKey 必须用 `MomentIndex.dayKey`：`moments_cal_$key` / `moments_cal_mark_$key`。
- 展开态是页面 `bool`，不进 Provider。收起发生在 listener / setState / post-frame，不在 `build` 赋值。
- 远跳用 `jumpToDate`，不走 `_onDateChanged(animate: true)`。`_onDateChanged` 见 `isJumping` 则 return。
- 生产默认 `scheduleEndJump` 为 post-frame；纯 `test()` 必须注入同步或捕获回调，禁止碰 `WidgetsBinding.instance`。
- 移动端尺子视觉隐藏但保持挂载：`ClipRect` + `AnimatedAlign(heightFactor: 0)` + `IgnorePointer` + `SizedBox(height: 85)`。
- `extendBodyBehindAppBar` 时 `_BodyBuilder` 已把 AppBar 全高写入 `MediaQuery.padding.top`，`SafeArea(top: true)` 即可让月历紧贴顶栏。禁止再垫 `kToolbarHeight`，否则会多出一段空隙。
- 月历几何：`ConstrainedBox(maxHeight: 296)`，头 `SizedBox(height: 40)`，星期 `SizedBox(height: 22)`，`mainAxisExtent: 36`，固定 6 行，`shrinkWrap` + `NeverScrollableScrollPhysics`。周日首列用 `weekday % 7`，不用 `DateUtils.firstDayOffset`。
- 标题保持 `yyyy年M月` + `Icons.arrow_drop_down`，不展示当日图片计数；展开块内月份走横向 `PageView`（Key `moments_cal_pager`），chevron 与滑动都 `animateToPage` 300ms `easeOutCubic`；标记是数字下 5×5 圆点。
- 展开块月份标题相对面板几何中心居中。左右 chevron 与「今天」叠在头栏两侧，不进标题 `Row` 布局。禁止 `Expanded` 夹在 40px 左箭头和「今天」+右箭头之间。
- 桌面空态必须传 `selectedDate`，禁止 `DateTime.now()`。
- 格子 48×36 是有意低于 48×48 的规范例外（360 宽 + 6 行否则压没 PageView）。

### 4. Validation & Error Matrix

| Condition | Required behavior |
|---|---|
| 点非选中日 | `jumpToDate` 后收起；尺子 `controller.selectedItem` 与 Page 同 index |
| 点当前已选日 | 只收起，不 `jumpToDate` |
| 日期越出 `[startDate, endDate]` | `indexForDate` 钳制到 `[0, dayRange-1]`，灰显不可点 |
| 搜索（含 Sidebar `momentsSearchQuery`） | 打不开；已打开则 listener 收起 |
| 输入聚焦 | 收起 |
| `viewInsets.bottom` `0 → >0` | post-frame 收起；insets 一直 >0 不重复关 |
| Android 返回且日历开着 | `PopScope` 只收起，不 pop 路由 |
| 卸载尺子再 jump | 禁止。`hasClients==false` 会跳过 `jumpToItem`，remount 后尺子错位 |

### 5. Good/Base/Bad Cases

- Good: 打开月历 → 点昨天 → 列表昨天、尺子 `selectedItem == yesterdayIndex`、月历收起。
- Base: 点标题展开/再点收起；无记录日无 `moments_cal_mark_*`。
- Bad: `if (!open) RulerDatePicker(...)`；`test()` 不注入 `scheduleEndJump`；`expect(ruler.selectedDate, yesterday)`；`find.text('12')`。

### 6. Tests Required

- `moment_index_test`：`dayKey(DateTime(2026, 11, 3)) == '2026-11-3'`；有记录 true / 缺省 false。
- `moments_timeline_controller_test`：注入 seam；clamp；`dispose` 后 `jumpToDate` 不抛。禁止断言 `initialPage`。
- `moments_timeline_controller_jump_test`：有界 `PageView` + `ListWheelScrollView`，`pump()` 后 `page` 与 `selectedItem`。
- `moments_month_calendar_test`：钉死 `selectedDate: DateTime(2026, 3, 10)`；`ThemeRegistry.init()`；标记 Key；头高 == 40；360×800 无 overflow；月份标题 `center.dx` 对齐面板；滑动 / chevron 切月后新月标题在面板内。
- `moments_page_test`：尺子对齐用 `controller!.selectedItem`；桌面空的非今天 → 「这天没有留下记录」；90 天远跳无 `animateToPage`；PopScope；聚焦 / 键盘边沿收起。

### 7. Wrong vs Correct

#### Wrong

```dart
if (!_isCalendarOpen) RulerDatePicker(...);
WidgetsBinding.instance.addPostFrameCallback((_) => _isJumping = false); // 写死在控制器里
expect(find.text('12'), findsOneWidget);
expect(ruler.selectedDate, yesterday);
MomentsEmptyState(date: DateTime.now(), theme: theme);
```

#### Correct

```dart
ClipRect(
  child: AnimatedAlign(
    heightFactor: hide ? 0 : 1,
    child: IgnorePointer(
      ignoring: hide,
      child: SizedBox(height: 85, child: RulerDatePicker(...)),
    ),
  ),
);
MomentsTimelineController(scheduleEndJump: (cb) => cb()); // 纯单测
expect(
  tester.widget<RulerDatePicker>(find.byType(RulerDatePicker))
      .controller!
      .selectedItem,
  yesterdayIndex,
);
MomentsEmptyState(date: _timeline.selectedDate, theme: theme);
```
