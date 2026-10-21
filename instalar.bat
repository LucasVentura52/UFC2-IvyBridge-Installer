@echo off
chcp 65001 >nul
setlocal
title UFC 2 - suporte a CPUs legadas (Ivy/Sandy Bridge)
echo.
echo  ============================================================
echo   UFC 2 PS4 port - instalador de suporte a CPU legada
echo   (Intel Sandy Bridge / Ivy Bridge: sem BMI1, LZCNT, MOVBE)
echo  ============================================================
echo.
echo  Este instalador nao copia nem distribui arquivos do jogo.
echo  Ele traduz as instrucoes do codigo do PS4 para a sua CPU,
echo  usando o SEU proprio dump.
echo.
if "%~1"=="" (
    echo  Pressione ENTER para comecar, ou cancele fechando a janela.
    pause >nul
) else (
    echo  Usando o caminho: %~1
)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar-ivybridge.ps1" %*
echo.
pause
endlocal
