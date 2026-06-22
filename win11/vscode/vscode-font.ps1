# ==============================================================================
# FiraCode Nerd Font 半自动安装脚本 (调用原生 GUI，需手动确认)
# ==============================================================================

$fontName = "FiraCode Nerd Font"
$downloadUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
$tempZip = "$env:TEMP\FiraCode.zip"
$tempExtract = "$env:TEMP\FiraCode_NF"

Write-Host "1. 开始从 GitHub 拉取 [$fontName] 资源包..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip

Write-Host "2. 下载完成，正在解压缩..." -ForegroundColor Cyan
if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
New-Item -ItemType Directory -Path $tempExtract | Out-Null
Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

# 过滤出最核心的 6 个字重（Regular, Bold, Light 等）。
# 故意排除了 Mono/Propo 等变体，防止弹出几十个确认框导致体验糟糕。
$coreFonts = Get-ChildItem -Path $tempExtract -Filter "FiraCodeNerdFont-*.ttf"

Write-Host "3. 准备唤起 Windows 原生安装程序..." -ForegroundColor Yellow
Write-Host "👉 提示：屏幕上可能会闪过几个进度条。如果系统已存在该字体，会弹出官方的覆盖确认框，请手动点击【是】。" -ForegroundColor Yellow

# 创建 Windows Shell COM 对象
$shell = New-Object -ComObject Shell.Application
$folder = $shell.Namespace($tempExtract)

# 遍历核心字体并模拟右键“安装”
foreach ($font in $coreFonts) {
    $item = $folder.ParseName($font.Name)
    # 调用 Windows 右键菜单中的原生 "Install" 动作
    $item.InvokeVerb("Install")

    # 稍微休眠半秒，给 Windows GUI 留出响应时间，防止并发弹窗卡死
    Start-Sleep -Milliseconds 500
}

Write-Host "4. 打扫战场：清理临时构建文件..." -ForegroundColor DarkGray
Remove-Item $tempZip -Force
Remove-Item $tempExtract -Recurse -Force

Write-Host "=======================================================" -ForegroundColor Green
Write-Host "🎉 脚本执行完毕！请在弹出的所有 Windows 提示框中完成确认。" -ForegroundColor Green
Write-Host "安装彻底结束后，请完全重启 VS Code 和 Windows Terminal。" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Green
