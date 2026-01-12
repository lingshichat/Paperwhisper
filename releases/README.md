# Releases 文件夹

此文件夹用于存放发布相关文件：

- `version.json` - 版本配置文件（上传到 R2）
- `builds/` - 打包后的安装包

## 使用说明

1. 发布新版本时，更新 `version.json` 中的版本号和更新日志
2. 将 `version.json` 上传到 `https://dl.lingshichat.top/version.json`
3. 将打包的 APK/EXE 文件重命名为 `latest.apk` / `latest.exe` 并上传到 R2
