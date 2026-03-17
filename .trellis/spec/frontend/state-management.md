# State Management

> How state is managed in PaperWhisper using the Provider pattern.

---

## Overview

PaperWhisper uses **Provider** (`package:provider`) as its sole state management solution. The app has 4 providers registered at the root level via `MultiProvider`:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => SettingsProvider()),
    ChangeNotifierProvider(create: (_) => DiaryProvider(diaryService, initialEntries)),
    ChangeNotifierProxyProvider<DiaryProvider, SyncProvider>(
      create: (_) => SyncProvider(),
      update: (_, diary, syncProvider) => syncProvider!..updateDiaryProvider(diary),
    ),
    ChangeNotifierProvider.value(value: PaymentService()),
  ],
  ...
)
```

---

## State Categories

### 1. Global State (via Provider)

| Provider | Responsibility |
|----------|---------------|
| `SettingsProvider` | Theme, startup page, compatibility mode |
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

### ProxyProvider (dependent providers):
```dart
ChangeNotifierProxyProvider<DiaryProvider, SyncProvider>(
  create: (_) => SyncProvider(),
  update: (_, diary, syncProvider) => syncProvider!..updateDiaryProvider(diary),
)
```

---

## Service Singletons vs Providers

**Important distinction**: Services are singletons used for I/O operations but are NOT reactive. Providers wrap services and add reactivity.

```
UI ← watches → Provider ← calls → Service ← does → I/O (file, network)
```

Example flow:
1. User taps "Save" → calls `context.read<DiaryProvider>().saveEntry(entry)`
2. `DiaryProvider.saveEntry()` → calls `DiaryService().saveEntry(entry)` (file I/O)
3. `DiaryProvider` → calls `notifyListeners()` → UI rebuilds

---

## Real Code Examples

- [`main.dart`](../../paper_whisper_flutter/lib/main.dart) — root `MultiProvider` wiring for `SettingsProvider`, `DiaryProvider`, `SyncProvider`, and `PaymentService`
- [`editor_page.dart`](../../paper_whisper_flutter/lib/pages/editor_page.dart) — uses `context.read<SyncProvider>()` for save-triggered side effects without subscribing the whole page to sync rebuilds
- [`settings_page.dart`](../../paper_whisper_flutter/lib/pages/settings_page.dart) — scopes premium badge rebuilds with `Consumer<PaymentService>` instead of rebuilding the whole settings screen
- [`sidebar_widget.dart`](../../paper_whisper_flutter/lib/widgets/sidebar_widget.dart) — uses `context.watch<DiaryProvider>()` where the widget really needs reactive diary data

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

---

## Common Mistakes

1. **Using `context.watch` when no rebuild is needed** — Use `context.read` for fire-and-forget calls
2. **Calling `notifyListeners()` in a loop** — Batch updates, call once at the end
3. **Putting I/O logic in Provider instead of Service** — Provider should delegate to Service
4. **Creating new Provider for throwaway state** — Use local `StatefulWidget` state instead
5. **Not using `ChangeNotifierProxyProvider` for dependent providers** — Leads to stale references
