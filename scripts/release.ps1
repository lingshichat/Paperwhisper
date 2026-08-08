#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    纸语 PaperWhisper 统一发布脚本
    支持 Windows 和 Android 双平台构建，并自动上传到 GitHub Release 和 R2/S3

.DESCRIPTION
    该脚本整合了原有的 deploy.ps1 和 deploy_windows.ps1，提供统一的发布入口。
    自动处理版本同步、构建、打包、上传到 GitHub Release 和 R2/S3 分发的完整流程。

.PARAMETER Platform
    要构建的平台: all (默认), windows, android

.PARAMETER SkipBuild
    跳过构建步骤，仅上传现有构建产物到 GitHub Release

.PARAMETER SkipR2
    跳过 R2/S3 上传（仅上传到 GitHub Release）

.PARAMETER SkipGitHub
    跳过 GitHub Release 上传（仅上传到 R2/S3）

.PARAMETER PreRelease
    标记为预发布版本 (prerelease)

.PARAMETER Draft
    创建为草稿 Release

.EXAMPLE
    .\scripts\release.ps1
    # 构建所有平台并发布

.EXAMPLE
    .\scripts\release.ps1 -Platform windows
    # 仅构建 Windows 平台

.EXAMPLE
    .\scripts\release.ps1 -SkipBuild -Platform android
    # 跳过构建，仅上传 Android 产物到 GitHub Release

.NOTES
    前置要求:
    - Flutter SDK 已安装并配置
    - GitHub CLI (gh) 已安装并登录 (运行: gh auth login)
    - rclone 已配置 (用于 R2/S3 上传)
    - Inno Setup 已安装 (用于 Windows 安装包)
    
    快速开始:
    1. 确保已安装 gh CLI: winget install --id GitHub.cli
    2. 登录 GitHub: gh auth login
    3. 修改脚本中的 $Config.RepoOwner 为你的 GitHub 用户名
    4. 运行: .\scripts\release.ps1
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("all", "windows", "android")]
    [string]$Platform = "all",

    [Parameter()]
    [switch]$SkipBuild,

    [Parameter()]
    [switch]$SkipR2,

    [Parameter()]
    [switch]$SkipGitHub,

    [Parameter()]
    [switch]$PreRelease,

    [Parameter()]
    [switch]$Draft
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# ==========================================
# 🛠️ 配置区域
# ==========================================
$Config = @{
    # R2/S3 配置 (用于分发)
    BucketName = "paperwhisper"
    R2Remote   = "bitiful"
    Domain     = "https://pwdl.lingshichat.cn"

    # 路径配置
    FlutterProjectDir = "paper_whisper_flutter"
    ReleasesDir       = "releases\builds"
    VersionFile       = "releases\version.json"

    # GitHub 配置 - 请根据实际情况修改
    RepoOwner = "lings03"  # <-- 修改为你的 GitHub 用户名
    RepoName  = "paperwhisper"
}

# ==========================================
# 📁 初始化路径
# ==========================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$FlutterProjectPath = Join-Path $ProjectRoot $Config.FlutterProjectDir
$ReleasesPath = Join-Path $ProjectRoot $Config.ReleasesDir

# 确保 releases/builds 目录存在
if (-not (Test-Path $ReleasesPath)) {
    New-Item -ItemType Directory -Path $ReleasesPath -Force | Out-Null
}

Set-Location $FlutterProjectPath

# ==========================================
# 🎨 颜色输出函数
# ==========================================
function Write-Info($Message) {
    Write-Host $Message -ForegroundColor Cyan
}

function Write-Success($Message) {
    Write-Host $Message -ForegroundColor Green
}

function Write-Warn($Message) {
    Write-Host $Message -ForegroundColor Yellow
}

function Write-ErrorColored($Message) {
    Write-Host $Message -ForegroundColor Red
}

function Write-Section($Title) {
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "  $Title" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
}

# ==========================================
# 🔍 前置检查
# ==========================================
function Test-Prerequisites {
    Write-Section "前置检查"

    # 检查 Flutter
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw "❌ Flutter 未安装或未添加到 PATH"
    }
    Write-Success "✅ Flutter 已安装"

    # 检查 gh CLI (如果不上传 GitHub 可以跳过)
    if (-not $SkipGitHub) {
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
            throw "❌ GitHub CLI (gh) 未安装。请访问 https://cli.github.com/ 安装"
        }

        # 检查 gh 是否已登录
        $ghAuth = gh auth status 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "❌ GitHub CLI 未登录。请运行: gh auth login"
        }
        Write-Success "✅ GitHub CLI 已配置"
    }

    # 检查 rclone (如果不上传 R2 可以跳过)
    if (-not $SkipR2) {
        if (-not (Get-Command rclone -ErrorAction SilentlyContinue)) {
            throw "❌ rclone 未安装。请访问 https://rclone.org/ 安装"
        }
        Write-Success "✅ rclone 已安装"
    }

    # 检查 version.json
    $versionFilePath = Join-Path $ProjectRoot $Config.VersionFile
    if (-not (Test-Path $versionFilePath)) {
        throw "❌ 找不到版本文件: $versionFilePath"
    }
    Write-Success "✅ 版本文件存在"
}

# ==========================================
# 📋 读取版本信息
# ==========================================
function Get-VersionInfo {
    $versionFilePath = Join-Path $ProjectRoot $Config.VersionFile
    $versionData = Get-Content $versionFilePath -Raw | ConvertFrom-Json

    return @{
        Version      = $versionData.latestVersion
        BuildNumber  = $versionData.latestBuildNumber
        Title        = $versionData.title
        Changelog    = $versionData.changelog
        ReleaseDate  = $versionData.releaseDate
        IsForceUpdate = $versionData.isForceUpdate
    }
}

# ==========================================
# 🔄 同步版本号
# ==========================================
function Sync-Version {
    Write-Info "🔄 正在从 version.json 同步版本号..."

    # 运行 Dart 同步脚本
    dart run tool/sync_version.dart

    if ($LASTEXITCODE -ne 0) {
        throw "❌ 版本同步失败"
    }

    Write-Success "✅ 版本号同步完成"
}

# ==========================================
# 🪟 构建 Windows
# ==========================================
function Build-Windows {
    param([hashtable]$VersionInfo)

    Write-Section "Windows 构建"

    $Version = $VersionInfo.Version
    $ZipName = "paper_whisper_flutter_windows_$Version.zip"
    $ExeName = "PaperWhisper_Setup_$Version.exe"

    $BuildDir = "build\windows\x64\runner\Release"
    $ZipPath = Join-Path $ReleasesPath $ZipName
    $ExePath = Join-Path $ReleasesPath $ExeName

    $result = [PSCustomObject]@{
        ZipPath = $ZipPath
        ExePath = $null
    }

    # 1. 构建 Flutter
    if (-not $SkipBuild) {
        Write-Info "🚀 开始构建 Windows Release 版本..."
        flutter build windows --release

        if ($LASTEXITCODE -ne 0) {
            throw "❌ Windows 构建失败"
        }
        Write-Success "✅ Windows 构建完成"

        # 2. 打包 Zip
        Write-Info "📦 正在打包绿色版 (Zip)..."
        if (Test-Path $ZipPath) {
            Remove-Item $ZipPath -Force
        }
        Compress-Archive -Path "$BuildDir\*" -DestinationPath $ZipPath -Force
        Write-Success "✅ Zip 打包完成: $ZipPath"

        # 3. 编译 Inno Setup 安装包
        Write-Info "💿 正在编译安装包 (Inno Setup)..."

        $ISCCPath = "ISCC.exe"
        $isccFound = $false
        
        if (Get-Command $ISCCPath -ErrorAction SilentlyContinue) {
            $isccFound = $true
        }
        else {
            # 尝试常用路径
            $FallbackPath = "D:\Softwares\Inno Setup 6\ISCC.exe"
            if (Test-Path $FallbackPath) {
                $ISCCPath = $FallbackPath
                $isccFound = $true
                Write-Warn "⚠️ PATH 中未找到 ISCC，使用硬编码路径: $ISCCPath"
            }
        }

        if ($isccFound) {
            & $ISCCPath "/DMyAppVersion=$Version" "installers\paper_whisper.iss" 2>&1 | Out-Null

            # 等待文件生成并检查
            Start-Sleep -Seconds 2
            if (Test-Path $ExePath) {
                Write-Success "✅ 安装包生成完成: $ExePath"
            }
            else {
                Write-Warn "⚠️ 安装包可能未生成: $ExePath"
            }
        }
        else {
            Write-Warn "⚠️ 未找到 ISCC.exe，跳过安装包生成！"
        }
    }
    else {
        Write-Info "⏭️ 跳过构建，使用现有产物"
    }

    # 更新结果对象
    $result.ZipPath = $ZipPath
    $result.ExePath = if (Test-Path $ExePath) { $ExePath } else { $null }

    return $result
}

# ==========================================
# 🤖 构建 Android
# ==========================================
function Build-Android {
    param([hashtable]$VersionInfo)

    Write-Section "Android 构建"

    $Version = $VersionInfo.Version
    $ApkName = "paper_whisper_flutter_android_$Version.apk"
    $ApkPath = "build\app\outputs\flutter-apk\app-release.apk"

    if (-not $SkipBuild) {
        Write-Info "🚀 开始构建 Android APK..."
        flutter build apk --release --target-platform android-arm64

        if ($LASTEXITCODE -ne 0) {
            throw "❌ Android 构建失败"
        }
        Write-Success "✅ Android 构建完成"
    }
    else {
        Write-Info "⏭️ 跳过构建，使用现有 APK"
    }

    # 检查 APK 是否存在
    if (-not (Test-Path $ApkPath)) {
        throw "❌ 找不到 APK 文件: $ApkPath"
    }

    return [PSCustomObject]@{
        ApkPath = $ApkPath
        ApkName = $ApkName
    }
}

# ==========================================
# ☁️ 上传到 R2/S3
# ==========================================
function Upload-ToR2 {
    param(
        [PSCustomObject]$WindowsArtifacts,
        [PSCustomObject]$AndroidArtifacts,
        [hashtable]$VersionInfo
    )

    Write-Section "上传到 R2/S3 分发"

    $Version = $VersionInfo.Version

    # 上传 Windows 产物
    if ($WindowsArtifacts -and $WindowsArtifacts.ZipPath -and (Test-Path $WindowsArtifacts.ZipPath)) {
        Write-Info "☁️ 上传 Windows Zip 存档..."
        rclone copy "$($WindowsArtifacts.ZipPath)" "$($Config.R2Remote):$($Config.BucketName)/Windows/" --progress
        Write-Success "✅ Windows Zip 上传完成"
    }

    if ($WindowsArtifacts -and $WindowsArtifacts.ExePath -and (Test-Path $WindowsArtifacts.ExePath)) {
        Write-Info "☁️ 上传 Windows 安装包 (latest.exe)..."
        rclone copyto "$($WindowsArtifacts.ExePath)" "$($Config.R2Remote):$($Config.BucketName)/Windows/latest.exe" --progress
        Write-Success "✅ Windows 安装包上传完成"
    }

    # 上传 Android 产物
    if ($AndroidArtifacts -and $AndroidArtifacts.ApkPath -and (Test-Path $AndroidArtifacts.ApkPath)) {
        $ApkDestName = $AndroidArtifacts.ApkName
        Write-Info "☁️ 上传 Android APK 存档..."
        rclone copyto "$($AndroidArtifacts.ApkPath)" "$($Config.R2Remote):$($Config.BucketName)/Android/$ApkDestName" --progress

        Write-Info "☁️ 上传 Android 最新版 (latest.apk)..."
        rclone copyto "$($AndroidArtifacts.ApkPath)" "$($Config.R2Remote):$($Config.BucketName)/Android/latest.apk" --progress
        Write-Success "✅ Android APK 上传完成"
    }

    Write-Success "🎉 R2/S3 上传全部完成"
    Write-Info "📥 Windows: $($Config.Domain)/Windows/latest.exe"
    Write-Info "📥 Android: $($Config.Domain)/Android/latest.apk"
}

# ==========================================
# 🐙 上传到 GitHub Release
# ==========================================
function Upload-ToGitHubRelease {
    param(
        [PSCustomObject]$WindowsArtifacts,
        [PSCustomObject]$AndroidArtifacts,
        [hashtable]$VersionInfo
    )

    Write-Section "GitHub Release 发布"

    $Version = $VersionInfo.Version
    $TagName = "v$Version"

    # 检查 Release 是否已存在
    Write-Info "🔍 检查 GitHub Release 是否存在..."
    $existingRelease = gh release view $TagName 2>&1
    $releaseExists = $LASTEXITCODE -eq 0

    # 构建 release notes
    $releaseNotes = Build-ReleaseNotes -VersionInfo $VersionInfo

    if (-not $releaseExists) {
        Write-Info "📝 创建新的 GitHub Release: $TagName"

        $ghArgs = @(
            "release", "create", $TagName
            "--title", $VersionInfo.Title
            "--notes", $releaseNotes
        )

        if ($PreRelease) {
            $ghArgs += "--prerelease"
        }

        if ($Draft) {
            $ghArgs += "--draft"
        }

        & gh @ghArgs

        if ($LASTEXITCODE -ne 0) {
            throw "❌ 创建 GitHub Release 失败"
        }
        Write-Success "✅ GitHub Release 创建成功"
    }
    else {
        Write-Warn "⚠️ Release $TagName 已存在，将上传文件到现有 Release"
    }

    # 收集要上传的文件
    $filesToUpload = @()

    if ($WindowsArtifacts) {
        if ($WindowsArtifacts.ZipPath -and (Test-Path $WindowsArtifacts.ZipPath)) {
            $filesToUpload += $WindowsArtifacts.ZipPath
        }
        if ($WindowsArtifacts.ExePath -and (Test-Path $WindowsArtifacts.ExePath)) {
            $filesToUpload += $WindowsArtifacts.ExePath
        }
    }

    if ($AndroidArtifacts -and $AndroidArtifacts.ApkPath -and (Test-Path $AndroidArtifacts.ApkPath)) {
        $filesToUpload += $AndroidArtifacts.ApkPath
    }

    if ($filesToUpload.Count -eq 0) {
        Write-Warn "⚠️ 没有可上传的文件"
        return
    }

    # 上传文件
    Write-Info "📤 上传构建产物到 Release..."
    foreach ($file in $filesToUpload) {
        $fileName = Split-Path $file -Leaf
        Write-Info "  上传: $fileName"

        # 检查文件是否已存在
        $existingAsset = gh release view $TagName --json assets | ConvertFrom-Json | Select-Object -ExpandProperty assets | Where-Object { $_.name -eq $fileName }

        if ($existingAsset) {
            Write-Warn "  ⚠️ 文件已存在，先删除旧版本..."
            gh release delete-asset $TagName $fileName --yes
        }

        gh release upload $TagName $file --clobber

        if ($LASTEXITCODE -ne 0) {
            Write-ErrorColored "❌ 上传失败: $fileName"
        }
        else {
            Write-Success "  ✅ 上传成功: $fileName"
        }
    }

    Write-Success "🎉 GitHub Release 发布完成"
    Write-Info "🔗 https://github.com/$($Config.RepoOwner)/$($Config.RepoName)/releases/tag/$TagName"
}

# ==========================================
# 📝 构建 Release Notes
# ==========================================
function Build-ReleaseNotes {
    param([hashtable]$VersionInfo)

    $notes = @()
    $notes += "## 纸语 PaperWhisper v$($VersionInfo.Version)"
    $notes += ""
    $notes += "**发布日期:** $($VersionInfo.ReleaseDate)"
    $notes += ""
    $notes += "### 更新内容"
    $notes += ""

    foreach ($item in $VersionInfo.Changelog) {
        $notes += "- $item"
    }

    $notes += ""
    $notes += "---"
    $notes += ""
    $notes += "### 下载说明"
    $notes += ""
    $notes += "| 平台 | 文件 | 说明 |"
    $notes += "|------|------|------|"
    $notes += "| Windows | `paper_whisper_flutter_windows_$($VersionInfo.Version).zip` | 绿色版，解压即用 |"
    $notes += "| Windows | `PaperWhisper_Setup_$($VersionInfo.Version).exe` | 安装包，推荐 |"
    $notes += "| Android | `paper_whisper_flutter_android_$($VersionInfo.Version).apk` | APK 安装包 |"
    $notes += ""
    $notes += "### 快速下载链接"
    $notes += "- Windows: $($Config.Domain)/Windows/latest.exe"
    $notes += "- Android: $($Config.Domain)/Android/latest.apk"

    return ($notes -join "`n")
}

# ==========================================
# 🎯 主流程
# ==========================================
function Main {
    Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║           📝 纸语 PaperWhisper 统一发布脚本                  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

    try {
        # 1. 前置检查
        Test-Prerequisites

        # 2. 读取版本信息
        $VersionInfo = Get-VersionInfo
        Write-Section "版本信息"
        Write-Info "📌 版本: v$($VersionInfo.Version)+$($VersionInfo.BuildNumber)"
        Write-Info "📋 标题: $($VersionInfo.Title)"
        Write-Info "📅 日期: $($VersionInfo.ReleaseDate)"

        # 3. 同步版本号
        Sync-Version

        # 4. 构建平台
        $WindowsArtifacts = $null
        $AndroidArtifacts = $null

        if ($Platform -eq "all" -or $Platform -eq "windows") {
            $WindowsArtifacts = Build-Windows -VersionInfo $VersionInfo
        }

        if ($Platform -eq "all" -or $Platform -eq "android") {
            $AndroidArtifacts = Build-Android -VersionInfo $VersionInfo
        }

        # 5. 上传到 GitHub Release
        if (-not $SkipGitHub) {
            Upload-ToGitHubRelease -WindowsArtifacts $WindowsArtifacts -AndroidArtifacts $AndroidArtifacts -VersionInfo $VersionInfo
        }
        else {
            Write-Warn "⏭️ 跳过 GitHub Release 上传"
        }

        # 6. 上传到 R2/S3
        if (-not $SkipR2) {
            Upload-ToR2 -WindowsArtifacts $WindowsArtifacts -AndroidArtifacts $AndroidArtifacts -VersionInfo $VersionInfo
        }
        else {
            Write-Warn "⏭️ 跳过 R2/S3 上传"
        }

        # 7. 完成总结
        Write-Section "发布完成 🎉"
        Write-Success "✅ 所有任务已完成！"
        Write-Info ""
        Write-Info "📦 构建产物:"
        if ($WindowsArtifacts) {
            if ($WindowsArtifacts.ZipPath -and (Test-Path $WindowsArtifacts.ZipPath)) {
                Write-Info "   - Windows Zip: $($WindowsArtifacts.ZipPath)"
            }
            if ($WindowsArtifacts.ExePath -and (Test-Path $WindowsArtifacts.ExePath)) {
                Write-Info "   - Windows Exe: $($WindowsArtifacts.ExePath)"
            }
        }
        if ($AndroidArtifacts) {
            Write-Info "   - Android APK: $($AndroidArtifacts.ApkPath)"
        }
        Write-Info ""
        Write-Info "🔗 下载地址:"
        Write-Info "   - GitHub: https://github.com/$($Config.RepoOwner)/$($Config.RepoName)/releases/tag/v$($VersionInfo.Version)"
        Write-Info "   - R2/S3: $($Config.Domain)"
        Write-Info ""
        Write-Warn "🔔 别忘了手动把产物备份到网盘哦！"

    }
    catch {
        Write-ErrorColored "`n❌ 错误: $_"
        Write-ErrorColored $_.ScriptStackTrace
        exit 1
    }
    finally {
        # 返回原始目录
        Set-Location $ProjectRoot
    }
}

# 启动主流程
Main
