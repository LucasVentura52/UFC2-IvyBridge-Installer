@echo off
REM English alias for desinstalar.bat - the uninstaller itself is in Portuguese.
chcp 65001 >nul
setlocal
title UFC 2 - undo legacy CPU support
echo.
echo  ============================================================
echo   Undo: legacy CPU support (Sandy/Ivy Bridge)
echo  ============================================================
echo.
if "%~1"=="" (
    echo  Press ENTER to start, or cancel by closing this window.
    pause >nul
) else (
    echo  Using path: %~1
)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0desinstalar-ivybridge.ps1" %*
echo.
pause
endlocal
