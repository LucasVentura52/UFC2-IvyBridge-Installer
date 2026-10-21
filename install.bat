@echo off
REM English alias for instalar.bat - the installer itself is in Portuguese.
chcp 65001 >nul
setlocal
title UFC 2 - legacy CPU support (Sandy/Ivy Bridge)
echo.
echo  ============================================================
echo   UFC 2 PS4 port - legacy CPU installer
echo   (Intel Sandy Bridge / Ivy Bridge: no BMI1, LZCNT, MOVBE)
echo  ============================================================
echo.
echo  Ships no game files. It translates the PS4 code for your CPU
echo  using YOUR own dump.
echo.
if "%~1"=="" (
    echo  Press ENTER to start, or cancel by closing this window.
    pause >nul
) else (
    echo  Using path: %~1
)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar-ivybridge.ps1" %*
echo.
pause
endlocal
