# Design

## Target Boundaries

```text
SyncProvider (ChangeNotifier facade)
  -> SyncConfigStore / SyncScopeCacheStore
  -> SyncTrustEngine
  -> SyncRunner
  -> SyncProgressTracker
  -> AutoSyncScheduler
  -> SyncNotificationService
  -> SyncErrorClassifier
```

边界可在实施中按耦合证据合并，但不得重新形成万能 Service。

## File Placement

- 新提取类型直接放入 `features/sync/data`、`features/sync/application` 或 `features/sync/presentation`，不先落 `lib/services/` 再二次搬迁。
- 现有 `SyncProvider` 暂时保留原路径作为兼容门面，阶段 5 再随业务域整体移动，避免本阶段扩大 import diff。

## Context And UI

- Provider 与 Runner 不接收 BuildContext。
- OS 通知服务只负责通知插件；`SyncUiCoordinator` 负责单次手动/自动同步动作的权限说明、命令执行结果和同步 UI intent，不负责“业务保存后是否应触发同步”的跨功能策略。
- 阶段 4 的 `SaveSyncCoordinator` 消费本阶段的 context-free 同步命令与结果，统一处理日记/随心记保存后的 pending/auto-sync 决策。
- 同步命令返回 typed result/state，由页面决定具体 Toast、Dialog 和 Navigator 行为。

## Instance Ownership

- `main.dart`/app bootstrap 创建共享 DiaryService 与 MomentService。
- DiaryProvider、SyncProvider、StatisticsService、StorageService 和页面通过构造或 Provider 获取共享依赖。
- `MomentService.exportDailySummary` 接收 DiaryService，不再局部 new。
- ManifestService 写操作进入可等待的串行队列；共享服务实例与回归测试共同防止旧缓存覆盖。

## Compatibility

所有 prefs/secure-storage 键、JSON、scope ID、云端路径、时间戳判胜、batch 限流、超时、流量保护和通知标识原样保留。

## Migration Strategy

先提取纯函数，再持久化，再调度/通知，再状态机，最后 Runner 与实例所有权。每一步保持 SyncProvider 门面可编译，调用点只在 Context 解耦时集中适配。
