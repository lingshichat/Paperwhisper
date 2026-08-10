# Directory Structure

> How the Flutter frontend code is organized.

---

## Overview

The entire app lives under `paper_whisper_flutter/lib/`. There is no separate backend server — all "backend" logic (storage, sync, database) runs in-process as Dart services.

---

## Directory Layout

```
paper_whisper_flutter/
├── lib/
│   ├── main.dart               # App entry: init services, MultiProvider, MyApp
│   ├── config/
│   │   ├── app_theme.dart      # AppTheme facade used by UI/widgets
│   │   └── theme/
│   │       ├── theme_registry.dart
│   │       ├── components/     # Typed component theme data objects
│   │       └── themes/         # Per-theme palettes/tokens
│   ├── features/               # Feature-first boundaries for extracted domains
│   │   ├── sync/
│   │   │   ├── data/           # Config/scope/trust persistence
│   │   │   ├── application/    # Runner, trust, progress, scheduling, save-sync policy
│   │   │   └── presentation/   # Notification, UI coordinators, status formatter
│   │   ├── editor/
│   │   │   ├── data/           # Export stitching/path/file persistence
│   │   │   ├── application/    # Session and save coordination
│   │   │   └── presentation/   # Editor-specific widgets and painters
│   │   ├── export/             # Cross-page export directory resolution
│   │   │   └── data/           # ExportPathResolver
│   │   ├── permissions/        # Cross-page permission state/request
│   │   │   └── application/    # PermissionCoordinator
│   │   ├── update/             # Update check and download state machines
│   │   │   └── application/    # UpdateCheckCoordinator, UpdateDownloadController
│   │   ├── settings/           # Settings page sections
│   │   │   ├── application/    # Permission/storage/update controllers
│   │   │   └── presentation/   # Section and primitive widgets
│   │   ├── moments/            # Moments timeline/index/send pipeline
│   │   │   ├── application/    # MomentsTimelineController, MomentIndex, MomentSendPipeline, audio/recorder controllers
│   │   │   └── presentation/   # Desktop/search/empty/limit widgets, waterfall
│   │   ├── diary/              # Diary list timeline/announcement
│   │   │   ├── application/    # DiaryTimelineLayoutBuilder, DiaryAnnouncementCoordinator, filter
│   │   │   └── presentation/   # Empty state, update dialog widgets
│   │   ├── sync_settings/      # Sync configuration form
│   │   │   ├── application/    # SyncSettingsFormController
│   │   │   └── presentation/   # Form/status widgets
│   │   └── security/           # Lock screen state machine
│   │       └── application/    # LockController
│   ├── models/                 # Plain Dart data classes
│   │   ├── diary_entry.dart    # DiaryEntry (file-based serialization)
│   │   ├── moment.dart         # Moment (JSON serialization)
│   │   ├── sync_config.dart    # WebDAV / S3 sync configuration
│   │   ├── sync_manifest.dart  # Sync state tracking
│   │   └── update_info.dart    # App update metadata
│   ├── pages/                  # Full-screen page widgets (17 files)
│   │   ├── diary_list_page.dart
│   │   ├── moments_page.dart
│   │   ├── editor_page.dart
│   │   ├── settings_page.dart
│   │   └── ...
│   ├── providers/              # ChangeNotifier-based state (3 files)
│   │   ├── diary_provider.dart
│   │   ├── settings_provider.dart
│   │   └── sync_provider.dart
│   ├── services/               # Shared/injected business logic & I/O
│   │   ├── diary_service.dart
│   │   ├── moment_service.dart
│   │   ├── storage_service.dart
│   │   ├── webdav_sync_service.dart
│   │   ├── s3_sync_service.dart
│   │   └── ...
│   ├── utils/
│   │   └── platform_utils.dart # Platform detection helpers
│   └── widgets/                # Reusable UI components (38 files)
│       ├── skeuomorphic_*.dart # Skeuomorphic base components
│       ├── moment_card.dart
│       ├── sidebar_widget.dart
│       └── ...
├── assets/
│   ├── textures/               # Wood, paper, leather texture images
│   ├── illustrations/          # Decorative illustrations
│   ├── images/                 # App images
│   └── version.json            # Version metadata
└── pubspec.yaml
```

---

## Module Organization

### Rules for new and extracted features:

1. **Feature-owned code** goes directly under `features/<feature>/{data,application,presentation}`; do not stage it in `services/` or `widgets/` for a later move.
2. **Compatibility page shells** may remain in `pages/` while imports migrate. A page owns route/lifecycle/UI intent translation and composes feature presentation widgets; application and I/O logic belong to the feature. `settings_page.dart`、`moments_page.dart`、`diary_list_page.dart`、`sync_settings_page.dart` 已是薄壳（944/907/881/764 行），只装配 section、绑定状态、翻译 typed outcome，不再实现更新/权限/保存后同步/导出路径等横切逻辑。
3. **Cross-feature reusable widgets** stay in `widgets/`; feature-specific widgets stay in `features/<feature>/presentation/widgets/`.
4. **Shared data models** stay in `models/`; a model used by one feature only may live under that feature.
5. **Global reactive state** stays in `providers/`. Local controllers and short-lived state belong to feature application/presentation code, not a new Provider.
6. **Shared infrastructure services** remain in `services/`, but stateful manifest-owning services are created in the composition root and injected rather than reconstructed by pages.
7. **Theme configuration** stays in `config/`; typed theme data belongs under `config/theme/components/`, with public accessors in `config/app_theme.dart` until the typed migration is complete.

### When things grow large:

- Split by owned responsibility: application controller/coordinator, data service, or presentation widget with explicit inputs and outputs.
- A page over 1000 lines must be decomposed before adding more behavior.
- Do not use `part`, `part of`, `*_methods.dart`, or extension files that merely move private methods while preserving one giant State object.
- Keep route animation or `RepaintBoundary` capture in presentation when extracting it would require leaking Widget/RenderObject state into application/data layers.

---

## Naming Conventions

| Item | Convention | Example |
|------|-----------|---------|
| Page files | `snake_case_page.dart` | `diary_list_page.dart` |
| Widget files | `snake_case.dart` | `skeuomorphic_container.dart` |
| Service files | `snake_case_service.dart` | `diary_service.dart` |
| Provider files | `snake_case_provider.dart` | `sync_provider.dart` |
| Model files | `snake_case.dart` | `diary_entry.dart` |
| Classes | `PascalCase` | `DiaryProvider`, `MomentService` |
| Private methods | `_camelCase` | `_buildFlatList()`, `_loadBookMetadata()` |

---

## Examples

- **Feature application boundary**: [`editor_session_controller.dart`](../../paper_whisper_flutter/lib/features/editor/application/editor_session_controller.dart) — owns editor controllers, draft debounce, preview state, and lifecycle without holding BuildContext
- **Cross-page coordinator**: [`save_sync_coordinator.dart`](../../paper_whisper_flutter/lib/features/sync/application/save_sync_coordinator.dart) — decides save-triggered auto-sync policy as typed outcomes, consumed by the page-level `SyncUiCoordinator`
- **Pure path resolution**: [`export_path_resolver.dart`](../../paper_whisper_flutter/lib/features/export/data/export_path_resolver.dart) — platform/permission seams resolve the export directory without file writes or BuildContext
- **Page form controller**: [`sync_settings_form_controller.dart`](../../paper_whisper_flutter/lib/features/sync_settings/application/sync_settings_form_controller.dart) — owns the 8 input controllers, validation, and save/test/disable actions behind a provider gateway seam
- **Feature data boundary**: [`diary_export_service.dart`](../../paper_whisper_flutter/lib/features/editor/data/diary_export_service.dart) — plans chunks, stitches captures, and writes JPEG output through injectable persistence seams
- **Feature presentation boundary**: [`editor_body.dart`](../../paper_whisper_flutter/lib/features/editor/presentation/widgets/editor_body.dart) — receives explicit controllers, values, and callbacks while keeping save/sync behavior outside the widget
- **Shared service**: [`diary_service.dart`](../../paper_whisper_flutter/lib/services/diary_service.dart) — shared file-backed service created at the composition root
- **Shared widget**: [`skeuomorphic_container.dart`](../../paper_whisper_flutter/lib/widgets/skeuomorphic_container.dart) — named factory constructors for cross-feature tactile surfaces
- **Shared model**: [`moment.dart`](../../paper_whisper_flutter/lib/models/moment.dart) — immutable fields and serialization factories

---

## Common Anti-patterns

1. **把文件/网络逻辑塞进页面或小组件** — UI 留在 presentation，I/O 和平台差异下沉到 data/service 边界
2. **用 `part` / `*_methods.dart` 伪装拆分** — 如果新文件仍依赖原 State 的大量私有字段，就没有形成可维护边界
3. **在页面里新增一套散装主题常量** — 新主题字段先进入 `config/theme/components/`，再通过 typed facade 暴露给 UI
4. **为了局部状态新增 Provider** — 输入框、草稿 Timer、动画控制器等短生命周期状态应由页面或 feature controller 管理
5. **在页面内重新创建有状态 Service** — 从 composition root 注入共享实例，防止 manifest/cache 状态分歧
