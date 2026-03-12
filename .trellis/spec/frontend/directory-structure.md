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
│   │   └── app_theme.dart      # Centralized theme system (~4000 lines)
│   ├── models/                 # Plain Dart data classes
│   │   ├── diary_entry.dart    # DiaryEntry (file-based serialization)
│   │   ├── moment.dart         # Moment (JSON serialization)
│   │   ├── sync_config.dart    # WebDAV / S3 sync configuration
│   │   ├── sync_manifest.dart  # Sync state tracking
│   │   └── update_info.dart    # App update metadata
│   ├── pages/                  # Full-screen page widgets (16 files)
│   │   ├── diary_list_page.dart
│   │   ├── moments_page.dart
│   │   ├── editor_page.dart
│   │   ├── settings_page.dart
│   │   └── ...
│   ├── providers/              # ChangeNotifier-based state (3 files)
│   │   ├── diary_provider.dart
│   │   ├── settings_provider.dart
│   │   └── sync_provider.dart
│   ├── services/               # Business logic & I/O (17 files, singletons)
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

### Rules for new features:

1. **Pages** go in `pages/` — one file per screen, named `*_page.dart`
2. **Reusable widgets** go in `widgets/` — named descriptively (e.g., `skeuomorphic_dialog.dart`)
3. **Data models** go in `models/` — plain Dart classes with `toJson()`/`fromJson()`
4. **State management** goes in `providers/` — only if global state is needed
5. **Business logic / I/O** goes in `services/` — singleton pattern via factory constructor
6. **Theme configuration** stays in `config/app_theme.dart` — static methods returning theme maps

### When things grow large:
- Split page logic into helper widgets or `*_methods.dart` partial files
- A page over 1000 lines should be refactored into sub-widgets

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

- **Well-organized service**: [`diary_service.dart`](../../paper_whisper_flutter/lib/services/diary_service.dart) — clean singleton, init/reset pattern, clear CRUD methods
- **Well-organized widget**: [`skeuomorphic_container.dart`](../../paper_whisper_flutter/lib/widgets/skeuomorphic_container.dart) — named factory constructors for variants (`.paper()`, `.inset()`)
- **Well-organized model**: [`moment.dart`](../../paper_whisper_flutter/lib/models/moment.dart) — immutable fields, factory constructors for creation and deserialization
