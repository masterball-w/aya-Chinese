# AYA Android Manager 启动脚本 (PowerShell)
# 用法: .\start.ps1 [build|dev|clean]

param(
    [string]$Mode = "run"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AYA Android Manager 启动脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 清除可能影响 Electron 的环境变量
Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue

switch ($Mode) {
    "clean" {
        Write-Host "[1/1] 清理构建产物..." -ForegroundColor Yellow
        if (Test-Path "$ProjectRoot\dist") {
            Remove-Item "$ProjectRoot\dist" -Recurse -Force
        }
        Write-Host "清理完成。" -ForegroundColor Green
    }
    "build" {
        Write-Host "[1/5] 构建主进程..." -ForegroundColor Yellow
        Push-Location $ProjectRoot
        npm run build:main
        if ($LASTEXITCODE -ne 0) { Write-Host "主进程构建失败!" -ForegroundColor Red; Pop-Location; exit 1 }

        Write-Host "[2/5] 构建 Preload..." -ForegroundColor Yellow
        npm run build:preload
        if ($LASTEXITCODE -ne 0) { Write-Host "Preload 构建失败!" -ForegroundColor Red; Pop-Location; exit 1 }

        Write-Host "[3/5] 构建渲染进程..." -ForegroundColor Yellow
        npm run build:renderer
        if ($LASTEXITCODE -ne 0) { Write-Host "渲染进程构建失败!" -ForegroundColor Red; Pop-Location; exit 1 }
        Pop-Location

        Write-Host "[4/5] 复制资源文件到 dist..." -ForegroundColor Yellow
        if (Test-Path "$ProjectRoot\resources") {
            Copy-Item -Path "$ProjectRoot\resources" -Destination "$ProjectRoot\dist\resources" -Recurse -Force
        }

        Write-Host "[5/5] 构建完成!" -ForegroundColor Green
    }
    "dev" {
        Write-Host "启动开发模式..." -ForegroundColor Yellow
        Push-Location $ProjectRoot
        npm run dev
        Pop-Location
    }
    "run" {
        Push-Location $ProjectRoot

        # 检查构建产物是否存在
        if (-not (Test-Path "$ProjectRoot\dist\main\index.js")) {
            Write-Host "构建产物不存在，正在构建..." -ForegroundColor Yellow
            npm run build:main
            if ($LASTEXITCODE -ne 0) { Write-Host "主进程构建失败!" -ForegroundColor Red; Pop-Location; exit 1 }
            npm run build:preload
            if ($LASTEXITCODE -ne 0) { Write-Host "Preload 构建失败!" -ForegroundColor Red; Pop-Location; exit 1 }
            npm run build:renderer
            if ($LASTEXITCODE -ne 0) { Write-Host "渲染进程构建失败!" -ForegroundColor Red; Pop-Location; exit 1 }
        }

        Pop-Location

        # 检查资源文件
        $resourcesOk = $true
        if (-not (Test-Path "$ProjectRoot\resources\adb\adb.exe")) {
            Write-Host "警告: ADB 工具不存在，请运行: npm run adb" -ForegroundColor Red
            $resourcesOk = $false
        }
        if (-not (Test-Path "$ProjectRoot\resources\scrcpy.jar")) {
            Write-Host "警告: scrcpy-server 不存在，请运行: npm run scrcpy" -ForegroundColor Red
            $resourcesOk = $false
        }
        if (-not (Test-Path "$ProjectRoot\resources\aya.dex")) {
            Write-Host "警告: aya.dex 不存在，请运行: npm run server" -ForegroundColor Red
            $resourcesOk = $false
        }

        if ($resourcesOk) {
            Write-Host "所有资源文件就绪。" -ForegroundColor Green
        } else {
            Write-Host "部分资源文件缺失，应用仍可启动但部分功能不可用。" -ForegroundColor Yellow
        }

        # 复制资源文件到 dist/resources (生产模式下 resolveResources 从 dist/resources 加载)
        Write-Host "同步资源文件到 dist..." -ForegroundColor Yellow
        if (Test-Path "$ProjectRoot\resources") {
            Copy-Item -Path "$ProjectRoot\resources" -Destination "$ProjectRoot\dist\resources" -Recurse -Force
        }

        Write-Host "正在启动 Electron..." -ForegroundColor Green
        Push-Location $ProjectRoot
        & ".\node_modules\electron\dist\electron.exe" .
        Pop-Location
    }
    default {
        Write-Host "用法: .\start.ps1 [build|dev|run|clean]" -ForegroundColor White
        Write-Host "  run    - 构建并启动应用 (默认)" -ForegroundColor White
        Write-Host "  build  - 仅构建前端" -ForegroundColor White
        Write-Host "  dev    - 开发模式 (热重载)" -ForegroundColor White
        Write-Host "  clean  - 清理构建产物" -ForegroundColor White
    }
}
