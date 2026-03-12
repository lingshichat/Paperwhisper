# Directory Structure

> How service-layer code is organized in PaperWhisper.

---

## Overview

All service ("backend") code lives in `paper_whisper_flutter/lib/services/`. Services are Dart singleton classes that handle business logic and I/O — there is no separate backend server.

---

## Directory Layout

```
lib/services/
├── diary_service.dart           # 日记 CRUD (file system)
├── moment_service.dart          # 随心记 CRUD (JSON files)
├── storage_service.dart         # Storage stats, cache cleanup
├── manifest_service.dart        # Sync manifest for diff tracking
├── webdav_sync_service.dart     # WebDAV sync implementation
├── s3_sync_service.dart         # S3/MinIO sync implementation
├── cloud_storage_service.dart   # Cloud storage abstraction
├── auth_service.dart            # Local authentication (lock screen)
├── analytics_service.dart       # Usage analytics (Umami)
├── draft_service.dart           # Auto-save draft management
├── hitokoto_service.dart        # "一言" API quote fetcher
├── payment_service.dart         # Premium subscription management
├── trial_service.dart           # Trial period tracking
├── statistics_service.dart      # Diary/moments statistics
├── thumbnail_cache_service.dart # Image thumbnail caching
├── trash_service.dart           # Soft-delete (trash bin)
└── update_service.dart          # Check for app updates
```

---

## Module Organization

### Service categories:

| Category | Services |
|----------|----------|
| **Core data** | `DiaryService`, `MomentService`, `ManifestService` |
| **Storage** | `StorageService`, `DraftService`, `TrashService`, `ThumbnailCacheService` |
| **Sync** | `WebDavSyncService`, `S3SyncService`, `CloudStorageService` |
| **Auth & payment** | `AuthService`, `PaymentService`, `TrialService` |
| **External** | `HitokotoService`, `UpdateService`, `AnalyticsService` |
| **Analytics** | `StatisticsService` |

### Pattern for new services:

1. Create `xxx_service.dart` in `lib/services/`
2. Use singleton pattern (see below)
3. Include `init()` and optionally `reset()` methods
4. Register in `main.dart` if needed at startup

---

## Naming Conventions

| Item | Convention | Example |
|------|-----------|---------|
| Service files | `snake_case_service.dart` | `diary_service.dart` |
| Service classes | `PascalCaseService` | `DiaryService` |
| Init methods | `init()` / `reset()` | `await DiaryService().init()` |
| CRUD methods | `getXxx()` / `saveXxx()` / `deleteXxx()` | `getEntries()`, `saveEntry()` |
| Private helpers | `_camelCase` | `_migrateFromPrivateToPublic()` |

---

## Singleton Pattern

All services follow this pattern:

```dart
class DiaryService {
  // 单例实例
  static final DiaryService _instance = DiaryService._internal();
  
  // 工厂构造函数返回单例
  factory DiaryService() => _instance;
  
  // 私有构造函数
  DiaryService._internal();
  
  // 初始化
  Future<void> init() async { ... }
  
  // 重置 (用于测试或数据清理)
  void reset() { ... }
}
```
