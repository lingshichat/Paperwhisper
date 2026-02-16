# PowerShell 脚本: 配置缤纷云 (Bitiful) Rclone
$ErrorActionPreference = "Stop"

Write-Host "🔧 正在配置缤纷云 (Bitiful) Rclone..." -ForegroundColor Cyan
Write-Host "请参考缤纷云控制台获取 Access Key 和 Secret Key。" -ForegroundColor Gray
Write-Host ""

# 1. 获取用户输入
$AccessKey = Read-Host "请输入 Access Key"
$SecretKey = Read-Host "请输入 Secret Key"

if ([string]::IsNullOrWhiteSpace($AccessKey) -or [string]::IsNullOrWhiteSpace($SecretKey)) {
    Write-Error "❌ Access Key 或 Secret Key 不能为空！"
}

# 2. 配置 Rclone
# 使用非交互模式创建配置
# type=s3, provider=Other, endpoint=s3.bitiful.net, region=cn-east-1
$RemoteName = "bitiful"

Write-Host "正在创建配置 '$RemoteName'..." -ForegroundColor Cyan

# 检查 rclone 是否存在
if (-not (Get-Command "rclone" -ErrorAction SilentlyContinue)) {
    Write-Error "❌ 未找到 rclone 命令，请先安装 rclone 并添加到 PATH。"
}

# 运行配置命令
# 注意：这就如同运行 rclone config create bitiful s3 ...
try {
    rclone config create $RemoteName s3 `
        provider Other `
        env_auth false `
        access_key_id $AccessKey `
        secret_access_key $SecretKey `
        region cn-east-1 `
        endpoint s3.bitiful.net `
        acl public-read

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Rclone 配置成功！" -ForegroundColor Green
        Write-Host "正在测试连接..." -ForegroundColor Cyan
        rclone lsd "$RemoteName`:"
        Write-Host ""
        Write-Host "🎉 配置完成！现在你可以使用 ./deploy_windows.ps1 进行部署了。" -ForegroundColor Green
    } else {
        Write-Error "❌ Rclone 配置失败，请检查错误信息。"
    }
} catch {
    Write-Error "❌ 执行出错: $_"
}
