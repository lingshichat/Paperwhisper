# Frontend Development Guidelines

> PaperWhisper (纸语) — a Flutter-based skeuomorphic diary app targeting Windows & Android.

---

## Tech Stack

| Category | Choice |
|----------|--------|
| Framework | Flutter 3.47.1 stable (Dart 3.13.1; locked dependency floor Flutter 3.44 / Dart 3.12) |
| State management | Provider (`ChangeNotifier` / `ChangeNotifierProvider`) |
| Animations | `simple_animations`, custom `PageRouteBuilder` transitions |
| UI paradigm | **Skeuomorphism** — realistic textures, shadows, gradients |
| Fonts | Google Fonts (via `google_fonts` package) |
| Styling | Typed theme registry in `core/theme/` |
| Storage | File-system based (plain text files + JSON), `shared_preferences` |
| Sync | WebDAV (`webdav_client`) and S3-compatible (`minio`) |

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Architecture Boundaries](./architecture-boundaries.md) | app/core/features/shared ownership, dependency gates, navigation and theme contracts | ✅ Filled |
| [Directory Structure](./directory-structure.md) | Module organization and file layout | ✅ Filled |
| [Component Guidelines](./component-guidelines.md) | Widget patterns, composition, skeuomorphic design | ✅ Filled |
| [Hook Guidelines](./hook-guidelines.md) | Widget lifecycle, mixins, callbacks | ✅ Filled |
| [State Management](./state-management.md) | Provider-based state, local vs global | ✅ Filled |
| [Quality Guidelines](./quality-guidelines.md) | Code standards, forbidden patterns | ✅ Filled |
| [Type Safety](./type-safety.md) | Dart type patterns, model conventions | ✅ Filled |
| [Refactoring Roadmap](../refactoring-roadmap.md) | 进度、规划与重构路线图 | ✅ Actionable |

---

## Design Philosophy

This project intentionally uses **skeuomorphic design** — every UI element should feel like a physical object with:
- **Real textures** (wood grain, paper, leather)
- **Heavy shadows & inner shadows** for depth
- **Gradients simulating lighting** rather than flat colors
- **Physical micro-interactions** (page flips, cassette wheels, wax seals)

**Flat design is explicitly rejected.** All contributors must maintain this aesthetic.

---

**Language**: Code comments should be in **Chinese (中文)**. Documentation may be in English.
