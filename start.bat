@echo off
chcp 65001 >nul 2>&1
title AYA Android Manager 启动脚本

REM ========================================
REM  AYA Android Manager 启动脚本 (Batch)
REM  用法: start.bat [build|dev|run|clean]
REM ========================================

setlocal enabledelayedexpansion
set "PROJECT_ROOT=%~dp0"
set "MODE=%1"
if "%MODE%"=="" set "MODE=run"

REM 清除可能影响 Electron 的环境变量
set "ELECTRON_RUN_AS_NODE="

echo ========================================
echo   AYA Android Manager 启动脚本
echo ========================================
echo.

if /i "%MODE%"=="clean" (
    echo [1/1] 清理构建产物...
    if exist "%PROJECT_ROOT%dist" rmdir /s /q "%PROJECT_ROOT%dist"
    echo 清理完成。
    goto :eof
)

if /i "%MODE%"=="build" (
    echo [1/5] 构建主进程...
    cd /d "%PROJECT_ROOT%"
    call npm run build:main
    if errorlevel 1 echo 主进程构建失败! & exit /b 1

    echo [2/5] 构建 Preload...
    call npm run build:preload
    if errorlevel 1 echo Preload 构建失败! & exit /b 1

    echo [3/5] 构建渲染进程...
    call npm run build:renderer
    if errorlevel 1 echo 渲染进程构建失败! & exit /b 1

    echo [4/5] 复制资源文件到 dist...
    if exist "%PROJECT_ROOT%resources" (
        xcopy "%PROJECT_ROOT%resources" "%PROJECT_ROOT%dist\resources\" /E /I /Y /Q >nul
    )

    echo [5/5] 构建完成!
    goto :eof
)

if /i "%MODE%"=="dev" (
    echo 启动开发模式...
    cd /d "%PROJECT_ROOT%"
    call npm run dev
    goto :eof
)

if /i "%MODE%"=="run" (
    cd /d "%PROJECT_ROOT%"

    REM 检查构建产物是否存在
    if not exist "%PROJECT_ROOT%dist\main\index.js" (
        echo 构建产物不存在，正在构建...
        call npm run build:main
        if errorlevel 1 echo 主进程构建失败! & exit /b 1
        call npm run build:preload
        if errorlevel 1 echo Preload 构建失败! & exit /b 1
        call npm run build:renderer
        if errorlevel 1 echo 渲染进程构建失败! & exit /b 1
    )

    REM 检查资源文件
    set "RESOURCES_OK=1"
    if not exist "%PROJECT_ROOT%resources\adb\adb.exe" (
        echo 警告: ADB 工具不存在，请运行: npm run adb
        set "RESOURCES_OK=0"
    )
    if not exist "%PROJECT_ROOT%resources\scrcpy.jar" (
        echo 警告: scrcpy-server 不存在，请运行: npm run scrcpy
        set "RESOURCES_OK=0"
    )
    if not exist "%PROJECT_ROOT%resources\aya.dex" (
        echo 警告: aya.dex 不存在，请运行: npm run server
        set "RESOURCES_OK=0"
    )

    if "!RESOURCES_OK!"=="1" (
        echo 所有资源文件就绪。
    ) else (
        echo 部分资源文件缺失，应用仍可启动但部分功能不可用。
    )

    REM 复制资源文件到 dist/resources (生产模式下 resolveResources 从 dist/resources 加载)
    echo 同步资源文件到 dist...
    if exist "%PROJECT_ROOT%resources" (
        xcopy "%PROJECT_ROOT%resources" "%PROJECT_ROOT%dist\resources\" /E /I /Y /Q >nul
    )

    echo 正在启动 Electron...
    cd /d "%PROJECT_ROOT%"
    ".\node_modules\electron\dist\electron.exe" .
    goto :eof
)

echo 用法: start.bat [build^|dev^|run^|clean]
echo   run    - 构建并启动应用 (默认)
echo   build  - 仅构建前端
echo   dev    - 开发模式 (热重载)
echo   clean  - 清理构建产物
