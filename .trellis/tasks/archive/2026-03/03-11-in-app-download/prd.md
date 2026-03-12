# 应用内下载更新

## Goal

将现有“跳转浏览器下载更新”的主路径改为“应用内下载 + 安装”，避免浏览器篡改安装包后缀（如 `.apk` 变 `.zip`）导致安装失败，同时在现有 `UpdateDialog` 中提供清晰的下载进度、取消、重试和浏览器回退能力。

## Requirements

### 核心体验

- 保留现有 `UpdateDialog` 入口和视觉风格，不重做弹窗，仅在原组件中扩展状态与动作。
- “立即更新”改为应用内下载主路径。
- “备用下载”始终保留为浏览器回退方案。
- 强制更新场景下对话框仍然不可关闭。

### 下载状态机

```text
idle -> downloading -> downloaded -> install_attempt
  |        |              |               |
  |        |              |               -> install_error (仍保留已下载文件)
  |        -> download_error
  -> browser_fallback
```

对应 UI 约束：

- `idle`：显示“立即更新” + “备用下载” + “暂不更新（非强更）”
- `downloading`：显示进度条、百分比、已下载大小、“取消下载”
- `downloaded`：显示“立即安装”，必要时显示安装失败提示，但不能丢失已下载文件
- `download_error`：显示中文错误信息、“重试”、“浏览器下载”，如有备用地址则显示“备用下载”

### 服务层行为

- `UpdateService.downloadUpdate()` 负责：
  - 从平台下载 URL 推导文件名并保留原始后缀
  - 使用临时目录保存安装包
  - 显式设置下载超时，避免无限挂起
  - 通过回调上报进度
  - 取消下载或下载失败时清理临时文件
- `UpdateService.installUpdate()` 负责：
  - Android：调用 `open_filex` 打开 APK，触发系统安装流程
  - Windows：调用 `Process.start()` 运行 EXE；只有安装器成功拉起后才允许 `exit(0)`
  - 向 UI 返回可判定的安装结果，不能只打印日志

### 平台与异常处理

- Android 安装权限被拒或系统拒绝打开 APK 时，UI 需显示中文引导，提示用户开启未知来源安装/安装应用权限后重试。
- Windows 安装器启动失败时，UI 需展示错误并保留当前弹窗，不能直接退出应用。
- 下载超时、断网、HTTP 错误、磁盘写入失败、用户取消下载，都要落到可恢复状态。
- 不向用户暴露原始异常栈；只展示友好的中文提示。
- 开发期日志使用 `debugPrint()`；不记录用户隐私内容。

## Acceptance Criteria

- [ ] Android：点击“立即更新”后开始应用内下载，并显示实时进度与百分比
- [ ] Windows：点击“立即更新”后开始应用内下载，并显示实时进度与百分比
- [ ] 取消下载后回到 `idle` 状态，且临时文件被清理
- [ ] 下载失败时显示中文错误信息，并可“重试”或“浏览器下载”
- [ ] 下载完成后显示“立即安装”，无需重新下载
- [ ] Android：安装权限被拒或系统无法打开 APK 时，显示明确引导，且保留再次安装能力
- [ ] Windows：仅在安装器成功启动后才退出当前应用；启动失败时不退出并展示错误
- [ ] “备用下载”按钮在可用场景下始终保留，现有浏览器回退行为不变
- [ ] 强制更新场景下对话框不可关闭，原有强更约束不被破坏
- [ ] 进度条与弹窗整体样式继续保持拟物化主题一致性

## Definition of Done

- `dart analyze lib/services/update_service.dart lib/widgets/update_dialog.dart` 通过
- Android 和 Windows 至少各完成一次手工冒烟验证
- 下载失败、取消、安装失败三类恢复路径都被实际走通或通过日志/代码路径核对
- 服务层未引入同步 I/O、`print()`、未处理异常直冲 UI 的问题

## Technical Approach

- 继续使用 `UpdateDialog` 的本地状态管理，不引入 Provider 或额外全局状态。
- 在 `UpdateService` 内补充安装结果结构化返回值，用于区分：
  - 安装器已成功拉起
  - 权限被拒 / 系统拒绝
  - 平台不支持
  - 通用失败
- 下载错误继续通过 `DioException` 向 UI 暴露细节，UI 统一映射为中文提示。
- 安装失败不应清空 `_downloadedPath`；用户修复权限后应可直接再次点击“立即安装”。

## Decision (ADR-lite)

**Context**：当前实现能下载和调用安装，但安装阶段只写 `debugPrint()`，UI 无法区分“权限问题”“系统拒绝”“真正失败”，同时下载链路未设置显式超时。  
**Decision**：保留现有弹窗状态机和浏览器回退路径，在服务层新增结构化安装结果，并补齐下载超时与失败清理。  
**Consequences**：服务层 API 会比原 PRD 多一个“安装结果”契约，但 UI 能稳定处理 Android 权限提示和 Windows 启动失败，不需要通过字符串解析日志判断状态。

## Out of Scope

- 后台下载 / 通知栏下载
- 断点续传
- 安装包校验和 / 数字签名校验
- iOS / macOS 的安装流程支持
- 更新埋点与分析事件扩展

## Implementation Plan

- PR1：收紧 `UpdateService` 契约，补齐下载超时、失败清理、安装结果返回
- PR2：调整 `UpdateDialog` 状态与错误文案，覆盖下载失败和安装失败两类恢复路径
- PR3：做 Android / Windows 冒烟验证，整理剩余边界问题并收尾

## Technical Notes

### 相关文件

- `paper_whisper_flutter/lib/services/update_service.dart`
- `paper_whisper_flutter/lib/widgets/update_dialog.dart`
- `paper_whisper_flutter/pubspec.yaml`
- `paper_whisper_flutter/android/app/src/main/AndroidManifest.xml`

### 相关规范

- `.trellis/spec/backend/error-handling.md`
- `.trellis/spec/backend/logging-guidelines.md`
- `.trellis/spec/backend/quality-guidelines.md`
- `.trellis/spec/frontend/component-guidelines.md`
- `.trellis/spec/frontend/quality-guidelines.md`

### 已确认风险

- Android 安装权限问题必须通过结构化结果回传给 UI，不能只靠日志
- Windows 不能在 `Process.start()` 失败时直接 `exit(0)`
- 安装失败后应允许直接重试安装，而不是逼用户重新下载
