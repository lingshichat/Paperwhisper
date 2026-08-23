# State Management

> How state is managed in PaperWhisper using the Provider pattern.

---

## Overview

PaperWhisper uses **Provider** (`package:provider`) as its sole state management solution. The root graph registers two shared service instances and four reactive providers:

```dart
final diaryService = DiaryService();
final momentService = MomentService(diaryService: diaryService);

MultiProvider(
  providers: [
    Provider<DiaryService>.value(value: diaryService),
    Provider<MomentService>.value(value: momentService),
    ChangeNotifierProvider(create: (_) => SettingsProvider(...)),
    ChangeNotifierProvider(
      create: (_) => DiaryProvider(
        service: diaryService,
        initialEntries: initialEntries,
      ),
    ),
    ChangeNotifierProxyProvider<DiaryProvider, SyncProvider>(
      create: (_) => SyncProvider(momentService: momentService),
      update: (_, diary, sync) => sync!..updateDiaryProvider(diary),
    ),
    ChangeNotifierProvider.value(value: PaymentService()),
  ],
  ...
)
```

`DiaryService` and `MomentService` are registered as non-reactive dependencies so every page, provider, statistics flow, storage flow, and sync run uses the same manifest-owning instances.

---

## State Categories

### 1. Global State (via Provider)

| Provider | Responsibility |
|----------|---------------|
| `SettingsProvider` | Theme, startup page, compatibility mode, simplified editor transitions |
| `DiaryProvider` | Diary entries, search queries, book metadata |
| `SyncProvider` | WebDAV/S3 sync state, sync progress, conflicts |
| `PaymentService` | Premium membership status |

### 2. Local Widget State

- Animation controllers, scroll positions → `StatefulWidget` local state
- Form input values → `TextEditingController` local to page
- Temporary UI state (expanded/collapsed, loading indicators) → `setState()`

### 3. Persisted State (non-reactive)

| Storage | Data |
|---------|------|
| `SharedPreferences` | Small key-value settings (theme, flags, booleans) |
| File system (text files) | Diary entries content |
| File system (JSON files) | Moments data, sync manifests |
| `shared_preferences` via `AuthService` | Lock/unlock state, password hash |

---

## When to Use Global State

✅ **Use Provider** when:
- Data is needed by 3+ unrelated widgets
- UI needs to react when data changes (diary list updates)
- Data flows bi-directionally between screens

❌ **Keep local** when:
- Data is only for this widget and its children
- Data doesn't survive navigation (ephemeral UI state)
- Data is a controller (scroll, animation, text editing)

---

## Provider Access Patterns

### Read (non-reactive, one-time):
```dart
final provider = context.read<DiaryProvider>();
provider.saveEntry(entry);
```

### Watch (reactive, rebuilds on change):
```dart
final settings = context.watch<SettingsProvider>();
return Text(settings.currentTheme);
```

### Consumer (scoped rebuild):
```dart
Consumer<SettingsProvider>(
  builder: (context, settings, child) {
    return MaterialApp(
      theme: AppTheme.getThemeData(settings.currentTheme),
      ...
    );
  },
)
```

### Immediate settings preview inside overlays

User-facing settings with live preview update the in-memory source of truth and
call `notifyListeners()` before awaiting persistence. A dialog or bottom sheet
that remains open must subscribe inside its own route subtree; passing
`currentTheme` or derived colors only when opening the route creates a stale
snapshot.

```dart
Future<void> setTheme(String theme) async {
  _currentTheme = theme;
  notifyListeners();

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('theme', theme);
}

showModalBottomSheet<void>(
  context: context,
  builder: (sheetContext) => Selector<SettingsProvider, String>(
    selector: (_, settings) => settings.currentTheme,
    builder: (context, theme, _) => ThemeChoiceSheet(
      selected: theme,
      style: ThemeRegistry.get(theme).settings,
    ),
  ),
);
```

Required regression assertions:

- Immediately after calling the setter, listeners have observed the new value,
  even before awaiting the returned persistence `Future`.
- A live-preview overlay remains open, moves its selected marker, and rebuilds
  its typed theme style after one pump.
- The persisted theme and related preference flags still match the selected
  value after the `Future` completes.

### ProxyProvider (dependent providers):
```dart
ChangeNotifierProxyProvider<DiaryProvider, SyncProvider>(
  create: (_) => SyncProvider(momentService: momentService),
  update: (_, diary, syncProvider) => syncProvider!..updateDiaryProvider(diary),
)
```

---

## Service Singletons vs Providers

Services perform I/O but are not reactive. Stateful file services must be created once in the composition root and injected through `Provider<T>` or constructors; pages must not construct another service that writes the same manifest.

```
UI ← watches → Provider ← calls → shared Service ← does → I/O
                         ↑
                 composition root owns it
```

Example flow:
1. `app/bootstrap.dart` creates one `DiaryService` and one `MomentService(diaryService: ...)`.
2. `DiaryProvider`, `SyncProvider`, pages, statistics, and storage receive those exact instances.
3. User taps Save → `DiaryProvider.saveEntry()` writes through the shared `DiaryService`.
4. `DiaryProvider` calls `notifyListeners()` and sync pending calculation reads the same manifest state.

Constructors for manifest-owning consumers require explicit dependencies:

```dart
DiaryProvider(service: diaryService)
SyncProvider(momentService: momentService)
StorageService(momentService: momentService)
StatisticsService(
  diaryService: diaryService,
  momentService: momentService,
)
```

---

## Real Code Examples

- [`bootstrap.dart`](../../../paper_whisper_flutter/lib/app/bootstrap.dart) — owns the shared `DiaryService` / `MomentService` instances and registers services plus reactive providers
- [`sync_provider.dart`](../../../paper_whisper_flutter/lib/features/sync/application/sync_provider.dart) — exposes context-free sync commands and delegates persistence, state calculation, scheduling, notifications, and transfer algorithms inside `features/sync/`
- [`sync_notification_service.dart`](../../../paper_whisper_flutter/lib/features/sync/application/sync_notification_service.dart) — owns OS notification side effects without creating an application → presentation dependency
- [`sync_ui_coordinator.dart`](../../../paper_whisper_flutter/lib/features/sync/presentation/sync_ui_coordinator.dart) — translates typed sync results into permission dialogs and toasts without putting `BuildContext` in the provider
- [`editor_page.dart`](../../../paper_whisper_flutter/lib/features/editor/presentation/editor_page.dart) — uses `context.read<SyncProvider>()` for save-triggered side effects without subscribing the whole page to sync rebuilds
- [`settings_page.dart`](../../../paper_whisper_flutter/lib/features/settings/presentation/settings_page.dart) — scopes premium badge rebuilds with `Consumer<PaymentService>` instead of rebuilding the whole settings screen

---

## Sync Trust Snapshot Contract

`SyncProvider` is the only UI-facing source of truth for sync state. UI code must not infer sync safety from `SyncConfig.enabled` or from toasts alone.

### Required read model

Screens such as `SettingsPage` and `SyncSettingsPage` should render from `provider.trustSnapshot`, especially:

- `state`
- `totalPendingCount`
- `lastSuccessfulSyncAt`
- `lastSuccessfulSyncPlatform`
- `failureReason`
- `configurationInvalid`

### Context-Free Command Boundary

`SyncProvider` must not import `BuildContext`, Widget APIs, permission handlers, notification plugins, or `SharedPreferences`. Its UI-facing commands are typed and context-free:

```dart
Future<SyncRunResult> sync({bool isAuto = false});
Future<AutoSyncDecision?> requestAutoSync({
  bool fromLifecycle = false,
  bool force = false,
});
```

`SyncUiCoordinator` is the presentation boundary for a single sync action. It owns notification permission prompts, dialogs, and toasts, and translates `SyncRunResult` into existing user-facing text. Delayed auto-sync timers must never capture a page context.

```dart
final coordinator = SyncUiCoordinator(context);
await coordinator.runManualSync(context.read<SyncProvider>());
```

The implemented `SaveSyncCoordinator` centralizes cross-feature save policy in `features/sync/application/save_sync_coordinator.dart`. It consumes the same context-free provider commands instead of moving UI dependencies back into `SyncProvider`:

```dart
await SyncUiCoordinator(context).handleSaveAutoSync(
  provider: context.read<SyncProvider>(),
  savedToast: '日记已保存',
  preparingToast: '日记已保存，准备同步...',
);
```

`SyncUiCoordinator` 内部调用 `SaveSyncCoordinator.decideAfterSave(provider)`，再把 `SaveSyncAutoSync` / `SaveSyncPending(pendingCount)` / `SaveSyncSaved` 翻译为权限请求与既有 Toast。页面不直接重复 pending/auto-sync 判定。

### UI rules

- `Testing connection` may save config and validate connectivity, but must not trigger a real sync run
- `Sync now` is the only settings-page action that should start a real sync
- When current target has pending work, show pending counts for the **current scoped target**
- When current target is clean, show the last success time and platform, for example `最近一次成功同步：2026-03-12 09:30（S3）`
- `notEnabled` must remain a reachable UI state; users need a real way to disable sync again

### Good / Base / Bad Cases

- Good: After switching back to a previously synced S3 target, UI returns to `Synced Successfully` with the S3 badge in the success line
- Base: A brand new WebDAV target shows `Local Changes Pending` until its first successful sync
- Bad: UI says `尚有内容待同步` only because the user switched away from and back to a different provider that already had its own clean baseline

## Page Coordinator & Controller Ownership

页面横切职责（更新检查、权限、保存后同步、导出路径）由 `features/{update,permissions,sync,export}/` 下的 context-free 协调器承担，返回 typed outcome（`UpdateCheckOutcome`、`PermissionSnapshot`/`PermissionRequestOutcome`、`SaveSyncDecision`、`Directory`）。它们不持有 BuildContext，页面负责 Toast/Dialog/Navigator 翻译。

短生命周期控制器属于 feature application 层或页面自身，**不为它们新增 Provider**：

| 控制器 | 归属 | 生命周期 |
|---|---|---|
| `MomentsTimelineController` | `features/moments/application/` | 页面 owned，释放 Page/Ruler controllers |
| `MomentIndex` / `MomentSendPipeline` | `features/moments/application/` | 纯索引 / 单次动作对象，无 Widget 生命周期 |
| `DiaryTimelineLayoutBuilder` / `DiaryAnnouncementCoordinator` | `features/diary/application/` | 纯函数 / 页面 owned |
| `SyncSettingsFormController` | `features/sync_settings/application/` | 页面 owned，持有 8 个输入 Controller |
| `LockController` | `features/auth/application/` | 页面 owned |
| `UpdateDownloadController` / `SettingsUpdateController` 等 | `features/{update,settings}/application/` | 页面 owned，随 dialog/页面销毁 |
| `MomentAudioController` / `MomentRecorderController` | `features/moments/application/` | 组件 owned，`dispose()` 释放播放器/录音器 |

Ownership rule: Widget/Page 自建的控制器由自身 `dispose()`；外部注入的控制器由注入方释放。控制器内部创建的 TextEditingController、Timer、AudioPlayer/Recorder、CancelToken 与订阅必须全部释放；应用级共享的 SyncProvider、UpdateService、AuthService 不由页面控制器释放。

---

## Common Mistakes

1. **Using `context.watch` when no rebuild is needed** — Use `context.read` for fire-and-forget calls
2. **Calling `notifyListeners()` in a loop** — Batch updates, call once at the end
3. **Putting I/O or UI logic in Provider** — Provider delegates I/O to services and UI feedback to coordinators
4. **Creating a manifest-owning service inside a page/provider** — Inject the composition-root instance instead
5. **Capturing `BuildContext` in delayed auto-sync callbacks** — Schedule a context-free provider command and render results from state/typed results
6. **Creating new Provider for throwaway state** — Use local `StatefulWidget` state instead
7. **Not using `ChangeNotifierProxyProvider` for dependent providers** — Leads to stale references
