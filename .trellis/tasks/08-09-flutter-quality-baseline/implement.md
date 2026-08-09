# Implementation Plan

1. 记录当前 analyzer issue 分类与 18 个测试结果。
2. 修复两处同步开关的 Material 边界，先跑 `sync_settings_page_test.dart`，再跑完整测试。
3. 添加至少 4 个行为刻画测试；测试必须先在当前实现上通过或准确暴露既有缺陷。
4. 补齐 Editor、MomentEditor、Intro 和 SyncProvider 的 dispose/cancel。
5. 逐文件修复 `use_build_context_synchronously`，优先保存、聚合、导航和权限链路。
6. 处理剩余 analyzer info：下划线、花括号、插值、import、override 与合理的 CLI lint 说明。
7. 运行格式化、`flutter analyze`、聚焦测试、完整 `flutter test`，并完成 Windows/Android 同步设置页冒烟。
8. 派发独立 check 子代理，核对无业务流程改变和无视觉回归。

## Worktree Lanes

- `task/flutter-quality-baseline`：拥有所有产品代码修复；不得新增或改写 T1-T4 测试文件。
- `lane/flutter-quality-baseline-tests`：只拥有 `test/providers/`、`test/services/` 中的 T1-T4 行为测试；不得修改 `lib/`。
- 两 lane 可并行编辑，但 Flutter 命令串行执行。测试 lane 先形成 checkpoint，集成到 child 后再完成产品修复与全量质量门。
- 机械 lint 与生命周期修复都由 child worktree 串行处理，避免同时修改 editor/sync_provider。

## Validation

```bash
cd paper_whisper_flutter
flutter analyze
flutter test test/widgets/sync_settings_page_test.dart
flutter test test/providers/sync_provider_test.dart
flutter test test/services/moment_service_test.dart
flutter test
```

## Stop Conditions

- 任一新增测试需要改变既有产品行为才能通过。
- SwitchListTile 修复改变布局、颜色或触控区域。
- Analyzer 清理触及持久化或同步语义。

## Sub-Agent Constraints

使用 `cch/deepseek-v4-flash`。禁止 install/update/upgrade，禁止修改 Trellis/Pi/Codex 配置，禁止 commit/push/merge。

## Completion Evidence

| Gate | Result |
|---|---|
| Product implementation review | PASS；25 个允许文件，无持久化、同步、导航或视觉参数回归 |
| Test lane review | PASS；T1-T4 与跨平台开关冒烟均面向公开可观察行为 |
| `flutter analyze` | 0 issue，exit 0 |
| Focused tests | sync settings 4/4、sync provider 10/10、moment service 3/3 |
| Full suite | 24/24，exit 0 |
| Main integration | `2c09146`、`dab6257`、`cf95257` |

真实 Android 设备未连接；老师将在 `main` 工作区执行最终真机视觉检查，该结果由父任务最终验收统一收口，不阻塞后续依赖屏障。
