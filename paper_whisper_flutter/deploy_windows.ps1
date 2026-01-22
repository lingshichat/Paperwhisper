# PowerShell 脚本: Windows 自动构建发布
$ErrorActionPreference = "Stop"

# --- 🛠️ 配置区域 (与 deploy.sh 保持一致) ---
$BucketName = "paper-whisper-releases"
$R2Remote = "cfr2"
$Domain = "https://dl.lingshichat.top"
# ----------------------------------------


Write-Host "🔄 [1/5] 正在从 version.json 同步版本号..." -ForegroundColor Cyan
dart run tool/sync_version.dart

Write-Host "🚀 [2/5] 开始构建 Release 版 Windows 应用..." -ForegroundColor Cyan
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
$ExeName = "PaperWhisper_Setup_$Version.exe"

$BuildDir = "build\windows\x64\runner\Release"
$ReleasesDir = "..\releases\builds"

# 确保输出目录存在
if (-not (Test-Path $ReleasesDir)) {
    New-Item -ItemType Directory -Path $ReleasesDir -Force | Out-Null
}

$ZipPath = Join-Path $ReleasesDir $ZipName

Write-Host "📦 [3/5] 正在根据版本 $Version 打包绿色版 (Zip)..." -ForegroundColor Cyan

if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}

# 压缩 Release 文件夹内容到 Zip
Compress-Archive -Path "$BuildDir\*" -DestinationPath $ZipPath -Force

Write-Host "💿 [4/5] 正在编译 Inno Setup 安装包..." -ForegroundColor Cyan
$ISCC = "ISCC.exe" # 假设已添加到环境变量
$IssFile = "installers\paper_whisper.iss"

# 检查 ISCC 是否可用
$ISCCPath = "ISCC.exe"
if (-not (Get-Command $ISCCPath -ErrorAction SilentlyContinue)) {
    # 尝试常用路径 (Fallback)
    $FallbackPath = "D:\Softwares\Inno Setup 6\ISCC.exe"
    if (Test-Path $FallbackPath) {
        $ISCCPath = $FallbackPath
        Write-Host "⚠️ PATH 中未找到 ISCC，使用硬编码路径: $ISCCPath" -ForegroundColor Yellow
    }
    else {
        Write-Warning "⚠️ 未找到 ISCC.exe，跳过安装包生成！请确保 Inno Setup 已安装并添加到 PATH。"
        $ISCCPath = $null
    }
}

if ($ISCCPath) {
    & $ISCCPath "/DMyAppVersion=$Version" $IssFile | Out-Null
}



Write-Host "☁️ [5/5] 正在上传构建产物到 R2..." -ForegroundColor Cyan

# 1. 上传存档版 (Zip)
rclone copy "$ZipPath" "$R2Remote`:$BucketName/Windows/" --progress

$ExePath = Join-Path $ReleasesDir $ExeName
# 给予文件系统一点缓冲时间，并显式检查
Start-Sleep -Seconds 1

Write-Host "🔎 正在检查安装包: $ExePath" -ForegroundColor Gray

if (Test-Path $ExePath) {
    Write-Host "✅ 找到安装包，准备上传..." -ForegroundColor Green
    
    # 3. 上传最新安装包 (Exe) -> 重命名为 latest.exe
    Write-Host "☁️ [5.1/5] 上传最新安装包: latest.exe" -ForegroundColor Cyan
    rclone copyto "$ExePath" "$R2Remote`:$BucketName/Windows/latest.exe" --progress
}
else {
    Write-Error "❌ 未找到安装包文件: $ExePath"
}

Write-Host "✅ 发布成功！" -ForegroundColor Green
Write-Host "⬇️ 最新版 (Exe): $Domain/Windows/latest.exe"
Write-Host "📦 历史存档: $Domain/Windows/$ZipName"
Write-Host ""
Write-Host "🔔 别忘了手动把 Zip/Exe 拖到网盘备份文件夹哦！" -ForegroundColor Yellow

