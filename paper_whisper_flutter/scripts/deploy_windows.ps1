#Requires -Version 7.0

$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$releaseScript = Join-Path $repositoryRoot 'scripts/release.ps1'

Write-Warning 'This compatibility entry now delegates to the full dual-platform release workflow.'
& $releaseScript
