# Release Guidelines

## 1. Scope And Trigger

本规范适用于 `scripts/release.ps1`、版本元数据、Windows/Android 发布产物、Git tag、GitHub Release 和 R2/S3 客户端更新通道。修改其中任一环节前，必须同时检查客户端读取的 `releases/version.json` 契约和完整发布顺序。

正式发布的唯一实现入口是仓库根目录的 `scripts/release.ps1`。历史部署脚本只能作为无业务逻辑的兼容转发器。

## 2. Signatures

```powershell
.\scripts\release.ps1 [-Platform all|windows|android] [-Preview] [-BaseTag vX.Y.Z] [-SkipBuild] [-SkipChecks] [-SkipGitHub] [-SkipR2] [-PreRelease] [-Draft] [-Resume]
```

- `-Preview`：只读取本地 Git 历史并输出草稿，不修改文件或远端状态。
- `-BaseTag`：只覆盖更新日志的提交基线，不改变当前清单版本的递增基线。
- `-Resume`：从已存在的版本提交、tag、GitHub draft 和版本化产物继续；不得改写已经推送的历史。
- 编辑器按 `$env:VISUAL`、`$env:EDITOR`、`notepad.exe` 的顺序选择。
- Inno Setup 可由 `ISCC_PATH` 显式指定，否则从 `PATH` 和标准安装位置解析。
- 稳定客户端发布必须提供 `BITIFUL_API_TOKEN`，用于调用 Bitiful CDN 刷新 API。

`releases/version.json` 是版本元数据的唯一源，必须保留以下字段和类型：

```json
{
  "latestVersion": "MAJOR.MINOR.PATCH",
  "latestBuildNumber": 1,
  "releaseDate": "YYYY-MM-DD",
  "title": "string",
  "isForceUpdate": false,
  "changelog": ["string"],
  "downloadUrl": { "android": "https://...", "windows": "https://..." },
  "backupUrl": { "android": "https://...", "windows": "https://..." },
  "minSupportedVersion": "MAJOR.MINOR.PATCH"
}
```

## 3. Contracts

1. 默认更新日志范围是最新可达语义版本 tag `vMAJOR.MINOR.PATCH..HEAD`；只将用户可感知的提交纳入草稿。
2. `feat`、`fix`、`perf` 分组展示；`docs`、`test`、`chore`、`style`、`ci`、`build`、`refactor`、工具链和 Trellis 维护提交默认过滤。
3. 草稿条目必须改写成普通用户能理解的中文，描述可感知的变化和收益，避免框架版本、依赖、重构、内部模块名等实现术语。
4. 发布者可反复编辑草稿。只有逐字输入 `RELEASE vX.Y.Z` 才能进入有副作用阶段。
5. 正式稳定版使用共享客户端清单，因此必须同时发布 Windows 和 Android；单平台只适用于不切换客户端通道的场景。
6. 三份版本状态必须一致：`releases/version.json`、`paper_whisper_flutter/assets/version.json`、`paper_whisper_flutter/pubspec.yaml`。
7. 正常发布必须从干净的 `main` 执行，且本地 HEAD 与 `origin/main` 一致。恢复模式仅允许 HEAD 比远端多一个匹配的 `chore(release): vX.Y.Z` 提交。
8. 稳定版顺序固定为：版本化产物 -> GitHub draft 资产 -> R2/S3 版本化产物 -> `latest.exe`/`latest.apk` -> `version.json` -> 刷新并验证 Bitiful CDN -> 公开 GitHub Release。
9. `version.json` 必须最后上传。它是客户端发现新版本的提交点，上传前所有下载目标必须可用；上传后必须刷新 `version.json`、`latest.exe` 和 `latest.apk` 的 CDN 缓存，并确认线上清单版本正确。
10. `-PreRelease` 和 `-Draft` 不得更新 `latest` 或客户端 `version.json`；`-SkipR2` 也不得声称客户端通道已经发布。
11. 原生命令的非零退出码必须终止流程。日志不得输出 Android keystore 密码、GitHub token 或 R2 凭据。

## 4. Validation And Error Matrix

| 场景 | 必须验证 | 失败行为 |
|---|---|---|
| 草稿生成 | 基线 tag 可达、存在可发布条目 | 停止并要求显式调整基线或提交内容 |
| 进入正式发布 | 分支、工作区、远端同步、精确确认短语 | 不修改版本文件和远端 |
| 版本同步 | 三份版本状态完全一致 | 恢复版本文件并停止 |
| 质量检查 | `pub get --enforce-lockfile`、analyze、test | 停止；只有显式 `-SkipChecks` 可跳过 |
| 构建 | Windows ZIP/EXE 和 Android APK 为本次版本化非空文件 | 停止；不得复用模糊名称或旧文件 |
| GitHub 恢复 | 同版本 Release 仍为 draft，prerelease 状态匹配 | 拒绝覆盖已公开或状态冲突的 Release |
| R2/S3 发布 | 版本化文件先成功，客户端清单最后成功 | 保留可恢复状态，使用 `-Resume` 继续 |
| CDN 刷新 | API 返回 `message=ok`，线上清单返回目标版本 | 保持 GitHub draft，使用 `-Resume` 重试 |
| 版本提交后失败 | 当前提交/tag 与目标版本一致 | 不 reset、不删除远端 tag，提示恢复命令 |

## 5. Good, Base, And Bad Examples

**Good**

```powershell
.\scripts\release.ps1 -Preview
.\scripts\release.ps1
.\scripts\release.ps1 -Resume -SkipBuild
```

先预览并修改草稿，正式流程完整构建两个平台，失败后复用精确的版本化产物恢复。

**Base**

```powershell
.\scripts\release.ps1 -PreRelease
```

可以创建 GitHub prerelease，但不得切换客户端稳定通道。

**Bad**

```powershell
.\scripts\release.ps1 -Platform windows
rclone copy releases/version.json bitiful:paperwhisper/
```

只生成单平台产物却手动切换共享清单，会让另一平台看到不存在或过期的下载目标。

## 6. Tests Required

修改发布逻辑后至少执行：

```powershell
pwsh -NoProfile -File scripts/release.tests.ps1
pwsh -NoProfile -File scripts/release.ps1 -Preview
flutter analyze
flutter test
```

还必须用 PowerShell AST 解析所有 PowerShell 入口，用 `bash -n` 检查 shell 兼容入口。涉及构建路径、Inno 配置或 Android 配置时，需分别完成 Windows Release、Inno Setup 和 Android Release 的本地构建验证。测试不得执行真实上传、push、tag 或 Release 发布。

## 7. Wrong Vs Correct

| Wrong | Correct |
|---|---|
| 从 `git log` 直接拼一段不可编辑文本 | 生成分组 Markdown，允许编辑，再转成客户端 changelog |
| 用工作区中任意 APK/EXE 作为发布资产 | 只接受目标版本的确定文件名，并在构建前删除同名旧产物 |
| 先上传 `version.json` 再上传安装包 | 先验证并上传全部安装包，最后上传 `version.json`，刷新并验证 CDN |
| 发布失败后 `reset --hard` 或强制推 tag | 保留已发布状态，用 `-Resume` 幂等继续 |
| 在脚本中硬编码错误的 GitHub 仓库名 | 从 `origin` URL 解析并校验 `OWNER/REPO` |
| 兼容脚本复制一套发布逻辑 | 兼容脚本只转发到根发布入口 |
