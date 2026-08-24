#!/usr/bin/env pwsh
#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'release.ps1')

$script:Passed = 0
$script:Failed = 0

function Assert-Equal {
    param(
        [Parameter(Mandatory)]$Actual,
        [Parameter(Mandatory)]$Expected
    )

    if ($Actual -cne $Expected) {
        throw "Expected '$Expected', got '$Actual'."
    }
}

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition)
    if (-not $Condition) { throw 'Expected condition to be true.' }
}

function Assert-False {
    param([Parameter(Mandatory)][bool]$Condition)
    if ($Condition) { throw 'Expected condition to be false.' }
}

function Assert-SequenceEqual {
    param(
        [Parameter(Mandatory)][object[]]$Actual,
        [Parameter(Mandatory)][object[]]$Expected
    )

    if ($Actual.Count -ne $Expected.Count) {
        throw "Expected $($Expected.Count) items, got $($Actual.Count)."
    }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ($Actual[$index] -cne $Expected[$index]) {
            throw "Item $index expected '$($Expected[$index])', got '$($Actual[$index])'."
        }
    }
}

function Assert-Throws {
    param([Parameter(Mandatory)][scriptblock]$Action)

    try {
        & $Action
    }
    catch {
        return
    }
    throw 'Expected action to throw.'
}

function Invoke-TestCase {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Test
    )

    try {
        & $Test
        $script:Passed++
        Write-Host "PASS $Name" -ForegroundColor Green
    }
    catch {
        $script:Failed++
        Write-Host "FAIL $Name`n  $($_.Exception.Message)" -ForegroundColor Red
    }
}

function New-TestCommit {
    param(
        [Parameter(Mandatory)][string]$Hash,
        [Parameter(Mandatory)][string]$Subject
    )

    return ConvertTo-ReleaseCommit -Hash $Hash -ShortHash $Hash.Substring(0, 7) -Subject $Subject
}

Invoke-TestCase 'classifies user-facing conventional commits' {
    $feature = New-TestCommit -Hash '1111111111111111111111111111111111111111' -Subject 'feat(editor): add focus mode'
    $fix = New-TestCommit -Hash '2222222222222222222222222222222222222222' -Subject 'fix(sync): preserve remote entries'
    $performance = New-TestCommit -Hash '3333333333333333333333333333333333333333' -Subject 'perf(ui): reduce first paint work'

    Assert-True $feature.Include
    Assert-Equal $feature.Category '新增功能'
    Assert-True $fix.Include
    Assert-Equal $fix.Category '问题修复'
    Assert-True $performance.Include
    Assert-Equal $performance.Category '性能优化'
}

Invoke-TestCase 'filters internal commit types and scopes' {
    $docs = New-TestCommit -Hash '1111111111111111111111111111111111111111' -Subject 'docs(readme): update release docs'
    $refactor = New-TestCommit -Hash '2222222222222222222222222222222222222222' -Subject 'refactor(core): move service'
    $trellisFeature = New-TestCommit -Hash '3333333333333333333333333333333333333333' -Subject 'feat(trellis): add workflow helper'
    $flutterUpgrade = New-TestCommit -Hash '4444444444444444444444444444444444444444' -Subject 'feat(flutter): upgrade framework version'
    $releaseScript = New-TestCommit -Hash '5555555555555555555555555555555555555555' -Subject '完善发布脚本'
    $qualityBaseline = New-TestCommit -Hash '6666666666666666666666666666666666666666' -Subject 'fix(test): restore strict quality baseline'

    Assert-False $docs.Include
    Assert-False $refactor.Include
    Assert-False $trellisFeature.Include
    Assert-False $flutterUpgrade.Include
    Assert-False $releaseScript.Include
    Assert-False $qualityBaseline.Include
}

Invoke-TestCase 'keeps non-conventional commits as other updates' {
    $commit = New-TestCommit -Hash '1111111111111111111111111111111111111111' -Subject '新增随心记日历视图'
    Assert-True $commit.Include
    Assert-Equal $commit.Category '其他更新'
    Assert-Equal $commit.Subject '新增随心记日历视图'
}

Invoke-TestCase 'suggests semantic versions from commit impact' {
    $feature = New-TestCommit -Hash '1111111111111111111111111111111111111111' -Subject 'feat(editor): add focus mode'
    $fix = New-TestCommit -Hash '2222222222222222222222222222222222222222' -Subject 'fix(sync): preserve remote entries'
    $breaking = New-TestCommit -Hash '3333333333333333333333333333333333333333' -Subject 'feat(core)!: replace storage format'

    Assert-Equal (Get-SuggestedVersion -BaseVersion '1.5.8' -Commits @($feature, $fix)) '1.6.0'
    Assert-Equal (Get-SuggestedVersion -BaseVersion '1.5.8' -Commits @($fix)) '1.5.9'
    Assert-Equal (Get-SuggestedVersion -BaseVersion '1.5.8' -Commits @($breaking)) '2.0.0'
}

Invoke-TestCase 'converts edited Markdown to client changelog entries' {
    $markdown = @'
## 新增功能
- add focus mode <!-- commit: 1111111 -->
- 新增简化动效

## 问题修复
- 修复：keep remote entries <!-- commit: 2222222 -->
- 修复日期崩溃

## 体验优化
- 优化启动速度

## 自定义分组
- migration note
'@
    $actual = @(ConvertFrom-ReleaseDraft -Markdown $markdown)
    $expected = @(
        '新增：add focus mode',
        '新增：简化动效',
        '修复：keep remote entries',
        '修复：日期崩溃',
        '优化：启动速度',
        '自定义分组：migration note'
    )
    Assert-SequenceEqual -Actual $actual -Expected $expected
}

Invoke-TestCase 'builds the stable client CDN refresh URL set' {
    $actual = @(Get-BitifulCdnRefreshUrls)
    $expected = @(
        'https://pwdl.lingshichat.cn/version.json',
        'https://pwdl.lingshichat.cn/Windows/latest.exe',
        'https://pwdl.lingshichat.cn/Android/latest.apk'
    )
    Assert-SequenceEqual -Actual $actual -Expected $expected
}

Invoke-TestCase 'requires at least one Markdown list item' {
    Assert-Throws { ConvertFrom-ReleaseDraft -Markdown '## Empty' }
}

Invoke-TestCase 'validates version ordering' {
    Assert-Equal (Compare-SemVer -Left '1.6.0' -Right '1.5.8') 1
    Assert-Equal (Compare-SemVer -Left '1.5.8' -Right '1.5.8') 0
    Assert-Equal (Compare-SemVer -Left '1.5.7' -Right '1.5.8') -1
    Assert-Throws { Assert-VersionIsNewer -Candidate '1.5.8' -Baseline '1.5.8' }
}

Invoke-TestCase 'requires exact case-sensitive release confirmation' {
    Assert-True (Test-ReleaseConfirmation -InputText 'RELEASE v1.6.0' -Version '1.6.0')
    Assert-False (Test-ReleaseConfirmation -InputText 'release v1.6.0' -Version '1.6.0')
    Assert-False (Test-ReleaseConfirmation -InputText 'RELEASE v1.6.0 ' -Version '1.6.0')
}

Invoke-TestCase 'accepts only synchronized or one-commit resume repository state' {
    Assert-True (Test-RepositoryHeadAllowed -LocalHead 'aaa' -RemoteHead 'aaa')
    Assert-True (Test-RepositoryHeadAllowed `
        -LocalHead 'bbb' `
        -RemoteHead 'aaa' `
        -ResumeRelease `
        -LocalParent 'aaa' `
        -LocalSubject 'chore(release): v1.6.0' `
        -ResumeVersion '1.6.0')
    Assert-False (Test-RepositoryHeadAllowed `
        -LocalHead 'bbb' `
        -RemoteHead 'aaa' `
        -ResumeRelease `
        -LocalParent 'aaa' `
        -LocalSubject 'feat: unrelated change' `
        -ResumeVersion '1.6.0')
    Assert-False (Test-RepositoryHeadAllowed `
        -LocalHead 'bbb' `
        -RemoteHead 'aaa' `
        -LocalParent 'aaa' `
        -LocalSubject 'chore(release): v1.6.0' `
        -ResumeVersion '1.6.0')
}

Invoke-TestCase 'derives the GitHub repository from HTTPS and SSH origins' {
    Assert-Equal (ConvertFrom-GitHubRemoteUrl 'https://github.com/lingshichat/Paperwhisper.git') 'lingshichat/Paperwhisper'
    Assert-Equal (ConvertFrom-GitHubRemoteUrl 'git@github.com:lingshichat/Paperwhisper.git') 'lingshichat/Paperwhisper'
    Assert-Throws { ConvertFrom-GitHubRemoteUrl 'https://example.com/lingshichat/Paperwhisper.git' }
}

Invoke-TestCase 'writes complete client-compatible version metadata' {
    $originalVersionPath = $script:VersionFilePath
    $temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) "paperwhisper-release-test-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null
    try {
        $script:VersionFilePath = Join-Path $temporaryDirectory 'version.json'
        $metadata = [PSCustomObject]@{
            Version       = '1.6.0'
            BuildNumber   = 19
            ReleaseDate   = '2026-08-24'
            Title         = '纸语 1.6.0'
            IsForceUpdate = $false
        }
        $existing = [PSCustomObject]@{ minSupportedVersion = '1.0.0' }
        Write-VersionManifest -Metadata $metadata -Changelog @('新增：focus mode') -ExistingManifest $existing

        $manifest = Get-Content $script:VersionFilePath -Raw -Encoding utf8 | ConvertFrom-Json
        Assert-Equal $manifest.latestVersion '1.6.0'
        Assert-Equal $manifest.latestBuildNumber 19
        Assert-Equal $manifest.changelog[0] '新增：focus mode'
        Assert-Equal $manifest.downloadUrl.android 'https://pwdl.lingshichat.cn/Android/latest.apk'
        Assert-Equal $manifest.downloadUrl.windows 'https://pwdl.lingshichat.cn/Windows/latest.exe'
        Assert-Equal $manifest.minSupportedVersion '1.0.0'
    }
    finally {
        $script:VersionFilePath = $originalVersionPath
        Remove-Item (Join-Path $temporaryDirectory 'version.json') -Force -ErrorAction SilentlyContinue
        Remove-Item $temporaryDirectory -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
Write-Host "Release script tests: $script:Passed passed, $script:Failed failed"
if ($script:Failed -gt 0) { exit 1 }
