# Design

## Target Shape

```text
features/editor/
  presentation/editor_page.dart
  presentation/widgets/*
  application/editor_session_controller.dart
  application/editor_save_coordinator.dart
  data/diary_export_service.dart
```

具体目录名可贴合最终项目结构，但依赖方向保持 presentation -> application -> services/providers。

## Controller Boundary

`EditorSessionController` 持有标题、正文、预览 Controller，编辑元数据、草稿 debounce 和 hasChanges。保存/删除通过注入的 DiaryProvider/DraftService 处理，返回 typed result；Toast、Dialog 和 Navigator 留在页面。

编辑器只适配阶段 2 提供的 context-free 同步命令与结果，不在本阶段创建通用 `SaveSyncCoordinator`。跨日记与随心记复用的保存后同步策略由阶段 4 统一实现。

## Export Boundary

展示层负责 RepaintBoundary 捕获；`DiaryExportService` 负责分块、图片拼接、路径解析和文件写入。导出结果返回路径与统计，不持有 BuildContext。

## Lifecycle Invariants

- 200 字预览和 route reverse 同步保持在页面/会话控制器的明确接口中。
- 页面 pause 时立即草稿保存。
- dispose 后 Timer、Controller、FocusNode、route listener 全部失效。
- 保存成功清草稿，失败保留草稿。

## UI Decomposition

只提取有完整 props 的 TopBar、MetaSelector、EditorBody、ExportSurface 和 Painter；不拆散相互依赖的 route animation 与 preview 优化。
