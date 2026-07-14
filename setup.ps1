# AYA Android Manager 一键部署脚本 (PowerShell)
# 用法: .\setup.ps1
# 功能: 安装依赖、下载ADB/scrcpy、构建server、构建前端、启动应用

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AYA Android Manager 一键部署脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 清除可能影响 Electron 的环境变量
Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue

# ========================================
# 步骤 1: 安装 npm 依赖
# ========================================
Write-Host "[1/7] 安装 npm 依赖..." -ForegroundColor Yellow
Push-Location $ProjectRoot
npm install --no-fund --no-audit --legacy-peer-deps
if ($LASTEXITCODE -ne 0) {
    Write-Host "npm install 失败!" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location
Write-Host "npm 依赖安装完成。" -ForegroundColor Green
Write-Host ""

# ========================================
# 步骤 2: 下载 ADB 工具
# ========================================
Write-Host "[2/7] 下载 ADB 工具..." -ForegroundColor Yellow
$adbDir = "$ProjectRoot\resources\adb"
if (Test-Path "$adbDir\adb.exe") {
    Write-Host "ADB 已存在，跳过。" -ForegroundColor Green
} else {
    if (-not (Test-Path $adbDir)) {
        New-Item -ItemType Directory -Path $adbDir -Force | Out-Null
    }
    $zipPath = "$adbDir\platform-tools-latest-windows.zip"
    Write-Host "正在下载 platform-tools..."
    Invoke-WebRequest -Uri "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -OutFile $zipPath -UseBasicParsing
    Write-Host "正在解压..."
    Expand-Archive -Path $zipPath -DestinationPath $adbDir -Force
    Copy-Item "$adbDir\platform-tools\adb.exe" "$adbDir\adb.exe" -Force
    Copy-Item "$adbDir\platform-tools\AdbWinApi.dll" "$adbDir\AdbWinApi.dll" -Force
    Copy-Item "$adbDir\platform-tools\AdbWinUsbApi.dll" "$adbDir\AdbWinUsbApi.dll" -Force
    Remove-Item "$adbDir\platform-tools" -Recurse -Force
    Remove-Item $zipPath -Force
    Write-Host "ADB 工具下载完成。" -ForegroundColor Green
}
Write-Host ""

# ========================================
# 步骤 3: 下载 scrcpy-server
# ========================================
Write-Host "[3/7] 下载 scrcpy-server..." -ForegroundColor Yellow
$scrcpyPath = "$ProjectRoot\resources\scrcpy.jar"
if (Test-Path $scrcpyPath) {
    Write-Host "scrcpy-server 已存在，跳过。" -ForegroundColor Green
} else {
    Invoke-WebRequest -Uri "https://github.com/Genymobile/scrcpy/releases/download/v3.1/scrcpy-server-v3.1" -OutFile $scrcpyPath -UseBasicParsing
    Write-Host "scrcpy-server 下载完成。" -ForegroundColor Green
}
Write-Host ""

# ========================================
# 步骤 4: 构建 Server (Java/Gradle)
# ========================================
Write-Host "[4/7] 构建 Server (Java/Gradle)..." -ForegroundColor Yellow
$ayaDexPath = "$ProjectRoot\resources\aya.dex"
if (Test-Path $ayaDexPath) {
    Write-Host "aya.dex 已存在，跳过。" -ForegroundColor Green
} else {
    # 查找 JDK 21
    $javaHome = $null
    $jdk21Path = "C:\Program Files\Java\latest\jdk-21"
    if (Test-Path "$jdk21Path\bin\java.exe") {
        $javaHome = $jdk21Path
    } else {
        # 尝试查找其他 JDK
        $javaCmd = Get-Command java -ErrorAction SilentlyContinue
        if ($javaCmd) {
            $javaVersion = & java -version 2>&1 | Select-String "version"
            if ($javaVersion -match "version ""(\d+)") {
                $majorVersion = [int]$Matches[1]
                if ($majorVersion -le 21) {
                    $javaHome = (Split-Path (Split-Path $javaCmd.Source))
                }
            }
        }
    }

    if ($javaHome) {
        Write-Host "使用 JDK: $javaHome"
        $env:JAVA_HOME = $javaHome
        $env:PATH = "$javaHome\bin;$env:PATH"
        $env:ANDROID_HOME = "C:\Android\Sdk"

        Push-Location "$ProjectRoot\server"
        & .\gradlew.bat :server:assembleRelease --init-script init.gradle 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Server 构建失败! 请确保已安装 JDK 21 和 Android SDK。" -ForegroundColor Red
            Write-Host "可以跳过此步骤，应用仍可启动但设备端功能不可用。" -ForegroundColor Yellow
        } else {
            # 移动 aya.dex
            if (Test-Path "$ProjectRoot\server\aya.dex") {
                Move-Item "$ProjectRoot\server\aya.dex" $ayaDexPath -Force
                Write-Host "Server 构建完成。" -ForegroundColor Green
            }
        }
        Pop-Location
    } else {
        Write-Host "未找到合适的 JDK，跳过 Server 构建。" -ForegroundColor Yellow
        Write-Host "请安装 JDK 21 后运行: cd server; .\gradlew.bat :server:assembleRelease --init-script init.gradle" -ForegroundColor Yellow
    }
}
Write-Host ""

# ========================================
# 步骤 5: 构建前端 (main + preload + renderer)
# ========================================
Write-Host "[5/7] 构建前端..." -ForegroundColor Yellow
Push-Location $ProjectRoot

Write-Host "  构建主进程..."
npm run build:main
if ($LASTEXITCODE -ne 0) { Write-Host "主进程构建失败!" -ForegroundColor Red; Pop-Location; exit 1 }

Write-Host "  构建 Preload..."
npm run build:preload
if ($LASTEXITCODE -ne 0) { Write-Host "Preload 构建失败!" -ForegroundColor Red; Pop-Location; exit 1 }

Write-Host "  构建渲染进程..."
npm run build:renderer
if ($LASTEXITCODE -ne 0) { Write-Host "渲染进程构建失败!" -ForegroundColor Red; Pop-Location; exit 1 }

Pop-Location

# 复制资源文件到 dist/resources (生产模式下 resolveResources 从 dist/resources 加载)
Write-Host "  复制资源文件到 dist..."
if (Test-Path "$ProjectRoot\resources") {
    Copy-Item -Path "$ProjectRoot\resources" -Destination "$ProjectRoot\dist\resources" -Recurse -Force
}

Write-Host "前端构建完成。" -ForegroundColor Green
Write-Host ""

# ========================================
# 步骤 6: 验证资源文件
# ========================================
Write-Host "[6/7] 验证资源文件..." -ForegroundColor Yellow
$allOk = $true
if (Test-Path "$ProjectRoot\resources\adb\adb.exe") {
    Write-Host "  [OK] ADB 工具" -ForegroundColor Green
} else {
    Write-Host "  [缺失] ADB 工具" -ForegroundColor Red
    $allOk = $false
}
if (Test-Path "$ProjectRoot\resources\scrcpy.jar") {
    Write-Host "  [OK] scrcpy-server" -ForegroundColor Green
} else {
    Write-Host "  [缺失] scrcpy-server" -ForegroundColor Red
    $allOk = $false
}
if (Test-Path "$ProjectRoot\resources\aya.dex") {
    Write-Host "  [OK] aya.dex" -ForegroundColor Green
} else {
    Write-Host "  [缺失] aya.dex" -ForegroundColor Yellow
}
if (Test-Path "$ProjectRoot\dist\main\index.js") {
    Write-Host "  [OK] 主进程构建产物" -ForegroundColor Green
} else {
    Write-Host "  [缺失] 主进程构建产物" -ForegroundColor Red
    $allOk = $false
}
if (Test-Path "$ProjectRoot\dist\preload\index.js") {
    Write-Host "  [OK] Preload 构建产物" -ForegroundColor Green
} else {
    Write-Host "  [缺失] Preload 构建产物" -ForegroundColor Red
    $allOk = $false
}
if (Test-Path "$ProjectRoot\dist\renderer\index.html") {
    Write-Host "  [OK] 渲染进程构建产物" -ForegroundColor Green
} else {
    Write-Host "  [缺失] 渲染进程构建产物" -ForegroundColor Red
    $allOk = $false
}
Write-Host ""

# ========================================
# 步骤 7: 启动应用
# ========================================
Write-Host "[7/7] 启动 AYA 应用..." -ForegroundColor Yellow
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  应用正在启动..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
& "$ProjectRoot\node_modules\electron\dist\electron.exe" $ProjectRoot
