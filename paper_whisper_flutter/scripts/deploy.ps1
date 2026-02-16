$ErrorActionPreference = "Stop"

# --- 🛠️ 配置区域 ---
$BUCKET_NAME = "paperwhisper"
$R2_REMOTE = "bitiful"
$DOMAIN = "https://paperwhisper.s3.bitiful.net"
# --------------------

# 设置工作目录为 Flutter 项目根目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Join-Path $ScriptDir ".."
Set-Location $ProjectRoot

# 0. 同步版本号
Write-Host "🔄 [Sync] 正在从 version.json 同步版本号..." -ForegroundColor Cyan
dart run tool/sync_version.dart

# 1. 自动获取版本号
$pubspec = Get-Content pubspec.yaml
$versionLine = $pubspec | Where-Object { $_ -match "^version:" }
if ($versionLine) {
    $VERSION = $versionLine.ToString().Trim().Split(' ')[1].Split('+')[0]
}
else {
    Write-Error "无法在 pubspec.yaml 中找到版本号"
}

Write-Host "📌 当前版本: v$VERSION" -ForegroundColor Green

# ==========================================
# 🤖 第一部分：Android 打包与上传
# ==========================================
Write-Host "--------------------------------------"
Write-Host "🚀 [Android] 开始构建 APK..." -ForegroundColor Cyan
flutter build apk --release --target-platform android-arm64

$APK_PATH = "build\app\outputs\flutter-apk\app-release.apk"
$APK_NAME = "paper_whisper_flutter_android_$VERSION.apk"

if (Test-Path $APK_PATH) {
    Write-Host "☁️ [Android] 正在上传 $APK_NAME..." -ForegroundColor Yellow
    rclone copyto "$APK_PATH" "$R2_REMOTE`:$BUCKET_NAME/Android/$APK_NAME" --progress
    rclone copyto "$APK_PATH" "$R2_REMOTE`:$BUCKET_NAME/Android/latest.apk" --progress
}
else {
    Write-Error "APK 构建失败或找不到文件: $APK_PATH"
}

# ==========================================
# 🎉 总结
# ==========================================
Write-Host "--------------------------------------"
Write-Host "🎉 Android 发布任务完成！" -ForegroundColor Green
Write-Host "⬇️ Android 最新版: $DOMAIN/Android/latest.apk"
Write-Host "📦 历史存档: $DOMAIN/Android/$APK_NAME"
