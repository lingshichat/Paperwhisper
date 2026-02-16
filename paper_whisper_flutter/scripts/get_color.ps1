Add-Type -AssemblyName System.Drawing

# 获取脚本所在目录，然后定位到项目根目录的 assets
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$IconPath = Join-Path $ScriptDir "..\assets\icon.png"

$img = [System.Drawing.Bitmap]::FromFile($IconPath)
$color = $img.GetPixel(0, 0)
Write-Output "#$($color.R.ToString('X2'))$($color.G.ToString('X2'))$($color.B.ToString('X2'))"
$img.Dispose()
