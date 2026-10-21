# Instalador de suporte a CPUs legadas (Intel Sandy/Ivy Bridge) para o UFC 2 PS4 port.
#
# O que ele faz:
#   1. localiza o port do UFC 2
#   2. confere se a CPU realmente precisa da traducao (CPUID)
#   3. faz backup do link_modules.py original
#   4. copia cpu_compat.py / build_cpu_compat.py para o port
#   5. insere os ganchos de traducao no link_modules.py (idempotente)
#   6. instala capstone + keystone-engine no Python embutido do port
#   7. gera o plano de traducao a partir do dump do usuario
#   8. refaz o link (boot-linked.bin) e confere o resultado
#   9. define BB_SKIP_CPU_CHECK=1 (permanente, para novos processos)
#
# Nada do jogo e copiado, alterado ou distribuido: o plano e gerado localmente
# a partir do dump do proprio usuario.

param(
    [string]$PortPath = '',
    [switch]$SkipRelink,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$payload = Join-Path $here 'payload'

function Say($m)  { Write-Host $m }
function Ok($m)   { Write-Host "[ OK ] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[AVISO] $m" -ForegroundColor Yellow }
function Err($m)  { Write-Host "[ERRO] $m" -ForegroundColor Red }
function Step($m) { Write-Host ''; Write-Host "== $m" -ForegroundColor Cyan }

function Run-Python {
    param([string]$Exe, [string[]]$PyArgs, [string]$Label)
    $out = & $Exe @PyArgs 2>&1
    $code = $LASTEXITCODE
    $out | ForEach-Object { Write-Host "    $_" }
    if ($code -ne 0) { Err "$Label falhou (codigo $code)"; exit 1 }
    return ($out -join "`n")
}

# ---------------------------------------------------------------- 1. localizar o port
Step "1/9  Localizando o port do UFC 2"
if (-not $PortPath) {
    $guess = @(
        (Join-Path $here '..'),
        'D:\UFC 2\PORTHEON',
        (Join-Path $env:LOCALAPPDATA 'UFC2Native')
    )
    foreach ($g in $guess) {
        if ($g -and (Test-Path (Join-Path $g 'scripts\link_modules.py'))) { $PortPath = $g; break }
        if ($g -and (Test-Path (Join-Path $g 'games\UFC2\scripts\link_modules.py'))) { $PortPath = (Join-Path $g 'games\UFC2'); break }
    }
    if (-not $PortPath) {
        $PortPath = Read-Host 'Caminho do port do UFC 2 (ex.: D:\UFC 2\PORTHEON)'
    }
}
$PortPath = $PortPath.Trim().Trim('"')
$port = $null
foreach ($cand in @($PortPath, (Join-Path $PortPath 'games\UFC2'))) {
    if ($cand -and (Test-Path (Join-Path $cand 'scripts\link_modules.py'))) { $port = (Resolve-Path $cand).Path; break }
}
if (-not $port) { Err "Nao encontrei o port (scripts\link_modules.py) em: $PortPath"; exit 1 }
Ok "Port: $port"

$scripts   = Join-Path $port 'scripts'
$tools     = Join-Path $port 'tools'
$linker    = Join-Path $scripts 'link_modules.py'
$prepare   = Join-Path $scripts 'prepare.py'
$linkLibc  = Join-Path $scripts 'link_libc.py'
foreach ($f in @($linker, $prepare)) {
    if (-not (Test-Path $f)) { Err "Faltando: $f"; exit 1 }
}
if (-not (Test-Path $tools)) { New-Item -ItemType Directory -Force -Path $tools | Out-Null }

# ---------------------------------------------------------------- 2. dump do jogo
Step "2/9  Localizando o dump do jogo (eboot.bin)"
$game = $null
$ini = Join-Path $env:LOCALAPPDATA 'UFC2Native\bbport.ini'
if (Test-Path $ini) {
    $line = Select-String -Path $ini -Pattern '^game=(.*)$' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($line) {
        $cand = $line.Matches[0].Groups[1].Value.Trim()
        if ($cand -and (Test-Path (Join-Path $cand 'eboot.bin'))) { $game = $cand }
    }
}
if (-not $game) {
    foreach ($cand in @((Join-Path $port 'UFC 2'), (Join-Path (Split-Path $port -Parent) 'UFC 2'))) {
        if (Test-Path (Join-Path $cand 'eboot.bin')) { $game = (Resolve-Path $cand).Path; break }
    }
}
if (-not $game) { Err 'Nao encontrei a pasta do dump (eboot.bin). Apontando o launcher para a pasta do jogo.'; exit 1 }
if (-not (Test-Path (Join-Path $game 'sce_module\libc.prx'))) { Err "Dump incompleto: sem sce_module\libc.prx em $game"; exit 1 }
Ok "Dump: $game"

# ---------------------------------------------------------------- 3. Python
Step "3/9  Python do port"
$python = Join-Path $port 'python\python.exe'
if (Test-Path $python) { Ok "Python embutido: $python" }
else {
    $python = $null
    foreach ($c in @('py', 'python')) {
        $probe = Get-Command $c -ErrorAction SilentlyContinue
        if ($probe) { $python = $c; break }
    }
    if (-not $python) { Err 'Nao encontrei um Python (nem o do port, nem do sistema).'; exit 1 }
    Warn "Usando o Python do sistema: $python"
}

# ---------------------------------------------------------------- 4. checar a CPU
Step "4/9  Verificando a CPU"
$check = (& $python (Join-Path $payload 'cpu_check.py') 2>&1 | Out-String).Trim()
Say "    CPUID: $check"
if ($check -like 'OK*' -and -not $Force) {
    Ok 'Sua CPU ja suporta BMI1/LZCNT/MOVBE - nao precisa deste patch. Nada foi alterado.'
    exit 0
}
if ($check -like 'UNKNOWN*') { Warn 'Nao foi possivel ler o CPUID; vou continuar mesmo assim (o patch so e ativado quando faz falta).' }

# ---------------------------------------------------------------- 5. backup
Step "5/9  Backup do link_modules.py"
$backup = Join-Path $scripts 'link_modules.py.ORIGINAL-backup'
if (Test-Path $backup) {
    Ok "Backup ja existe (mantido o original): $backup"
} else {
    Copy-Item $linker $backup
    Ok "Backup criado: $backup"
}

# ---------------------------------------------------------------- 6. copiar o payload
Step "6/9  Copiando as ferramentas de traducao"
foreach ($pair in @(@('cpu_compat.py', (Join-Path $scripts 'cpu_compat.py')),
                     @('build_cpu_compat.py', (Join-Path $tools 'build_cpu_compat.py')))) {
    $src = Join-Path $payload $pair[0]
    $dst = $pair[1]
    if ((Test-Path $dst) -and ((Get-FileHash $src).Hash -eq (Get-FileHash $dst).Hash)) {
        Ok "$($pair[0]) ja esta atualizado"
    } else {
        Copy-Item $src $dst -Force
        Ok "$($pair[0]) -> $dst"
    }
}

# ---------------------------------------------------------------- 7. ganchos
Step "7/9  Aplicando os ganchos no link_modules.py"
$hooks = Run-Python -Exe $python -PyArgs @((Join-Path $payload 'apply_hooks.py'), $linker) -Label 'apply_hooks'
if ($hooks -match 'ERRO') { Err 'Nao foi possivel aplicar os ganchos.'; exit 1 }

# ---------------------------------------------------------------- 8. dependencias + plano
Step "8/9  Dependencias (capstone, keystone-engine)"
$pip = & $python -m pip --version 2>&1
if ($LASTEXITCODE -ne 0) { Err "pip nao disponivel neste Python: $pip"; exit 1 }
& $python -m pip install --quiet --disable-pip-version-check capstone keystone-engine 2>&1 | ForEach-Object { Write-Host "    $_" }
if ($LASTEXITCODE -ne 0) { Err 'Falha ao instalar capstone/keystone-engine (precisa de internet na primeira vez).'; exit 1 }
Ok 'capstone e keystone-engine instalados'

Step '9/9  Gerando o plano de traducao (a partir do seu dump)'
$gen = Run-Python -Exe $python -PyArgs @('-B', (Join-Path $tools 'build_cpu_compat.py'), $game) -Label 'build_cpu_compat'
$planJson = Join-Path $tools 'legacy-cpu-plan.json'
if (-not (Test-Path $planJson)) { Err 'O plano nao foi gerado.'; exit 1 }
$stats = Run-Python -Exe $python -PyArgs @('-c', "import json;d=json.load(open(r'$planJson'));print('sites=%d unhandled=%d' % (len(d['sites']), len(d['unhandled'])))") -Label 'plan stats'
Say "    $stats"
if ($stats -notmatch 'unhandled=0') {
    Err 'Ficaram instrucoes sem traducao (unhandled > 0). O jogo ainda assim causaria erro de instrucao.'
    Err 'Envie o log para o projeto: https://github.com/GNSB/UFC-3-PS4-PORT-LINUX-WINDOWS'
    exit 1
}
Ok 'Plano gerado com cobertura total'

# ---------------------------------------------------------------- 10. relink
if (-not $SkipRelink) {
    Step 'Extra  Refazendo o link da imagem do jogo'
    $out = Join-Path $env:LOCALAPPDATA 'UFC2Native\out'
    if (-not (Test-Path (Join-Path $out 'boot.bin'))) {
        Run-Python -Exe $python -PyArgs @('-E', '-s', $prepare, $game, '--out', $out) -Label 'prepare' | Out-Null
    }
    if (Test-Path $linkLibc) {
        Run-Python -Exe $python -PyArgs @('-E', '-s', $linkLibc, $game, '--out', $out) -Label 'link_libc' | Out-Null
    }
    $link = Run-Python -Exe $python -PyArgs @('-E', '-s', $linker, $game, '--out', $out, '--modules', 'libc.prx', 'libSceFios2.prx') -Label 'link_modules'
    if ($link -notmatch 'CPU compatibility: translated') {
        Warn 'A traducao nao aparece no log do link. Confira os logs do jogo.'
    } else {
        Ok (($link -split "`n" | Where-Object { $_ -match 'CPU compatibility' }) -join '')
    }
}

# ---------------------------------------------------------------- 11. variavel de ambiente
Step 'Variavel de ambiente'
[Environment]::SetEnvironmentVariable('BB_SKIP_CPU_CHECK', '1', 'User')
Ok 'BB_SKIP_CPU_CHECK=1 definido para o seu usuario (vale para os proximos programas abertos)'

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host ' PRONTO! Agora e so jogar:' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Say '  1. Feche o launcher (se estiver aberto) e abra de novo.'
Say '  2. PORTHEON.exe -> UFC 2 -> (Procurar ja esta apontando para o dump) -> JOGAR.'
Say '  3. Dentro do jogo: Insert ou L3+R3 abre o menu do port.'
Say ''
Say '  Logs: %LOCALAPPDATA%\UFC2Native\logs  (botao "Abrir logs" no launcher)'
Say '  Desfazer: rode desinstalar.bat'
Say ''
