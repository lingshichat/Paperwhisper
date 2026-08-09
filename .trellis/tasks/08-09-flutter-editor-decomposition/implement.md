# Implementation Plan

1. 补编辑器保存、草稿恢复/清理、自动保存 debounce、返回确认和导出行为测试。
2. 创建 editor feature 边界与 `EditorSessionController`，先迁草稿和编辑状态。
3. 迁移保存/删除编排，只适配同步域提供的 context-free 结果契约；不在本阶段抽取跨页面 SaveSyncCoordinator。
4. 提取导出路径与 `DiaryExportService`；保持 RepaintBoundary 布局和图片样式。
5. 提取 TopBar、MetaSelector、EditorBody、ExportSurface 与 Painter。
6. 收敛 `EditorPage` 为生命周期、路由动画和组件装配。
7. 运行格式化、analyze、聚焦测试、完整测试和双平台冒烟。
8. 派发独立 check，重点检查草稿竞态、dispose 和长内容预览。

## Worktree Lanes

- `task/flutter-editor-decomposition`：唯一拥有 `editor_page.dart` 和 editor feature 接线。
- `lane/flutter-editor-decomposition-tests`：只创建/维护 `test/pages/editor_page_test.dart` 及测试 fake，不修改 `lib/`。
- 控制器、导出和展示组件都收敛到同一页面，必须在 child worktree 内串行提取；不再拆多个实现 lane。
- 测试 lane 可与第一批控制器提取并行，但同步反馈测试以阶段 2 已集成契约为准。

## Validation

先在步骤 1 创建 `test/pages/editor_page_test.dart`，再执行：

```bash
cd paper_whisper_flutter
flutter analyze
flutter test test/pages/editor_page_test.dart
flutter test
```

手测：新建、编辑、天气/心情、切后台、恢复草稿、保存、删除、返回、长日记打开/退出、长图导出。

## Sub-Agent Constraints

使用 `cch/deepseek-v4-flash`。禁止 install/update/upgrade，禁止修改 Trellis/Pi/Codex 配置，禁止 commit/push/merge。

## Rollback Points

- 行为测试。
- SessionController。
- 保存/删除协调。
- ExportService。
- 展示组件与 Painter。

## Completion Evidence

| Checkpoint | Commit |
|---|---|
| SessionController | `325af60` |
| 页面行为刻画 | `404dfba`（child cherry-pick） |
| 保存/删除协调 | `75022f2` |
| SessionController 单测 | `2bf1187`（child cherry-pick） |
| DiaryExportService | `842bf8f` |
| 保存协调与草稿竞态测试 | `54d2aa4`（child cherry-pick） |
| 导出测试 seam | `e68c064` |
| 导出服务完整测试 | `dca7cf0`（child cherry-pick） |
| TopBar/Meta/Body 展示组件 | `ccfc1ed` |
| ExportSurface/Painter | `5e79b6e` |
| Android 360 metadata 响应式修复 | `415e9f5` |
| 展示组件与双平台 smoke 测试 / main 集成 HEAD | `7ed8e15` |

最终 `trellis-check`：format 0 changed、`flutter analyze` 0 issue、编辑器聚焦 115/115、完整测试 324/324，架构与行为审查 PASS。`editor_page.dart` 为 581 行；真实设备权限与导出视觉保留到父任务最终验收。
