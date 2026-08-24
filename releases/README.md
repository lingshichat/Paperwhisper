# PaperWhisper 发布流程

`scripts/release.ps1` 是唯一实现发布逻辑的入口。旧的 `paper_whisper_flutter/deploy.sh`、`paper_whisper_flutter/scripts/deploy.ps1` 和 `paper_whisper_flutter/scripts/deploy_windows.ps1` 仅作为兼容命令，统一转发到完整的双平台发布流程。

## 前置条件

- PowerShell 7
- Flutter 和 Dart
- GitHub CLI，已通过 `gh auth login` 登录
- rclone，已配置名为 `bitiful` 的 remote
- 环境变量 `BITIFUL_API_TOKEN`，用于刷新稳定通道的 Bitiful CDN 缓存
- Windows 构建需要 Inno Setup 6 的 `ISCC.exe` 位于 `PATH`，或设置 `ISCC_PATH`
- Android 构建需要本机 `android/key.properties` 和对应 keystore
- 从 `main` 运行，工作区必须干净，且本地 HEAD 必须与 `origin/main` 一致

## 预览更新日志

```powershell
.\scripts\release.ps1 -Preview
```

预览模式只读取本地 Git 历史。脚本默认从最新的 `vMAJOR.MINOR.PATCH` 标签读取到 `HEAD`，过滤发布工程、依赖和重构等内部提交，再按 Conventional Commit 生成以下分组：

- `feat`：新增功能
- `fix`：问题修复
- `perf`：性能优化
- 非 Conventional Commit：其他更新

`docs`、`test`、`chore`、`style`、`ci`、`build`、`refactor`、工具链和 Trellis 维护提交默认不进入草稿。草稿仍需在确认环节改写成普通用户能理解的中文，说明可感知的变化和收益，避免直接发布内部模块名与实现术语。

## 正式发布

```powershell
.\scripts\release.ps1
```

脚本依次执行：

1. 获取最新 tag 和提交历史，给出下一语义版本建议。
2. 交互填写版本、build number、标题、日期和强制更新开关。
3. 显示 Markdown 更新日志；输入 `E` 后使用 `$env:VISUAL`、`$env:EDITOR` 或 `notepad.exe` 修改。
4. 显示最终摘要。只有输入 `RELEASE vX.Y.Z` 才继续。
5. 同步 `releases/version.json`、`pubspec.yaml` 和内置 `assets/version.json`。
6. 执行 `flutter pub get`、`flutter analyze`、`flutter test`。
7. 重新构建版本化 Windows ZIP/EXE 和 Android APK。
8. 创建 `chore(release): vX.Y.Z` 提交并推送 `main`，创建并推送 tag。
9. 创建 GitHub draft，上传版本化产物。
10. 上传 R2/S3 版本化产物，再切换 `latest.exe` / `latest.apk`。
11. 最后上传根目录 `version.json`。
12. 调用 Bitiful CDN API 刷新 `version.json`、`latest.exe` 和 `latest.apk`，并轮询确认客户端已看到新版本。
13. 公开 GitHub Release。

不再需要手动上传 `version.json`、APK、EXE 或 ZIP。

## 常用参数

| 参数 | 行为 |
|---|---|
| `-Platform all\|windows\|android` | 选择构建平台；发布客户端稳定版时必须使用 `all` |
| `-Preview` | 仅输出本地更新日志草稿 |
| `-BaseTag vX.Y.Z` | 显式指定提交历史基线 |
| `-PreRelease` | 发布 GitHub prerelease；不切换 `latest` 或客户端清单 |
| `-Draft` | GitHub Release 保持草稿；可上传版本化备份，但不切换客户端通道 |
| `-SkipBuild` | 显式复用 `releases/builds` 中完整的版本化产物 |
| `-SkipChecks` | 跳过 Flutter 检查；最终确认会显示警告 |
| `-SkipGitHub` | 仅发布 Git/R2 通道 |
| `-SkipR2` | 仅发布 Git/GitHub 通道，客户端不会收到更新 |
| `-Resume` | 复用当前版本提交、tag、GitHub draft 和远端版本化文件继续失败的发布 |

## 失败恢复

首次 Git 提交前失败时，脚本会恢复三个版本文件。构建产物保留在 `releases/builds`，便于检查。

版本提交或 tag 已推送后失败时，不会自动重写历史。确认失败原因已经修复后运行：

```powershell
.\scripts\release.ps1 -Resume -SkipBuild
```

上传命令使用确定的版本化路径并允许覆盖同版本 draft 资产，因此恢复过程是幂等的。已经公开的同版本 GitHub Release 不会被覆盖；这种情况必须提升版本重新发布。

## 发布产物

```text
releases/builds/
├── PaperWhisper_Setup_X.Y.Z.exe
├── paper_whisper_flutter_windows_X.Y.Z.zip
└── paper_whisper_flutter_android_X.Y.Z.apk
```

R2/S3 稳定通道：

- `Windows/latest.exe`
- `Android/latest.apk`
- `version.json`

`version.json` 始终最后上传，随后必须刷新并验证 CDN 缓存，避免客户端发现新版本时安装包尚未就绪，或继续读取旧清单。

缓存刷新接口遵循 [Bitiful S4 静态 CDN API](https://docs.bitiful.com/developer/api/cdn)，Token 只从 `BITIFUL_API_TOKEN` 读取，不写入文件或日志。
