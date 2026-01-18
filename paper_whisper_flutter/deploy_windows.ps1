# PowerShell 脚本: Windows 自动构建发布
$ErrorActionPreference = "Stop"

# --- 🛠️ 配置区域 (与 deploy.sh 保持一致) ---
$BucketName = "paper-whisper-releases"
$R2Remote = "cfr2"
$Domain = "https://dl.lingshichat.top"
# ----------------------------------------

Write-Host "🔄 [0/4] 正在从 version.json 同步版本号..." -ForegroundColor Cyan
dart run tool/sync_version.dart

Write-Host "🚀 [1/4] 开始构建 Release 版 Windows 应用..." -ForegroundColor Cyan
flutter build windows --release

# 获取版本号 (从 pubspec.yaml 读取)
$PubspecContent = Get-Content -Path "pubspec.yaml" -Raw
if ($PubspecContent -match '(?m)^version:\s+([^\s+]+)') {
    $Version = $matches[1]
}
else {
    Write-Error "❌ 无法从 pubspec.yaml 提取版本号！"
}

$ZipName = "paper_whisper_flutter_windows_$Version.zip"
$BuildDir = "build\windows\x64\runner\Release"
$ReleasesDir = "..\releases\builds"

# 确保输出目录存在
if (-not (Test-Path $ReleasesDir)) {
    New-Item -ItemType Directory -Path $ReleasesDir -Force | Out-Null
}

$ZipPath = Join-Path $ReleasesDir $ZipName

Write-Host "📦 [2/4] 正在根据版本 $Version 打包..." -ForegroundColor Cyan

if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}

# 压缩 Release 文件夹内容到 Zip
Compress-Archive -Path "$BuildDir\*" -DestinationPath $ZipPath -Force

Write-Host "☁️ [3/4] 正在上传 $ZipName 到 R2..." -ForegroundColor Cyan

# 1. 上传存档版
rclone copy "$ZipPath" "$R2Remote`:$BucketName/Windows/" --progress

# 2. 上传最新版 (重命名为 latest.zip)
rclone copyto "$ZipPath" "$R2Remote`:$BucketName/Windows/latest.zip" --progress

Write-Host "✅ [4/4] 发布成功！" -ForegroundColor Green
Write-Host "⬇️ 最新版: $Domain/Windows/latest.zip"
Write-Host "📦 历史存档: $Domain/Windows/$ZipName"
Write-Host ""
Write-Host "🔔 别忘了手动把 Zip 拖到百度网盘备份文件夹哦！" -ForegroundColor Yellow
