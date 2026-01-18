$ErrorActionPreference = "Stop"

# --- 🛠️ 配置区域 ---
$BUCKET_NAME = "paper-whisper-releases"
$R2_REMOTE = "cfr2"
$DOMAIN = "https://dl.lingshichat.top"
# --------------------

# 0. 同步版本号
Write-Host "🔄 [Sync] 正在从 version.json 同步版本号..." -ForegroundColor Cyan
dart run tool/sync_version.dart

# 1. 自动获取版本号
$pubspec = Get-Content pubspec.yaml
$versionLine = $pubspec | Where-Object { $_ -match "^version:" }
if ($versionLine) {
    $VERSION = $versionLine.ToString().Trim().Split(' ')[1].Split('+')[0]
} else {
    Write-Error "无法在 pubspec.yaml 中找到版本号"
}

Write-Host "📌 当前版本: v$VERSION" -ForegroundColor Green

# ==========================================
# 🤖 第一部分：Android 打包与上传
# ==========================================
Write-Host "--------------------------------------"
Write-Host "🚀 [Android] 开始构建 APK..." -ForegroundColor Cyan
flutter build apk --release

$APK_PATH = "build\app\outputs\flutter-apk\app-release.apk"
$APK_NAME = "paper_whisper_flutter_android_$VERSION.apk"

if (Test-Path $APK_PATH) {
    Write-Host "☁️ [Android] 正在上传 $APK_NAME..." -ForegroundColor Yellow
    rclone copyto "$APK_PATH" "$R2_REMOTE`:$BUCKET_NAME/Android/$APK_NAME" --progress
    rclone copyto "$APK_PATH" "$R2_REMOTE`:$BUCKET_NAME/Android/latest.apk" --progress
} else {
    Write-Error "APK 构建失败或找不到文件: $APK_PATH"
}

# ==========================================
# 🎉 总结
# ==========================================
Write-Host "--------------------------------------"
Write-Host "🎉 Android 发布任务完成！" -ForegroundColor Green
Write-Host "⬇️ Android 最新版: $DOMAIN/Android/latest.apk"
Write-Host "📦 历史存档: $DOMAIN/Android/$APK_NAME"
Write-Host ""
Write-Host "🔔 别忘了手动把 APK 拖到网盘备份文件夹哦！" -ForegroundColor Magenta
