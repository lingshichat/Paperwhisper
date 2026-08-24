#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    PaperWhisper unified release workflow for Windows and Android.

.DESCRIPTION
    Generates release notes from commits since the previous semantic-version tag,
    lets the publisher edit and approve the draft, then performs version syncing,
    quality checks, builds, Git publication, GitHub Release publication, and R2/S3
    distribution. The client-facing version.json is uploaded last.

.EXAMPLE
    .\scripts\release.ps1 -Preview
    # Print the local changelog draft. No files or remote systems are changed.

.EXAMPLE
    .\scripts\release.ps1
    # Review metadata and notes, then publish Windows and Android.

.EXAMPLE
    .\scripts\release.ps1 -Resume -SkipBuild
    # Resume an interrupted release by reusing versioned local artifacts.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('all', 'windows', 'android')]
    [string]$Platform = 'all',

    [Parameter()]
    [switch]$SkipBuild,

    [Parameter()]
    [switch]$SkipR2,

    [Parameter()]
    [switch]$SkipGitHub,

    [Parameter()]
    [switch]$PreRelease,

    [Parameter()]
    [switch]$Draft,

    [Parameter()]
    [switch]$Preview,

    [Parameter()]
    [switch]$SkipChecks,

    [Parameter()]
    [string]$BaseTag,

    [Parameter()]
    [switch]$Resume
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Utf8NoBom = [Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $script:Utf8NoBom
[Console]::OutputEncoding = $script:Utf8NoBom
$global:OutputEncoding = $script:Utf8NoBom

$script:ReleaseConfig = [ordered]@{
    BucketName       = 'paperwhisper'
    R2Remote         = 'bitiful'
    Domain           = 'https://pwdl.lingshichat.cn'
    BackupDomain     = 'https://paperwhisper.s3.bitiful.net'
    CdnRefreshApi    = 'https://api.bitiful.com/cdn/cache/refresh'
    GitHubRepository = ''
    ReleaseBranch    = 'main'
    GitRemote        = 'origin'
}

$script:ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ProjectRoot = Split-Path -Parent $script:ScriptDirectory
$script:FlutterProjectPath = Join-Path $script:ProjectRoot 'paper_whisper_flutter'
$script:ReleasesPath = Join-Path $script:ProjectRoot 'releases/builds'
$script:VersionFilePath = Join-Path $script:ProjectRoot 'releases/version.json'
$script:PubspecPath = Join-Path $script:FlutterProjectPath 'pubspec.yaml'
$script:AssetVersionPath = Join-Path $script:FlutterProjectPath 'assets/version.json'
$script:IsccPath = $null

function Write-Info {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

function Write-Success {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Write-WarningMessage {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Write-Section {
    param([Parameter(Mandatory)][string]$Title)
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Magenta
    Write-Host "  $Title" -ForegroundColor Magenta
    Write-Host '========================================' -ForegroundColor Magenta
}

function Invoke-CapturedCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter()][string[]]$Arguments = @(),
        [Parameter()][string]$WorkingDirectory = $script:ProjectRoot,
        [Parameter()][int[]]$AllowedExitCodes = @(0)
    )

    Push-Location $WorkingDirectory
    try {
        $output = @(& $Command @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    if ($AllowedExitCodes -notcontains $exitCode) {
        $details = ($output | ForEach-Object { $_.ToString() }) -join "`n"
        throw "Command failed ($exitCode): $Command $($Arguments -join ' ')`n$details"
    }

    return @($output | ForEach-Object { $_.ToString() })
}

function Invoke-StreamingCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter()][string[]]$Arguments = @(),
        [Parameter()][string]$WorkingDirectory = $script:ProjectRoot
    )

    Push-Location $WorkingDirectory
    try {
        & $Command @Arguments
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    if ($exitCode -ne 0) {
        throw "Command failed ($exitCode): $Command $($Arguments -join ' ')"
    }
}

function Invoke-CommandResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter()][string[]]$Arguments = @(),
        [Parameter()][string]$WorkingDirectory = $script:ProjectRoot
    )

    Push-Location $WorkingDirectory
    try {
        $output = @(& $Command @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    return [PSCustomObject]@{
        ExitCode = $exitCode
        Output   = @($output | ForEach-Object { $_.ToString() })
    }
}

function Assert-CommandAvailable {
    param([Parameter(Mandatory)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command is unavailable: $Name"
    }
}

function ConvertFrom-GitHubRemoteUrl {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RemoteUrl)

    $match = [regex]::Match($RemoteUrl.Trim(), '(?i)github\.com[:/](?<path>[^?#]+?)(?:\.git)?/?$')
    if (-not $match.Success) {
        throw "origin is not a GitHub repository URL: $RemoteUrl"
    }

    $repositoryPath = ($match.Groups['path'].Value -replace '\.git$', '').Trim('/')
    $parts = $repositoryPath -split '/'
    if ($parts.Count -ne 2 -or -not $parts[0] -or -not $parts[1]) {
        throw "Could not derive OWNER/REPO from origin: $RemoteUrl"
    }
    return "$($parts[0])/$($parts[1])"
}

function ConvertTo-SemVer {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Version)

    $match = [regex]::Match($Version.Trim(), '^v?(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)$')
    if (-not $match.Success) {
        throw "Invalid semantic version: $Version (expected MAJOR.MINOR.PATCH)"
    }

    $major = [int]$match.Groups['major'].Value
    $minor = [int]$match.Groups['minor'].Value
    $patch = [int]$match.Groups['patch'].Value
    $text = "$major.$minor.$patch"

    return [PSCustomObject]@{
        Major = $major
        Minor = $minor
        Patch = $patch
        Text  = $text
        Tag   = "v$text"
    }
}

function Compare-SemVer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Left,
        [Parameter(Mandatory)][string]$Right
    )

    $leftVersion = ConvertTo-SemVer $Left
    $rightVersion = ConvertTo-SemVer $Right
    foreach ($property in @('Major', 'Minor', 'Patch')) {
        if ($leftVersion.$property -lt $rightVersion.$property) { return -1 }
        if ($leftVersion.$property -gt $rightVersion.$property) { return 1 }
    }
    return 0
}

function Assert-VersionIsNewer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Candidate,
        [Parameter(Mandatory)][string]$Baseline
    )

    if ((Compare-SemVer -Left $Candidate -Right $Baseline) -le 0) {
        throw "Target version $Candidate must be newer than $Baseline"
    }
}

function Test-LocalTagExists {
    param([Parameter(Mandatory)][string]$Tag)

    Push-Location $script:ProjectRoot
    try {
        & git rev-parse --verify --quiet "refs/tags/$Tag" *> $null
        return $LASTEXITCODE -eq 0
    }
    finally {
        Pop-Location
    }
}

function Test-GitAncestor {
    param(
        [Parameter(Mandatory)][string]$Ancestor,
        [Parameter(Mandatory)][string]$Descendant
    )

    Push-Location $script:ProjectRoot
    try {
        & git merge-base --is-ancestor $Ancestor $Descendant *> $null
        return $LASTEXITCODE -eq 0
    }
    finally {
        Pop-Location
    }
}

function Get-SemanticVersionTags {
    $tags = @(Invoke-CapturedCommand -Command 'git' -Arguments @(
        'tag', '--merged', 'HEAD', '--list', 'v[0-9]*', '--sort=-version:refname'
    ))

    return @($tags | Where-Object { $_ -match '^v\d+\.\d+\.\d+$' })
}

function Test-InternalReleaseSubject {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Subject)

    return $Subject -match '(?i)(?:^|[\s:：])(release|deploy|build|ci|refactor|dependency|dependencies|toolchain|workflow|quality baseline)(?:$|[\s:：])|发布脚本|部署脚本|项目结构|工作流|质量基线|^重构'
}

function Get-ReleaseBaseTag {
    [CmdletBinding()]
    param(
        [Parameter()][string]$RequestedTag,
        [Parameter()][switch]$ResumeRelease,
        [Parameter(Mandatory)][string]$ManifestVersion
    )

    $tags = @(Get-SemanticVersionTags)
    if ($tags.Count -eq 0) {
        throw 'No reachable semantic-version tag was found.'
    }

    if ($RequestedTag) {
        if ($tags -notcontains $RequestedTag) {
            throw "Base tag $RequestedTag does not exist or is not an ancestor of HEAD."
        }
        return $RequestedTag
    }

    if (-not $ResumeRelease) {
        return $tags[0]
    }

    $currentTag = (ConvertTo-SemVer $ManifestVersion).Tag
    $currentIndex = [array]::IndexOf($tags, $currentTag)
    if ($currentIndex -lt 0) {
        return $tags[0]
    }
    if ($currentIndex + 1 -ge $tags.Count) {
        throw "No release tag exists before $currentTag; changelog range is unknown."
    }
    return $tags[$currentIndex + 1]
}

function ConvertTo-ReleaseCommit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Hash,
        [Parameter(Mandatory)][string]$ShortHash,
        [Parameter(Mandatory)][string]$Subject
    )

    $conventional = [regex]::Match(
        $Subject,
        '^(?<type>[A-Za-z]+)(?:\((?<scope>[^)]+)\))?(?<breaking>!)?:\s*(?<subject>.+)$'
    )

    if (-not $conventional.Success) {
        return [PSCustomObject]@{
            Hash      = $Hash
            ShortHash = $ShortHash
            RawSubject = $Subject
            Subject   = $Subject.Trim()
            Type      = 'other'
            Scope     = ''
            Breaking  = $false
            Include   = -not (Test-InternalReleaseSubject -Subject $Subject)
            Category  = '其他更新'
        }
    }

    $type = $conventional.Groups['type'].Value.ToLowerInvariant()
    $scope = $conventional.Groups['scope'].Value.ToLowerInvariant()
    $breaking = $conventional.Groups['breaking'].Success
    $internalTypes = @('docs', 'test', 'chore', 'style', 'ci', 'build', 'refactor')
    $internalScopes = @(
        'trellis', 'spec', 'task', 'gitignore', 'deps', 'dependencies',
        'flutter', 'tooling', 'release', 'infra'
    )
    $include = (
        ($internalTypes -notcontains $type) -and
        ($internalScopes -notcontains $scope) -and
        (-not (Test-InternalReleaseSubject -Subject $conventional.Groups['subject'].Value))
    )

    $category = switch ($type) {
        'feat' { '新增功能' }
        'fix' { '问题修复' }
        'perf' { '性能优化' }
        default { '其他更新' }
    }

    if ($type -notin @('feat', 'fix', 'perf')) {
        $include = $false
    }

    return [PSCustomObject]@{
        Hash       = $Hash
        ShortHash  = $ShortHash
        RawSubject = $Subject
        Subject    = $conventional.Groups['subject'].Value.Trim()
        Type       = $type
        Scope      = $scope
        Breaking   = $breaking
        Include    = $include
        Category   = $category
    }
}

function Get-ReleaseCommits {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$FromTag)

    if (-not (Test-GitAncestor -Ancestor $FromTag -Descendant 'HEAD')) {
        throw "Base tag $FromTag is not an ancestor of HEAD."
    }

    $records = @(Invoke-CapturedCommand -Command 'git' -Arguments @(
        '-c', 'i18n.logOutputEncoding=utf-8',
        'log', "$FromTag..HEAD", '--no-merges', '--format=%H%x09%h%x09%s'
    ))
    if ($records.Count -eq 0) {
        throw "No commits exist after $FromTag."
    }

    $commits = foreach ($record in $records) {
        $parts = $record -split "`t", 3
        if ($parts.Count -ne 3) {
            throw "Could not parse git log record: $record"
        }
        ConvertTo-ReleaseCommit -Hash $parts[0] -ShortHash $parts[1] -Subject $parts[2]
    }

    $included = @($commits | Where-Object Include)
    if ($included.Count -eq 0) {
        throw "No user-facing commits remain after filtering $FromTag..HEAD."
    }
    return @($commits)
}

function Get-SuggestedVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BaseVersion,
        [Parameter(Mandatory)][object[]]$Commits
    )

    $version = ConvertTo-SemVer $BaseVersion
    $included = @($Commits | Where-Object Include)
    if (@($included | Where-Object Breaking).Count -gt 0) {
        return "$($version.Major + 1).0.0"
    }
    if (@($included | Where-Object Type -eq 'feat').Count -gt 0) {
        return "$($version.Major).$($version.Minor + 1).0"
    }
    return "$($version.Major).$($version.Minor).$($version.Patch + 1)"
}

function New-ReleaseDraft {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][object[]]$Commits
    )

    $lines = @(
        '<!-- 请将条目改写成面向普通用户的中文：说明有什么变化、带来什么改善，避免框架版本、重构、依赖和构建等实现术语；并至少保留一项。 -->',
        "<!-- 为 v$Version 自动生成；commit 注释发布后不可见。 -->"
    )

    foreach ($category in @('新增功能', '问题修复', '性能优化', '其他更新')) {
        $items = @($Commits | Where-Object { $_.Include -and $_.Category -eq $category })
        if ($items.Count -eq 0) { continue }

        $lines += ''
        $lines += "## $category"
        foreach ($item in $items) {
            $lines += "- $($item.Subject) <!-- commit: $($item.ShortHash) -->"
        }
    }

    return ($lines -join "`n").Trim() + "`n"
}

function ConvertFrom-ReleaseDraft {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Markdown)

    $category = ''
    $items = [System.Collections.Generic.List[string]]::new()
    $prefixes = @{
        '新增功能' = '新增'
        '问题修复' = '修复'
        '性能优化' = '优化'
        '体验优化' = '优化'
        '其他更新' = '更新'
    }

    foreach ($line in ($Markdown -split '\r?\n')) {
        $headingMatch = [regex]::Match($line, '^##\s+(?<heading>.+?)\s*$')
        if ($headingMatch.Success) {
            $category = $headingMatch.Groups['heading'].Value.Trim()
            continue
        }

        $itemMatch = [regex]::Match($line, '^\s*[-*]\s+(?<item>.+?)\s*$')
        if (-not $itemMatch.Success) { continue }

        $item = $itemMatch.Groups['item'].Value
        $item = ($item -replace '\s*<!--\s*commit:\s*[0-9a-fA-F]+\s*-->\s*$', '').Trim()
        if (-not $item) { continue }

        if ($prefixes.ContainsKey($category)) {
            $prefix = $prefixes[$category]
            $escapedPrefix = [regex]::Escape($prefix)
            if ($item -notmatch "^${escapedPrefix}[：:]\s*") {
                if ($item -match "^${escapedPrefix}(?<content>.+)$") {
                    $item = "${prefix}：$($matches['content'].TrimStart())"
                }
                else {
                    $item = "${prefix}：$item"
                }
            }
        }
        elseif ($category) {
            $item = "${category}：$item"
        }

        $items.Add($item)
    }

    if ($items.Count -eq 0) {
        throw 'The release draft must contain at least one Markdown list item.'
    }
    return @($items)
}

function Get-VersionManifest {
    if (-not (Test-Path $script:VersionFilePath)) {
        throw "Version manifest is missing: $script:VersionFilePath"
    }
    return Get-Content $script:VersionFilePath -Raw -Encoding utf8 | ConvertFrom-Json
}

function Read-ValueWithDefault {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][string]$Default
    )

    $value = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
    return $value.Trim()
}

function Read-YesNoWithDefault {
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][bool]$Default
    )

    $suffix = if ($Default) { 'Y/n' } else { 'y/N' }
    while ($true) {
        $answer = (Read-Host "$Prompt [$suffix]").Trim().ToLowerInvariant()
        if (-not $answer) { return $Default }
        if ($answer -in @('y', 'yes')) { return $true }
        if ($answer -in @('n', 'no')) { return $false }
        Write-WarningMessage '请输入 y 或 n。'
    }
}

function Get-InteractiveReleaseMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Manifest,
        [Parameter(Mandatory)][string]$BaselineVersion,
        [Parameter(Mandatory)][string]$SuggestedVersion,
        [Parameter()][switch]$ResumeRelease
    )

    if ($ResumeRelease) {
        return [PSCustomObject]@{
            Version       = [string]$Manifest.latestVersion
            BuildNumber   = [int]$Manifest.latestBuildNumber
            Title         = [string]$Manifest.title
            ReleaseDate   = [string]$Manifest.releaseDate
            IsForceUpdate = [bool]$Manifest.isForceUpdate
        }
    }

    $version = Read-ValueWithDefault -Prompt '目标版本' -Default $SuggestedVersion
    $parsedVersion = ConvertTo-SemVer $version
    Assert-VersionIsNewer -Candidate $parsedVersion.Text -Baseline $BaselineVersion

    $defaultBuild = [int]$Manifest.latestBuildNumber + 1
    while ($true) {
        $buildText = Read-ValueWithDefault -Prompt '构建号' -Default "$defaultBuild"
        $buildNumber = 0
        if ([int]::TryParse($buildText, [ref]$buildNumber) -and $buildNumber -gt [int]$Manifest.latestBuildNumber) {
            break
        }
        Write-WarningMessage "构建号必须大于 $($Manifest.latestBuildNumber)。"
    }

    $title = Read-ValueWithDefault -Prompt '发布标题' -Default "纸语 $($parsedVersion.Text)"
    while ($true) {
        $releaseDate = Read-ValueWithDefault -Prompt '发布日期' -Default (Get-Date -Format 'yyyy-MM-dd')
        $parsedDate = [datetime]::MinValue
        if ([datetime]::TryParseExact(
            $releaseDate,
            'yyyy-MM-dd',
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::None,
            [ref]$parsedDate
        )) { break }
        Write-WarningMessage '发布日期必须使用 YYYY-MM-DD。'
    }

    $isForceUpdate = Read-YesNoWithDefault -Prompt '是否强制用户更新' -Default $false
    return [PSCustomObject]@{
        Version       = $parsedVersion.Text
        BuildNumber   = $buildNumber
        Title         = $title
        ReleaseDate   = $releaseDate
        IsForceUpdate = $isForceUpdate
    }
}

function Resolve-DraftEditor {
    $editor = if ($env:VISUAL) { $env:VISUAL } elseif ($env:EDITOR) { $env:EDITOR } else { $null }
    if (-not $editor) {
        if ($IsWindows) { return 'notepad.exe' }
        throw 'Set VISUAL or EDITOR to an editor executable before publishing.'
    }

    if ($editor -match '\s' -and -not (Test-Path $editor)) {
        throw 'VISUAL/EDITOR must contain an executable path without command-line arguments.'
    }
    return $editor
}

function Invoke-DraftEditor {
    param([Parameter(Mandatory)][string]$DraftPath)

    $editor = Resolve-DraftEditor
    $arguments = @($DraftPath)
    if ((Split-Path $editor -Leaf) -match '^code(?:\.cmd|\.exe)?$') {
        $arguments = @('--wait', $DraftPath)
    }

    $process = Start-Process -FilePath $editor -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Editor exited with code $($process.ExitCode): $editor"
    }
}

function Edit-ReleaseDraft {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$InitialDraft
    )

    $draftPath = Join-Path ([IO.Path]::GetTempPath()) "paperwhisper-release-v$Version.md"
    [IO.File]::WriteAllText($draftPath, $InitialDraft, [Text.UTF8Encoding]::new($false))

    try {
        while ($true) {
            $draft = [IO.File]::ReadAllText($draftPath, [Text.Encoding]::UTF8)
            Write-Section '更新日志草稿'
            Write-Host $draft
            Write-Host '[E] 编辑  [C] 继续  [Q] 取消' -ForegroundColor Yellow
            $choice = (Read-Host '请选择').Trim().ToUpperInvariant()
            switch ($choice) {
                'E' {
                    Invoke-DraftEditor -DraftPath $draftPath
                }
                'C' {
                    [void](ConvertFrom-ReleaseDraft -Markdown $draft)
                    return $draft
                }
                'Q' {
                    throw '发布已在最终确认前取消。'
                }
                default {
                    Write-WarningMessage '请输入 E、C 或 Q。'
                }
            }
        }
    }
    finally {
        Remove-Item $draftPath -Force -ErrorAction SilentlyContinue
    }
}

function Test-ReleaseConfirmation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InputText,
        [Parameter(Mandatory)][string]$Version
    )

    return $InputText -ceq "RELEASE v$Version"
}

function Confirm-Release {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Metadata,
        [Parameter(Mandatory)][string]$FromTag,
        [Parameter(Mandatory)][int]$IncludedCommitCount,
        [Parameter(Mandatory)][string]$SelectedPlatform
    )

    Write-Section '最终确认'
    Write-Host "提交范围：          $FromTag..HEAD（$IncludedCommitCount 条用户可见提交）"
    Write-Host "版本：              v$($Metadata.Version)+$($Metadata.BuildNumber)"
    Write-Host "标题：              $($Metadata.Title)"
    Write-Host "发布日期：          $($Metadata.ReleaseDate)"
    Write-Host "平台：              $SelectedPlatform"
    Write-Host "强制更新：          $($Metadata.IsForceUpdate)"
    Write-Host "质量检查：          $(if ($SkipChecks) { '跳过' } else { 'flutter analyze + flutter test' })"
    Write-Host "构建：              $(if ($SkipBuild) { '复用版本化产物' } else { '重新构建 Release' })"
    Write-Host "GitHub：            $(if ($SkipGitHub) { '跳过' } else { '草稿 -> 上传 -> 公开' })"
    Write-Host "R2/S3：             $(if ($SkipR2) { '跳过' } else { '版本化产物 -> latest -> version.json -> CDN 刷新' })"
    Write-Host "发布通道：          $(if ($Draft) { '仅草稿' } elseif ($PreRelease) { '预发布' } else { '稳定版' })"
    Write-Host 'Git：               commit + push main + tag'

    if ($SkipChecks) {
        Write-WarningMessage '警告：本次将跳过质量检查。'
    }
    if ($PreRelease -or $Draft) {
        Write-WarningMessage '该通道不会更新 latest 文件和客户端 version.json。'
    }

    $expected = "RELEASE v$($Metadata.Version)"
    $confirmation = Read-Host "请输入精确文本 '$expected' 继续"
    if (-not (Test-ReleaseConfirmation -InputText $confirmation -Version $Metadata.Version)) {
        throw '确认文本不匹配，发布已取消。'
    }
}

function Resolve-IsccPath {
    if ($env:ISCC_PATH) {
        if (-not (Test-Path $env:ISCC_PATH -PathType Leaf)) {
            throw "ISCC_PATH does not point to a file: $env:ISCC_PATH"
        }
        return $env:ISCC_PATH
    }

    $command = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue
    if (-not $command) {
        throw 'Inno Setup compiler ISCC.exe is unavailable. Add it to PATH or set ISCC_PATH.'
    }
    return $command.Source
}

function Assert-AndroidSigningConfiguration {
    $propertiesPath = Join-Path $script:FlutterProjectPath 'android/key.properties'
    if (-not (Test-Path $propertiesPath -PathType Leaf)) {
        throw "Android signing configuration is missing: $propertiesPath"
    }

    $properties = @{}
    foreach ($line in Get-Content $propertiesPath -Encoding utf8) {
        if ($line -match '^\s*(?<key>[^#!][^=]*?)\s*=\s*(?<value>.+?)\s*$') {
            $properties[$matches['key'].Trim()] = $matches['value'].Trim()
        }
    }
    foreach ($required in @('storeFile', 'storePassword', 'keyAlias', 'keyPassword')) {
        if (-not $properties.ContainsKey($required) -or -not $properties[$required]) {
            throw "Android key.properties is missing required field: $required"
        }
    }

    $storeFile = [string]$properties['storeFile']
    $storePath = if ([IO.Path]::IsPathRooted($storeFile)) {
        $storeFile
    }
    else {
        Join-Path (Join-Path $script:FlutterProjectPath 'android/app') $storeFile
    }
    if (-not (Test-Path $storePath -PathType Leaf)) {
        throw 'Android signing keystore referenced by key.properties does not exist.'
    }
}

function Test-RepositoryHeadAllowed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$LocalHead,
        [Parameter(Mandatory)][string]$RemoteHead,
        [Parameter()][switch]$ResumeRelease,
        [Parameter()][string]$LocalParent,
        [Parameter()][string]$LocalSubject,
        [Parameter()][string]$ResumeVersion
    )

    if ($LocalHead -eq $RemoteHead) { return $true }
    if (-not $ResumeRelease -or -not $ResumeVersion) { return $false }
    return (
        $LocalParent -eq $RemoteHead -and
        $LocalSubject -ceq "chore(release): v$ResumeVersion"
    )
}

function Assert-RepositoryReady {
    [CmdletBinding()]
    param(
        [Parameter()][switch]$ResumeRelease,
        [Parameter()][string]$ResumeVersion
    )

    Write-Section '仓库预检'
    Assert-CommandAvailable 'git'

    $branch = @(Invoke-CapturedCommand -Command 'git' -Arguments @('branch', '--show-current'))[0]
    if ($branch -ne $script:ReleaseConfig.ReleaseBranch) {
        throw "Release must run from branch $($script:ReleaseConfig.ReleaseBranch), current branch is $branch."
    }

    $status = @(Invoke-CapturedCommand -Command 'git' -Arguments @('status', '--porcelain'))
    if ($status.Count -gt 0) {
        throw "Working tree must be clean before release:`n$($status -join "`n")"
    }

    $remoteUrl = @(Invoke-CapturedCommand -Command 'git' -Arguments @(
        'remote', 'get-url', $script:ReleaseConfig.GitRemote
    ))[0]
    $script:ReleaseConfig.GitHubRepository = ConvertFrom-GitHubRemoteUrl $remoteUrl

    Write-Info '正在从 origin 获取 main 和 tags...'
    Invoke-StreamingCommand -Command 'git' -Arguments @(
        'fetch', $script:ReleaseConfig.GitRemote, $script:ReleaseConfig.ReleaseBranch, '--tags'
    )

    $localHead = @(Invoke-CapturedCommand -Command 'git' -Arguments @('rev-parse', 'HEAD'))[0]
    $remoteHead = @(Invoke-CapturedCommand -Command 'git' -Arguments @(
        'rev-parse', "$($script:ReleaseConfig.GitRemote)/$($script:ReleaseConfig.ReleaseBranch)"
    ))[0]
    if ($localHead -ne $remoteHead) {
        $parentHead = @(Invoke-CapturedCommand -Command 'git' -Arguments @('rev-parse', 'HEAD^'))[0]
        $headSubject = @(Invoke-CapturedCommand -Command 'git' -Arguments @('log', '-1', '--format=%s'))[0]
        $repositoryStateParameters = @{
            LocalHead      = $localHead
            RemoteHead     = $remoteHead
            ResumeRelease  = $ResumeRelease
            LocalParent    = $parentHead
            LocalSubject   = $headSubject
            ResumeVersion  = $ResumeVersion
        }
        $repositoryStateAllowed = Test-RepositoryHeadAllowed @repositoryStateParameters
        if (-not $repositoryStateAllowed) {
            throw 'Local HEAD must match origin/main, except for one unpushed matching release commit in -Resume mode.'
        }
        Write-WarningMessage 'Resume mode will push the existing local release commit.'
    }
    Write-Success '仓库状态干净且已同步。'
}

function Assert-ReleasePrerequisites {
    Write-Section '工具预检'
    Assert-CommandAvailable 'flutter'
    Assert-CommandAvailable 'dart'

    if (-not $SkipGitHub) { Assert-CommandAvailable 'gh' }
    if (-not $SkipR2) { Assert-CommandAvailable 'rclone' }

    if (-not $SkipBuild -and $Platform -in @('all', 'windows')) {
        $script:IsccPath = Resolve-IsccPath
    }
    if (-not $SkipBuild -and $Platform -in @('all', 'android')) {
        Assert-AndroidSigningConfiguration
    }

    if ($SkipGitHub -and $SkipR2) {
        throw 'SkipGitHub and SkipR2 cannot both be set for a release.'
    }
    if (-not $SkipR2 -and -not $PreRelease -and -not $Draft -and $Platform -ne 'all') {
        throw 'A stable client release must build both platforms because version.json is shared.'
    }
    if (
        -not $SkipR2 -and
        -not $PreRelease -and
        -not $Draft -and
        [string]::IsNullOrWhiteSpace($env:BITIFUL_API_TOKEN)
    ) {
        throw 'BITIFUL_API_TOKEN is required to refresh the stable client CDN cache.'
    }

    Write-Success '本地工具和签名输入可用。'
}

function Assert-PublishCredentials {
    Write-Section '远端认证'
    if (-not $SkipGitHub) {
        Invoke-StreamingCommand -Command 'gh' -Arguments @('auth', 'status')
    }
    if (-not $SkipR2) {
        $remotes = @(Invoke-CapturedCommand -Command 'rclone' -Arguments @('listremotes'))
        if ($remotes -notcontains "$($script:ReleaseConfig.R2Remote):") {
            throw "rclone remote is not configured: $($script:ReleaseConfig.R2Remote):"
        }
    }
    Write-Success '远端凭据已配置。'
}

function Backup-VersionFiles {
    $backups = foreach ($path in @($script:VersionFilePath, $script:PubspecPath, $script:AssetVersionPath)) {
        [PSCustomObject]@{
            Path  = $path
            Bytes = [IO.File]::ReadAllBytes($path)
        }
    }
    return @($backups)
}

function Restore-VersionFiles {
    param([Parameter(Mandatory)][object[]]$Backups)

    foreach ($backup in $Backups) {
        [IO.File]::WriteAllBytes($backup.Path, $backup.Bytes)
    }
}

function Write-VersionManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Metadata,
        [Parameter(Mandatory)][string[]]$Changelog,
        [Parameter(Mandatory)][object]$ExistingManifest
    )

    $manifest = [ordered]@{
        latestVersion      = $Metadata.Version
        latestBuildNumber  = $Metadata.BuildNumber
        releaseDate        = $Metadata.ReleaseDate
        title              = $Metadata.Title
        isForceUpdate      = $Metadata.IsForceUpdate
        changelog          = @($Changelog)
        downloadUrl        = [ordered]@{
            android = "$($script:ReleaseConfig.Domain)/Android/latest.apk"
            windows = "$($script:ReleaseConfig.Domain)/Windows/latest.exe"
        }
        backupUrl          = [ordered]@{
            android = "$($script:ReleaseConfig.BackupDomain)/Android/latest.apk"
            windows = "$($script:ReleaseConfig.BackupDomain)/Windows/latest.exe"
        }
        minSupportedVersion = [string]$ExistingManifest.minSupportedVersion
    }

    $json = $manifest | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText(
        $script:VersionFilePath,
        "$json`n",
        [Text.UTF8Encoding]::new($false)
    )
}

function Sync-AndVerifyVersionFiles {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Metadata)

    Write-Section '版本同步'
    Invoke-StreamingCommand -Command 'dart' -Arguments @('run', 'tool/sync_version.dart') -WorkingDirectory $script:FlutterProjectPath

    $expectedPubspecLine = "version: $($Metadata.Version)+$($Metadata.BuildNumber)"
    $pubspecVersionLine = Get-Content $script:PubspecPath -Encoding utf8 |
        Where-Object { $_ -match '^version:\s+' } |
        Select-Object -First 1
    if ($pubspecVersionLine -ne $expectedPubspecLine) {
        throw "pubspec.yaml version mismatch: expected '$expectedPubspecLine', got '$pubspecVersionLine'"
    }

    $manifestContent = [IO.File]::ReadAllText($script:VersionFilePath, [Text.Encoding]::UTF8)
    $assetContent = [IO.File]::ReadAllText($script:AssetVersionPath, [Text.Encoding]::UTF8)
    if ($manifestContent -cne $assetContent) {
        throw 'assets/version.json does not exactly match releases/version.json.'
    }
    Write-Success "版本已同步：v$($Metadata.Version)+$($Metadata.BuildNumber)"
}

function Invoke-QualityChecks {
    if ($SkipChecks) {
        Write-WarningMessage '已显式跳过质量检查。'
        return
    }

    Write-Section '质量检查'
    Invoke-StreamingCommand -Command 'flutter' -Arguments @('pub', 'get', '--enforce-lockfile') -WorkingDirectory $script:FlutterProjectPath
    Invoke-StreamingCommand -Command 'flutter' -Arguments @('analyze') -WorkingDirectory $script:FlutterProjectPath
    Invoke-StreamingCommand -Command 'flutter' -Arguments @('test') -WorkingDirectory $script:FlutterProjectPath
    Write-Success 'Flutter 静态分析和测试已通过。'
}

function Get-ArtifactSet {
    param([Parameter(Mandatory)][string]$Version)

    return [PSCustomObject]@{
        WindowsZip = Join-Path $script:ReleasesPath "paper_whisper_flutter_windows_$Version.zip"
        WindowsExe = Join-Path $script:ReleasesPath "PaperWhisper_Setup_$Version.exe"
        AndroidApk = Join-Path $script:ReleasesPath "paper_whisper_flutter_android_$Version.apk"
    }
}

function Assert-ArtifactFile {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path -PathType Leaf)) {
        throw "Release artifact is missing: $Path"
    }
    if ((Get-Item $Path).Length -le 0) {
        throw "Release artifact is empty: $Path"
    }
}

function Build-WindowsArtifacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][object]$Artifacts
    )

    Write-Section 'Windows 构建'
    Remove-Item $Artifacts.WindowsZip -Force -ErrorAction SilentlyContinue
    Remove-Item $Artifacts.WindowsExe -Force -ErrorAction SilentlyContinue

    Invoke-StreamingCommand -Command 'flutter' -Arguments @('build', 'windows', '--release') -WorkingDirectory $script:FlutterProjectPath
    $buildDirectory = Join-Path $script:FlutterProjectPath 'build/windows/x64/runner/Release'
    $runnerExecutable = Join-Path $buildDirectory 'paper_whisper_flutter.exe'
    Assert-ArtifactFile $runnerExecutable

    Compress-Archive -Path (Join-Path $buildDirectory '*') -DestinationPath $Artifacts.WindowsZip -Force
    Assert-ArtifactFile $Artifacts.WindowsZip

    $installerScript = Join-Path $script:FlutterProjectPath 'installers/paper_whisper.iss'
    Invoke-StreamingCommand -Command $script:IsccPath -Arguments @(
        "/DMyAppVersion=$Version", $installerScript
    ) -WorkingDirectory $script:FlutterProjectPath
    Assert-ArtifactFile $Artifacts.WindowsExe
    Write-Success 'Windows ZIP 和安装包已生成。'
}

function Build-AndroidArtifact {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Artifacts)

    Write-Section 'Android 构建'
    Remove-Item $Artifacts.AndroidApk -Force -ErrorAction SilentlyContinue
    Invoke-StreamingCommand -Command 'flutter' -Arguments @(
        'build', 'apk', '--release', '--target-platform', 'android-arm64'
    ) -WorkingDirectory $script:FlutterProjectPath

    $sourceApk = Join-Path $script:FlutterProjectPath 'build/app/outputs/flutter-apk/app-release.apk'
    Assert-ArtifactFile $sourceApk
    Copy-Item $sourceApk $Artifacts.AndroidApk -Force
    Assert-ArtifactFile $Artifacts.AndroidApk
    Write-Success '版本化 Android APK 已生成。'
}

function Build-ReleaseArtifacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][object]$Artifacts
    )

    if (-not (Test-Path $script:ReleasesPath)) {
        New-Item -ItemType Directory -Path $script:ReleasesPath -Force | Out-Null
    }

    if ($SkipBuild) {
        Write-Section '复用构建产物'
        if ($Platform -in @('all', 'windows')) {
            Assert-ArtifactFile $Artifacts.WindowsZip
            Assert-ArtifactFile $Artifacts.WindowsExe
        }
        if ($Platform -in @('all', 'android')) {
            Assert-ArtifactFile $Artifacts.AndroidApk
        }
        Write-Success '所需版本化产物均可用。'
        return
    }

    if ($Platform -in @('all', 'windows')) {
        Build-WindowsArtifacts -Version $Version -Artifacts $Artifacts
    }
    if ($Platform -in @('all', 'android')) {
        Build-AndroidArtifact -Artifacts $Artifacts
    }
}

function Get-SelectedArtifactFiles {
    param([Parameter(Mandatory)][object]$Artifacts)

    $files = [System.Collections.Generic.List[string]]::new()
    if ($Platform -in @('all', 'windows')) {
        $files.Add($Artifacts.WindowsZip)
        $files.Add($Artifacts.WindowsExe)
    }
    if ($Platform -in @('all', 'android')) {
        $files.Add($Artifacts.AndroidApk)
    }
    return @($files)
}

function Assert-OnlyVersionFilesChanged {
    $expected = @(
        'releases/version.json',
        'paper_whisper_flutter/pubspec.yaml',
        'paper_whisper_flutter/assets/version.json'
    )
    $status = @(Invoke-CapturedCommand -Command 'git' -Arguments @('status', '--porcelain'))
    $unexpected = foreach ($line in $status) {
        if ($line.Length -lt 4) { $line; continue }
        $path = $line.Substring(3).Trim().Replace('\', '/')
        if ($expected -notcontains $path) { $line }
    }
    if (@($unexpected).Count -gt 0) {
        throw "Unexpected working tree changes appeared during release:`n$($unexpected -join "`n")"
    }
}

function Get-HeadCommit {
    return @(Invoke-CapturedCommand -Command 'git' -Arguments @('rev-parse', 'HEAD'))[0]
}

function Publish-GitState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter()][switch]$ResumeRelease
    )

    $tag = "v$Version"
    if ($ResumeRelease) {
        $headCommit = Get-HeadCommit
        if (Test-LocalTagExists $tag) {
            $tagCommit = @(Invoke-CapturedCommand -Command 'git' -Arguments @('rev-list', '-n', '1', $tag))[0]
            if ($tagCommit -ne $headCommit) {
                throw "Resume requires HEAD to equal $tag ($tagCommit)."
            }
        }
        else {
            Invoke-StreamingCommand -Command 'git' -Arguments @('tag', '-a', $tag, '-m', "PaperWhisper $tag")
        }
        Invoke-StreamingCommand -Command 'git' -Arguments @('push', $script:ReleaseConfig.GitRemote, $script:ReleaseConfig.ReleaseBranch)
        Invoke-StreamingCommand -Command 'git' -Arguments @('push', $script:ReleaseConfig.GitRemote, $tag)
        return $headCommit
    }

    Assert-OnlyVersionFilesChanged
    $paths = @(
        'releases/version.json',
        'paper_whisper_flutter/pubspec.yaml',
        'paper_whisper_flutter/assets/version.json'
    )
    Invoke-StreamingCommand -Command 'git' -Arguments (@('add', '--') + $paths)
    $staged = @(Invoke-CapturedCommand -Command 'git' -Arguments @('diff', '--cached', '--name-only'))
    if ($staged.Count -ne $paths.Count) {
        throw "Expected three staged version files, found $($staged.Count)."
    }

    Invoke-StreamingCommand -Command 'git' -Arguments @('commit', '-m', "chore(release): v$Version")
    $releaseCommit = Get-HeadCommit
    Invoke-StreamingCommand -Command 'git' -Arguments @('push', $script:ReleaseConfig.GitRemote, $script:ReleaseConfig.ReleaseBranch)

    Invoke-StreamingCommand -Command 'git' -Arguments @('tag', '-a', $tag, '-m', "PaperWhisper $tag")
    Invoke-StreamingCommand -Command 'git' -Arguments @('push', $script:ReleaseConfig.GitRemote, $tag)
    return $releaseCommit
}

function New-ReleaseNotesFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Metadata,
        [Parameter(Mandatory)][string]$DraftMarkdown,
        [Parameter(Mandatory)][object]$Artifacts
    )

    $lines = @(
        "# 纸语 PaperWhisper v$($Metadata.Version)",
        '',
        "发布日期：$($Metadata.ReleaseDate)",
        '',
        $DraftMarkdown.Trim(),
        '',
        '---',
        '',
        '## 下载',
        ''
    )
    if ($Platform -in @('all', 'windows')) {
        $lines += "- Windows 安装版：$([IO.Path]::GetFileName($Artifacts.WindowsExe))"
        $lines += "- Windows 绿色版：$([IO.Path]::GetFileName($Artifacts.WindowsZip))"
    }
    if ($Platform -in @('all', 'android')) {
        $lines += "- Android：$([IO.Path]::GetFileName($Artifacts.AndroidApk))"
    }
    if (-not $PreRelease -and -not $Draft -and -not $SkipR2) {
        $lines += ''
        $lines += "- Windows 快速下载：$($script:ReleaseConfig.Domain)/Windows/latest.exe"
        $lines += "- Android 快速下载：$($script:ReleaseConfig.Domain)/Android/latest.apk"
    }

    $notesPath = Join-Path ([IO.Path]::GetTempPath()) "paperwhisper-release-notes-v$($Metadata.Version).md"
    [IO.File]::WriteAllText($notesPath, ($lines -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
    return $notesPath
}

function Publish-GitHubDraft {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Metadata,
        [Parameter(Mandatory)][string]$NotesPath,
        [Parameter(Mandatory)][string[]]$ArtifactFiles
    )

    if ($SkipGitHub) { return }

    Write-Section 'GitHub Release 草稿'
    $tag = "v$($Metadata.Version)"
    $view = Invoke-CommandResult -Command 'gh' -Arguments @(
        'release', 'view', $tag,
        '--json', 'isDraft,isPrerelease,url',
        '--repo', $script:ReleaseConfig.GitHubRepository
    )

    if ($view.ExitCode -eq 0) {
        $release = ($view.Output -join "`n") | ConvertFrom-Json
        if (-not $release.isDraft) {
            throw "GitHub Release $tag is already public and will not be overwritten."
        }
        if ([bool]$release.isPrerelease -ne [bool]$PreRelease) {
            throw "GitHub draft prerelease state differs. Resume with the original -PreRelease setting."
        }
        Invoke-StreamingCommand -Command 'gh' -Arguments @(
            'release', 'edit', $tag,
            '--title', $Metadata.Title,
            '--notes-file', $NotesPath,
            '--repo', $script:ReleaseConfig.GitHubRepository
        )
    }
    else {
        $errorText = $view.Output -join "`n"
        if ($errorText -notmatch '(?i)release not found|HTTP 404') {
            throw "Could not inspect GitHub Release ${tag}:`n$errorText"
        }

        $arguments = @(
            'release', 'create', $tag,
            '--verify-tag',
            '--title', $Metadata.Title,
            '--notes-file', $NotesPath,
            '--draft',
            '--repo', $script:ReleaseConfig.GitHubRepository
        )
        if ($PreRelease) { $arguments += '--prerelease' }
        Invoke-StreamingCommand -Command 'gh' -Arguments $arguments
    }

    $uploadArguments = @('release', 'upload', $tag) + $ArtifactFiles + @(
        '--clobber', '--repo', $script:ReleaseConfig.GitHubRepository
    )
    Invoke-StreamingCommand -Command 'gh' -Arguments $uploadArguments
    Write-Success 'GitHub Release 资产已上传到草稿。'
}

function Publish-GitHubRelease {
    param([Parameter(Mandatory)][string]$Version)

    if ($SkipGitHub -or $Draft) { return }
    Invoke-StreamingCommand -Command 'gh' -Arguments @(
        'release', 'edit', "v$Version",
        '--draft=false',
        '--repo', $script:ReleaseConfig.GitHubRepository
    )
    Write-Success "GitHub Release v$Version 已公开。"
}

function Get-BitifulCdnRefreshUrls {
    return @(
        "$($script:ReleaseConfig.Domain)/version.json",
        "$($script:ReleaseConfig.Domain)/Windows/latest.exe",
        "$($script:ReleaseConfig.Domain)/Android/latest.apk"
    )
}

function Refresh-BitifulCdnCache {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Version)

    Write-Section '刷新 Bitiful CDN 缓存'
    $urls = @(Get-BitifulCdnRefreshUrls)
    $body = @{
        type     = 'url'
        url_list = $urls
    } | ConvertTo-Json -Compress

    try {
        $refreshParameters = @{
            Method      = 'Post'
            Uri         = $script:ReleaseConfig.CdnRefreshApi
            Headers     = @{ Authorization = $env:BITIFUL_API_TOKEN }
            ContentType = 'application/json'
            Body        = $body
        }
        $response = Invoke-RestMethod @refreshParameters
    }
    catch {
        throw "Bitiful CDN cache refresh failed: $($_.Exception.Message)"
    }

    if ([string]$response.message -cne 'ok') {
        throw "Bitiful CDN cache refresh returned an unexpected response: $($response | ConvertTo-Json -Compress)"
    }

    for ($attempt = 1; $attempt -le 10; $attempt++) {
        Start-Sleep -Seconds 2
        try {
            $nonce = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            $verificationParameters = @{
                Uri     = "$($script:ReleaseConfig.Domain)/version.json?release_verify=$nonce"
                Headers = @{ 'Cache-Control' = 'no-cache' }
            }
            $onlineManifest = Invoke-RestMethod @verificationParameters
            if ([string]$onlineManifest.latestVersion -ceq $Version) {
                Write-Success "CDN 已返回 v$Version，缓存刷新生效。"
                return
            }
        }
        catch {
            if ($attempt -eq 10) {
                throw "Could not verify the refreshed CDN manifest: $($_.Exception.Message)"
            }
        }
    }

    throw "Bitiful CDN did not expose version $Version after the cache refresh."
}

function Publish-R2Artifacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Artifacts,
        [Parameter(Mandatory)][string]$Version
    )

    if ($SkipR2) { return }

    Write-Section 'R2/S3 版本化产物'
    $remoteRoot = "$($script:ReleaseConfig.R2Remote):$($script:ReleaseConfig.BucketName)"
    if ($Platform -in @('all', 'windows')) {
        Invoke-StreamingCommand -Command 'rclone' -Arguments @(
            'copyto', $Artifacts.WindowsZip, "$remoteRoot/Windows/$([IO.Path]::GetFileName($Artifacts.WindowsZip))", '--progress'
        )
        Invoke-StreamingCommand -Command 'rclone' -Arguments @(
            'copyto', $Artifacts.WindowsExe, "$remoteRoot/Windows/$([IO.Path]::GetFileName($Artifacts.WindowsExe))", '--progress'
        )
    }
    if ($Platform -in @('all', 'android')) {
        Invoke-StreamingCommand -Command 'rclone' -Arguments @(
            'copyto', $Artifacts.AndroidApk, "$remoteRoot/Android/$([IO.Path]::GetFileName($Artifacts.AndroidApk))", '--progress'
        )
    }

    if ($PreRelease -or $Draft) {
        Write-WarningMessage '预发布/草稿：未修改 latest 文件和 version.json。'
        return
    }

    Write-Section '切换 R2/S3 稳定通道'
    Invoke-StreamingCommand -Command 'rclone' -Arguments @(
        'copyto', $Artifacts.WindowsExe, "$remoteRoot/Windows/latest.exe", '--progress'
    )
    Invoke-StreamingCommand -Command 'rclone' -Arguments @(
        'copyto', $Artifacts.AndroidApk, "$remoteRoot/Android/latest.apk", '--progress'
    )

    Write-Info '最后发布客户端 version.json...'
    Invoke-StreamingCommand -Command 'rclone' -Arguments @(
        'copyto', $script:VersionFilePath, "$remoteRoot/version.json", '--progress'
    )
    Refresh-BitifulCdnCache -Version $Version
    Write-Success "R2/S3 稳定通道已切换到 v$Version。"
}

function Undo-UncommittedVersionChanges {
    param([Parameter(Mandatory)][object[]]$Backups)

    $paths = @(
        'releases/version.json',
        'paper_whisper_flutter/pubspec.yaml',
        'paper_whisper_flutter/assets/version.json'
    )
    $result = Invoke-CommandResult -Command 'git' -Arguments (@('restore', '--staged', '--') + $paths)
    if ($result.ExitCode -ne 0) {
        Write-WarningMessage 'Could not unstage version files during rollback.'
    }
    Restore-VersionFiles -Backups $Backups
    Write-WarningMessage 'Uncommitted version-file changes were restored.'
}

function Show-Preview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FromTag,
        [Parameter(Mandatory)][string]$SuggestedVersion,
        [Parameter(Mandatory)][object[]]$Commits
    )

    Write-Section '发布预览（仅本地）'
    Write-Host "基线 tag：         $FromTag"
    Write-Host "建议版本：         v$SuggestedVersion"
    Write-Host "提交总数：         $($Commits.Count)"
    Write-Host "纳入草稿：         $(@($Commits | Where-Object Include).Count)"
    Write-Host ''
    Write-Host (New-ReleaseDraft -Version $SuggestedVersion -Commits $Commits)
}

function Invoke-ReleaseMain {
    $versionBackups = $null
    $initialHead = $null
    $notesPath = $null

    try {
        $manifest = Get-VersionManifest

        if ($Preview) {
            $previewBaseTag = Get-ReleaseBaseTag -RequestedTag $BaseTag -ManifestVersion ([string]$manifest.latestVersion)
            $previewCommits = @(Get-ReleaseCommits -FromTag $previewBaseTag)
            $previewVersion = Get-SuggestedVersion -BaseVersion ([string]$manifest.latestVersion) -Commits $previewCommits
            Show-Preview -FromTag $previewBaseTag -SuggestedVersion $previewVersion -Commits $previewCommits
            return
        }

        Assert-RepositoryReady -ResumeRelease:$Resume -ResumeVersion ([string]$manifest.latestVersion)
        Assert-ReleasePrerequisites
        $initialHead = Get-HeadCommit

        $baseParameters = @{
            RequestedTag    = $BaseTag
            ResumeRelease   = $Resume
            ManifestVersion = [string]$manifest.latestVersion
        }
        $base = Get-ReleaseBaseTag @baseParameters
        $baseVersion = (ConvertTo-SemVer $base).Text
        $commits = @(Get-ReleaseCommits -FromTag $base)
        $manifestVersion = (ConvertTo-SemVer ([string]$manifest.latestVersion)).Text
        $suggestedVersion = Get-SuggestedVersion -BaseVersion $manifestVersion -Commits $commits

        if (-not $Resume -and -not $BaseTag -and $manifestVersion -ne $baseVersion) {
            throw "Manifest version $($manifest.latestVersion) must match latest release tag $base before starting a new release."
        }
        if (-not $Resume -and -not (Test-LocalTagExists "v$manifestVersion")) {
            throw "Manifest version tag is missing: v$manifestVersion"
        }
        if (-not $Resume -and -not (Test-GitAncestor -Ancestor "v$manifestVersion" -Descendant 'HEAD')) {
            throw "Manifest version tag v$manifestVersion is not an ancestor of HEAD."
        }

        $metadataParameters = @{
            Manifest         = $manifest
            BaselineVersion  = $manifestVersion
            SuggestedVersion = $suggestedVersion
            ResumeRelease    = $Resume
        }
        $metadata = Get-InteractiveReleaseMetadata @metadataParameters

        $targetTag = "v$($metadata.Version)"
        if (-not $Resume -and (Test-LocalTagExists $targetTag)) {
            throw "Target tag already exists: $targetTag"
        }

        $initialDraft = if ($Resume) {
            $resumeLines = @('## 更新内容') + @($manifest.changelog | ForEach-Object { "- $_" })
            ($resumeLines -join "`n") + "`n"
        }
        else {
            New-ReleaseDraft -Version $metadata.Version -Commits $commits
        }
        $finalDraft = Edit-ReleaseDraft -Version $metadata.Version -InitialDraft $initialDraft
        $changelog = @(ConvertFrom-ReleaseDraft -Markdown $finalDraft)

        $includedCommitCount = @($commits | Where-Object Include).Count
        $confirmationParameters = @{
            Metadata            = $metadata
            FromTag             = $base
            IncludedCommitCount = $includedCommitCount
            SelectedPlatform    = $Platform
        }
        Confirm-Release @confirmationParameters

        Assert-PublishCredentials
        $versionBackups = @(Backup-VersionFiles)

        if (-not $Resume) {
            Write-VersionManifest -Metadata $metadata -Changelog $changelog -ExistingManifest $manifest
        }
        Sync-AndVerifyVersionFiles -Metadata $metadata
        Invoke-QualityChecks

        $artifacts = Get-ArtifactSet -Version $metadata.Version
        Build-ReleaseArtifacts -Version $metadata.Version -Artifacts $artifacts
        $artifactFiles = @(Get-SelectedArtifactFiles -Artifacts $artifacts)

        [void](Publish-GitState -Version $metadata.Version -ResumeRelease:$Resume)
        $notesPath = New-ReleaseNotesFile -Metadata $metadata -DraftMarkdown $finalDraft -Artifacts $artifacts
        Publish-GitHubDraft -Metadata $metadata -NotesPath $notesPath -ArtifactFiles $artifactFiles
        Publish-R2Artifacts -Artifacts $artifacts -Version $metadata.Version
        Publish-GitHubRelease -Version $metadata.Version

        Write-Section '发布完成'
        Write-Success "PaperWhisper v$($metadata.Version) 发布成功。"
        if (-not $SkipGitHub) {
            Write-Info "GitHub: https://github.com/$($script:ReleaseConfig.GitHubRepository)/releases/tag/v$($metadata.Version)"
        }
        if (-not $SkipR2 -and -not $PreRelease -and -not $Draft) {
            Write-Info "Windows: $($script:ReleaseConfig.Domain)/Windows/latest.exe"
            Write-Info "Android: $($script:ReleaseConfig.Domain)/Android/latest.apk"
        }
    }
    catch {
        if ($versionBackups -and $initialHead) {
            $currentHead = Get-HeadCommit
            if ($currentHead -eq $initialHead) {
                Undo-UncommittedVersionChanges -Backups $versionBackups
            }
            else {
                Write-WarningMessage 'The release commit exists; Git history was not rewritten. Resume with -Resume.'
            }
        }
        throw
    }
    finally {
        if ($notesPath) {
            Remove-Item $notesPath -Force -ErrorAction SilentlyContinue
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-ReleaseMain
        exit 0
    }
    catch {
        Write-Host ''
        Write-Host "发布失败：$($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
