Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Bitmap]::FromFile('assets\icon.png')
$color = $img.GetPixel(0, 0)
Write-Output "#$($color.R.ToString('X2'))$($color.G.ToString('X2'))$($color.B.ToString('X2'))"
$img.Dispose()
