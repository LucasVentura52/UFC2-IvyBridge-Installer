# Desfaz a instalacao do suporte a CPUs legadas.
#
# - restaura o link_modules.py original (a partir do backup)
# - remove as ferramentas de traducao copiadas no port
# - remove a variavel BB_SKIP_CPU_CHECK

param([string]$PortPath = '')

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Say($m)  { Write-Host $m }
function Ok($m)   { Write-Host "[ OK ] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[AVISO] $m" -ForegroundColor Yellow }
function Err($m)  { Write-Host "[ERRO] $m" -ForegroundColor Red }

if (-not $PortPath) {
    $guess = @('D:\UFC 2\PORTHEON', (Join-Path $here '..'))
    foreach ($g in $guess) {
        if ($g -and (Test-Path (Join-Path $g 'scripts\link_modules.py'))) { $PortPath = $g; break }
        if ($g -and (Test-Path (Join-Path $g 'games\UFC2\scripts\link_modules.py'))) { $PortPath = (Join-Path $g 'games\UFC2'); break }
    }
    if (-not $PortPath) { $PortPath = Read-Host 'Caminho do port do UFC 2' }
}
$PortPath = $PortPath.Trim().Trim('"')
$port = $null
foreach ($cand in @($PortPath, (Join-Path $PortPath 'games\UFC2'))) {
    if ($cand -and (Test-Path (Join-Path $cand 'scripts\link_modules.py'))) { $port = (Resolve-Path $cand).Path; break }
}
if (-not $port) { Err "Nao encontrei o port em: $PortPath"; exit 1 }
Ok "Port: $port"

$scripts = Join-Path $port 'scripts'
$tools   = Join-Path $port 'tools'
$linker  = Join-Path $scripts 'link_modules.py'
$backup  = Join-Path $scripts 'link_modules.py.ORIGINAL-backup'

if (Test-Path $backup) {
    Copy-Item $backup $linker -Force
    Ok 'link_modules.py original restaurado'
} else {
    Warn 'Nao ha backup do link_modules.py (nada a restaurar)'
}

foreach ($f in @((Join-Path $scripts 'cpu_compat.py'),
                 (Join-Path $tools 'build_cpu_compat.py'),
                 (Join-Path $tools 'legacy-cpu-plan.json'),
                 (Join-Path $tools 'legacy-cpu-plan.json.xz'))) {
    if (Test-Path $f) { Remove-Item $f -Force; Say "removido: $f" }
}

[Environment]::SetEnvironmentVariable('BB_SKIP_CPU_CHECK', $null, 'User')
Ok 'BB_SKIP_CPU_CHECK removido do seu usuario'

Write-Host ''
Say 'Desinstalado. O port volta ao estado original (o jogo so voltara a rodar em CPUs Haswell+).'
Write-Host ''
