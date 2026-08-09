# Implementation Plan

1. 补测试：Manifest merge、trust 迁移、pending、错误分类、scope migration、媒体差集、scheduler 与多实例写入。
2. 在 `features/sync/` 下提取 `SyncErrorClassifier`，保持错误文案不变。
3. 在 `features/sync/` 下提取 `SyncConfigStore` 和 `SyncScopeCacheStore`，逐键验证序列化兼容。
4. 提取 `SyncProgressTracker`、`AutoSyncScheduler` 和 OS 通知服务，补 dispose/fakeAsync 测试。
5. 提取纯 `SyncTrustEngine`，用迁移矩阵测试锁定八个状态分支。
6. 提取 `SyncRunner`；先 diary/manifest，再 moments/media，分两个回滚批次。
7. 建立同步 UI 协调边界，移除 Provider 的 BuildContext、Dialog 与 Toast 依赖，更新调用点。
8. 在 app bootstrap 统一 DiaryService/MomentService 所有权，序列化 Manifest 写入，移除局部 new 与 reset/init 冗余。
9. 运行同步聚焦测试、完整 analyze/test，完成 Windows/Android 手动/自动同步冒烟，并派发独立 check。

## Worktree Lanes

- `task/flutter-sync-domain`：唯一拥有 `sync_provider.dart`、Runner 接线、实例所有权和 Manifest 写入实现。
- `lane/flutter-sync-domain-tests`：只拥有同步域新增/扩展测试与 fake；不得修改 `lib/`。
- 测试 lane 与 child 实施 lane 可并行；所有提取类型的接线在 child worktree 串行完成，禁止多个 lane 同时改 `sync_provider.dart`。
- 测试 checkpoint 先集成，随后按纯函数、store、调度、trust、runner、所有权顺序形成 child checkpoint。

## Validation

```bash
cd paper_whisper_flutter
flutter analyze
flutter test test/models/sync_trust_snapshot_test.dart
flutter test test/services/manifest_service_test.dart
flutter test test/services/moment_service_test.dart
flutter test test/providers/sync_provider_test.dart
flutter test test/widgets/sync_settings_page_test.dart
flutter test
```

## Rollback Points

- 纯函数与错误分类。
- 配置和 scope store。
- 调度、进度和通知。
- Trust engine。
- Diary runner。
- Moments/media runner。
- UI Context 解耦。
- `features/sync/` 新类型落位；现有 Provider 的目录移动留到阶段 5。
- 实例所有权和 Manifest 序列化。

## Sub-Agent Constraints

使用 `cch/deepseek-v4-flash`。禁止 install/update/upgrade，禁止修改 Trellis/Pi/Codex 配置，禁止 commit/push/merge。

## Completion Evidence

| Checkpoint | Commit |
|---|---|
| 持久化 foundation | `9543085` |
| 状态与调度 | `b3ebe46` |
| foundation 测试 | `081ba20`（child cherry-pick） |
| Runner | `2714d16` |
| 状态/调度测试 | `5c050a7`（child cherry-pick） |
| UI Context 解耦 | `67ab4ed` |
| Runner/pending 测试 | `e8efdac`（child cherry-pick） |
| 共享实例与 Manifest 串行化 | `67cd6c4` |
| typed/UI 测试 | `d2a60c7`（child cherry-pick） |
| Manifest 并发矩阵 | `73fe8c8` |
| 格式收尾 / main 集成 HEAD | `a7f4391` |

最终质量门：format 0 changed、`flutter analyze` 0 issue、聚焦测试 205/205、完整测试 209/209。独立 `trellis-check` 对持久化键、云端路径、时间戳判胜、1 秒限流、15 秒超时、>20 流量保护、通知 ID 888/渠道以及全部调用点判定为 PASS。

真实 Android 通知权限与 WebDAV/S3 网络冒烟留给父任务最终真机验收；后续 child 继续基于 `main@a7f4391`。
