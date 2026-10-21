@echo off
chcp 65001 >nul
setlocal
title UFC 2 - desfazer suporte a CPUs legadas
echo.
echo  ============================================================
echo   Desfazer: suporte a CPUs legadas (Ivy/Sandy Bridge)
echo  ============================================================
echo.
if "%~1"=="" (
    echo  Pressione ENTER para comecar, ou cancele fechando a janela.
    pause >nul
) else (
    echo  Usando o caminho: %~1
)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0desinstalar-ivybridge.ps1" %*
echo.
pause
endlocal
