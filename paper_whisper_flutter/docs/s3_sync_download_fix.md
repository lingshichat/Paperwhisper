# 修复：S3 同步下载静默失败

> 修复日期：2026-02-12

## 问题描述

手机端写完日记/随心记同步到 S3 云端后，电脑端触发同步下载，但新内容不出现在列表中。所有下载操作**静默失败**，没有报错提示。

## 根因分析

### 故障链路

```
statObject (HEAD请求) → S3 返回 204 → minio 抛 "200 expected, got 204"
    ↓
整个 try 块中断 → getObject (GET请求) 从未执行
    ↓
旧代码 _isSuccess204() 静默返回 → 调用者以为下载成功
    ↓
manifest 记录了文件 → 但磁盘上从未写入
    ↓
下次同步：本地 manifest 已有该条目 → SKIP，永远无法下载
```

### 核心问题

某些 S3 兼容存储服务（如 Cloudflare R2）的 `HEAD` 请求返回 **HTTP 204** 而非 200。Dart minio 客户端对非 200 响应抛出异常。

在旧代码中，`statObject`（HEAD）和 `getObject`（GET）在**同一个 try-catch** 中，`statObject` 的异常直接中断了后续的 `getObject`——即**实际下载从未发生**。

`_isSuccess204()` 辅助方法将 204 视为成功并静默返回，导致：
1. 调用者以为文件已下载
2. 本地 manifest 被更新为"文件已在本地"
3. 后续同步不再尝试下载该文件

## 修复方案

### 涉及文件

| 文件 | 修改内容 |
|------|----------|
| `lib/features/sync/data/s3_sync_service.dart` | `downloadFile` 方法拆分 try-catch |
| `lib/features/sync/application/sync_provider.dart` | 日记 + 随心记 manifest 更新增加磁盘校验 |

### 1. S3 下载：拆分 statObject 和 getObject

**文件**: `s3_sync_service.dart` — `downloadFile` 方法

```dart
// 修复前：statObject 失败导致 getObject 从未执行
try {
  final stat = await _client!.statObject(bucket, key);  // HEAD → 抛 204
  final stream = await _client!.getObject(bucket, key);  // GET → 从未执行
  // ...写入文件...
} catch (e) {
  if (_isSuccess204(e)) return;  // 静默返回，调用者以为成功
}

// 修复后：两者独立，statObject 失败不影响下载
int total = 0;
try {
  final stat = await _client!.statObject(bucket, key);
  total = stat.size ?? 0;
} catch (e) {
  // statObject 失败仅影响进度条（无法预知文件大小），不阻止下载
}

try {
  final stream = await _client!.getObject(bucket, key);
  // ...写入文件 + 验证磁盘写入...
} catch (e) {
  rethrow;  // 真正的下载错误必须上报
}
```

### 2. Manifest 磁盘一致性校验

**文件**: `sync_provider.dart` — `_syncDiaries` 和 `_syncMomentJsonFiles`

```dart
// 修复前：把所有合并条目都写入本地 manifest
for (var item in mergedItems.values) {
  service.manifestService.updateItem(item.filename, ...);
}

// 修复后：只写磁盘上确实存在的文件
for (var item in mergedItems.values) {
  if (!item.isDeleted) {
    final f = File(path.join(service.dataDir!.path, item.filename));
    if (!f.existsSync()) continue;  // 文件不在磁盘 → 不写 manifest
  }
  service.manifestService.updateItem(item.filename, ...);
}
```

## 验证结果

修复后同步测试：
- ✅ 日记 JSON 文件下载成功（7个）
- ✅ 随心记 JSON 文件下载成功（7个）
- ✅ 音频文件下载成功（2个）
- ✅ 图片正常显示
- ✅ 列表正确展示所有同步内容

## 经验教训

1. **永远不要在同一个 try-catch 中放不相关的操作** — `statObject` 和 `getObject` 是独立操作，前者的失败不应阻止后者
2. **不要将所有非 200 响应都视为可忽略的成功** — 204（No Content）对于需要内容的 GET/HEAD 请求意义不同
3. **manifest 必须与磁盘保持一致** — 只有文件确实存在于磁盘后才能更新 manifest
