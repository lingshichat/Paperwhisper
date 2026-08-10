# Directory Structure

> PaperWhisper Flutter 的 feature-first 目录规范。依赖方向和跨层接口见 [Architecture Boundaries](./architecture-boundaries.md)。

---

## Current Layout

```text
paper_whisper_flutter/
├── lib/
│   ├── main.dart                         # 仅调用 bootstrap()
│   ├── app/
│   │   ├── bootstrap.dart                # 初始化、Service/Provider composition root
│   │   ├── app.dart                      # MaterialApp、启动页、锁屏与自动同步接线
│   │   ├── app_lifecycle_observer.dart   # 生命周期转发
│   │   ├── navigation/                   # AppRoutes 与全部自定义 Route
│   │   └── shell/                        # Sidebar 与 shell 独占数据
│   ├── core/
│   │   ├── analytics/                    # 跨域分析能力
│   │   ├── platform/                     # 平台判定工具
│   │   ├── storage/                      # 跨域存储基础设施与端口
│   │   └── theme/                        # 七主题、typed component data、视觉效果
│   ├── features/
│   │   ├── auth/{data,application,presentation}/
│   │   ├── diary/{data,application,presentation}/
│   │   ├── editor/{data,application,presentation}/
│   │   ├── moments/{data,application,presentation}/
│   │   ├── sync/{data,application,presentation}/
│   │   ├── settings/{application,presentation}/
│   │   ├── sync_settings/{application,presentation}/
│   │   ├── update/{data,application,presentation}/
│   │   └── about, export, library, permissions, premium,
│   │       statistics, trash ...
│   └── shared/
│       └── widgets/                      # 无 feature 依赖的跨域 UI primitive
├── test/                                 # 结构尽量映射 lib/；旧测试路径可渐进整理
├── assets/
└── pubspec.yaml
```

Git 跟踪的 `lib/` 根不得重新出现 `config/`、`models/`、`pages/`、`providers/`、`services/`、`utils/` 或 `widgets/`。

---

## Ownership Rules

| Location | Owns | Does not own |
|---|---|---|
| `app/` | 启动、装配、全局生命周期、导航、shell | 业务规则、业务持久化 |
| `core/` | 真正跨域且与业务模型解耦的基础能力 | 页面、业务 Provider、单域 Service |
| `features/<domain>/data` | 模型、序列化、持久化、外部网关 | Widget、BuildContext、页面状态 |
| `features/<domain>/application` | Provider、Controller、Coordinator、typed outcome | Dialog、Toast、Navigator、RenderObject |
| `features/<domain>/presentation` | 页面、域内 Widget、UI intent 翻译 | 可复用 I/O、跨页全局装配 |
| `shared/widgets` | 已有多个跨域消费者的 UI primitive | SettingsProvider 等 feature 状态、单域组件 |

### Domain-specific examples

- `DiaryEntry`、`DiaryService`、`DiaryProvider`：`features/diary/`。
- `Moment`、`MomentService`、音频/录音控制器：`features/moments/`。
- `SyncProvider`、Runner、stores、WebDAV/S3 gateway：`features/sync/`。
- `EditorSessionController`、`DiaryExportService`、编辑器组件：`features/editor/`。
- Sidebar：`app/shell/`，不是 shared widget。
- Route transition：`app/navigation/`，不是 feature widget。
- 七主题 visual effects：`core/theme/widgets/`，因为 ThemeRegistry 直接持有它们。

---

## Placement Decision

新增文件时按以下顺序判断：

1. **它是否只服务一个业务域？** 是则放入该 feature。
2. **它属于 data、application 还是 presentation？** 按依赖和生命周期放入对应层。
3. **它是否已有多个稳定的跨域消费者？** 只有 UI primitive 才考虑 `shared/widgets`。
4. **它是否不含业务模型、可由多个域复用？** 满足后才考虑 `core`。
5. **它是否负责应用级接线或页面目标构造？** 放 `app`。

“以后可能复用”不是进入 shared/core 的证据。没有消费者的遗留组件可以暂留最保守边界，但新代码不得仿照扩张。

---

## Layer Rules

- data 不依赖 application/presentation。
- application 不依赖 presentation，也不持有 `BuildContext`。
- core 不依赖 app/features/shared。
- shared 不依赖 app/features。
- presentation 可以依赖本域 data/application、core/shared，以及必要的跨域公开契约。
- 跨页 Route 只在 `app/navigation` 构造。
- manifest-owning Service 只在 `app/bootstrap.dart` 创建一次并注入。

遇到依赖倒置时，先考虑最小端口。例如 `core/storage` 通过 `MomentStorageAccess` 获取图片引用，端口由 `MomentService` 实现，而不是让 core import Moments feature。

---

## Large Files

- 页面超过 1000 行时，不得继续添加新职责；先提取真实的 application/data/presentation 边界。
- 不按行数机械拆分仍然内聚的动画或复杂展示组件。`StatisticsPage`、Lock 动画、媒体主 UI 可在职责清晰时保持单文件。
- 禁止 `part`、`part of`、`*_methods.dart`，也禁止把大量原 State 私有字段搬进 extension 文件伪装拆分。
- `BuildContext`、GlobalKey、Route 动画、`RenderRepaintBoundary` 查找留在 presentation；纯计算、状态机、I/O 才向下提取。

---

## Naming

| Item | Convention | Example |
|---|---|---|
| Page | `snake_case_page.dart` | `diary_list_page.dart` |
| Widget | `snake_case.dart` | `skeuomorphic_dialog.dart` |
| Service | `snake_case_service.dart` | `moment_service.dart` |
| Provider | `snake_case_provider.dart` | `sync_provider.dart` |
| Controller | `snake_case_controller.dart` | `lock_controller.dart` |
| Coordinator | `snake_case_coordinator.dart` | `save_sync_coordinator.dart` |
| Port / gateway | 以能力命名 | `MomentStorageAccess` |

---

## Real Examples

- [`bootstrap.dart`](../../../paper_whisper_flutter/lib/app/bootstrap.dart)：共享 Service 和 Provider 图的唯一装配入口。
- [`app_routes.dart`](../../../paper_whisper_flutter/lib/app/navigation/app_routes.dart)：跨页 Route 工厂。
- [`moment_storage_access.dart`](../../../paper_whisper_flutter/lib/core/storage/moment_storage_access.dart)：core 声明、feature 实现的最小端口。
- [`editor_session_controller.dart`](../../../paper_whisper_flutter/lib/features/editor/application/editor_session_controller.dart)：不持有 BuildContext 的页面会话控制器。
- [`sync_ui_coordinator.dart`](../../../paper_whisper_flutter/lib/features/sync/presentation/sync_ui_coordinator.dart)：把 typed outcome 翻译成 Dialog/Toast。
- [`skeuomorphic_dialog.dart`](../../../paper_whisper_flutter/lib/shared/widgets/skeuomorphic_dialog.dart)：只依赖 core/theme 的共享 UI primitive。

---

## Static Validation

```bash
# 旧 layer-first 入口必须为 0
rg "package:paper_whisper_flutter/(config|models|pages|providers|services|utils|widgets)/" lib test

# 依赖方向必须为 0
rg "package:paper_whisper_flutter/(app|features|shared)/" lib/core
rg "package:paper_whisper_flutter/(app|features)/" lib/shared

# 禁止伪拆分
rg "^part( of)?\\s" lib test
find lib -name '*_methods.dart'

# Route 构造只允许在 app/navigation
rg "MaterialPageRoute|PageRouteBuilder" lib -g '!lib/app/navigation/**'
```
