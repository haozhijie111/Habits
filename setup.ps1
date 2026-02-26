# Flutter 环境自动安装 + 项目初始化脚本
# 使用方法：右键 -> 用 PowerShell 运行（或在 PowerShell 中执行）

$ErrorActionPreference = "Stop"
$FlutterDir = "D:\flutter"
$ProjectDir = "D:\工作学习\Habits\Habits"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  笛子练习 App - 环境安装脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ── 步骤 1：下载 Flutter SDK ──────────────────────────────────────────────────
if (-not (Test-Path "$FlutterDir\bin\flutter.bat")) {
    Write-Host "`n[1/5] 下载 Flutter SDK（约 1.2GB，请耐心等待）..." -ForegroundColor Yellow

    $url = "https://storage.flutter-io.cn/flutter_infra_release/releases/stable/windows/flutter_windows_3.27.1-stable.zip"
    $zip = "D:\flutter_sdk.zip"

    # 使用 BITS 后台下载，支持断点续传
    Start-BitsTransfer -Source $url -Destination $zip -DisplayName "Flutter SDK"

    Write-Host "[1/5] 解压中..." -ForegroundColor Yellow
    Expand-Archive -Path $zip -DestinationPath "D:\" -Force
    Remove-Item $zip
    Write-Host "[1/5] Flutter SDK 安装完成" -ForegroundColor Green
} else {
    Write-Host "[1/5] Flutter SDK 已存在，跳过下载" -ForegroundColor Green
}

# ── 步骤 2：添加 Flutter 到 PATH ──────────────────────────────────────────────
$flutterBin = "$FlutterDir\bin"
$currentPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentPath -notlike "*$flutterBin*") {
    [System.Environment]::SetEnvironmentVariable("PATH", "$currentPath;$flutterBin", "User")
    Write-Host "[2/5] Flutter 已添加到用户 PATH" -ForegroundColor Green
} else {
    Write-Host "[2/5] PATH 已包含 Flutter，跳过" -ForegroundColor Green
}
$env:PATH += ";$flutterBin"

# ── 步骤 3：初始化完整 Flutter 项目脚手架 ────────────────────────────────────
Write-Host "`n[3/5] 初始化 Flutter 项目脚手架..." -ForegroundColor Yellow

$tempDir = "D:\flute_temp"
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }

& "$flutterBin\flutter.bat" create flute_temp `
    --org com.fluteapp `
    --project-name flute_practice `
    --platforms android `
    -t app `
    --no-pub `
    --directory $tempDir

Write-Host "[3/5] 脚手架创建完成" -ForegroundColor Green

# ── 步骤 4：合并脚手架到项目目录 ─────────────────────────────────────────────
Write-Host "`n[4/5] 合并项目文件..." -ForegroundColor Yellow

# 复制 android 完整目录（保留我们的 AndroidManifest.xml）
$ourManifest = "$ProjectDir\android\app\src\main\AndroidManifest.xml"
Copy-Item "$tempDir\android" "$ProjectDir\android" -Recurse -Force
# 还原我们的 AndroidManifest
Copy-Item $ourManifest "$ProjectDir\android\app\src\main\AndroidManifest.xml" -Force

# 复制其他必要文件
foreach ($item in @("gradle", ".gradle")) {
    $src = "$tempDir\$item"
    if (Test-Path $src) {
        Copy-Item $src "$ProjectDir\$item" -Recurse -Force
    }
}

# 复制 gradle wrapper
Copy-Item "$tempDir\android\gradle" "$ProjectDir\android\gradle" -Recurse -Force

Remove-Item $tempDir -Recurse -Force
Write-Host "[4/5] 文件合并完成" -ForegroundColor Green

# ── 步骤 5：安装依赖 ──────────────────────────────────────────────────────────
Write-Host "`n[5/5] 安装 pub 依赖..." -ForegroundColor Yellow
Set-Location $ProjectDir
& "$flutterBin\flutter.bat" pub get

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  安装完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "下一步：" -ForegroundColor White
Write-Host "  1. 连接 Android 手机，开启 USB 调试" -ForegroundColor White
Write-Host "  2. 在此目录运行：" -ForegroundColor White
Write-Host "     D:\flutter\bin\flutter.bat devices" -ForegroundColor Yellow
Write-Host "     D:\flutter\bin\flutter.bat run" -ForegroundColor Yellow
Write-Host ""
