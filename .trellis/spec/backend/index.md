# Backend (Services Layer) Development Guidelines

> PaperWhisper is a client-side Flutter app with no separate backend server. This "backend" refers to the **services layer** — business logic, data persistence, and external API integrations running in-process.

---

## Tech Stack

| Category | Choice |
|----------|--------|
| Language | Dart (same as frontend) |
| Data storage | File system (text/JSON), `shared_preferences` |
| Cloud sync | `webdav_client` (WebDAV), `minio` (S3-compatible) |
| HTTP | `http` package |
| Audio | `audioplayers`, `record` |
| Analytics | Custom `AnalyticsService` (Umami-based) |

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Service organization and file layout | ✅ Filled |
| [Database Guidelines](./database-guidelines.md) | Data storage patterns (file-based, not SQL) | ✅ Filled |
| [Error Handling](./error-handling.md) | Error types, handling strategies | ✅ Filled |
| [Quality Guidelines](./quality-guidelines.md) | Code standards, forbidden patterns | ✅ Filled |
| [Logging Guidelines](./logging-guidelines.md) | Logging and analytics conventions | ✅ Filled |

---

## Architecture

```
UI (Pages/Widgets)
    ↕ watches/reads
Providers (DiaryProvider, SyncProvider, SettingsProvider)
    ↕ calls
Services (DiaryService, MomentService, WebDavSyncService, ...)
    ↕ does
I/O (File system, SharedPreferences, Network)
```

All services use the **singleton pattern** with factory constructors. Providers are the reactive bridge between services and UI.

---

**Language**: Code comments should be in **Chinese (中文)**.
