# Design

## Change Shape

本阶段不引入新架构，只建立可靠基线。变更分为四类：框架断言修复、资源生命周期、异步 Context、行为测试。

## Decisions

- 两处 `SwitchListTile` 使用透明 Material 边界，保留外层拟物背景；若 Flutter 断言仍存在，再改为等价 Row + Switch。
- State 字段 Controller/Timer 必须由拥有者释放；局部 dialog controller 不扩展范围。
- await 后 UI 操作统一使用 `context.mounted` 或 State `mounted`，不能靠 analyzer ignore。
- 纯 lint 机械修复与风险修复分批，便于审查。
- `tool/sync_version.dart` 的 CLI 输出保留 `print`，用文件级 lint 说明其合理性。

## Test Design

新增测试只断言公开状态、持久化结果和可观察行为，不锁定私有方法顺序。重点覆盖：

- saveConfig 保存但不触发真实同步。
- 未启用/未配置同步安全早退。
- 同步失败后的 trust snapshot 与 pending。
- Moment 保存后 Manifest 内容。

## Rollback Boundaries

1. SwitchListTile 修复。
2. 新增行为测试。
3. Controller/Timer 生命周期。
4. BuildContext 与机械 lint 收敛。
