# UFC 2 (PS4) — suporte a CPUs legadas (Intel Sandy/Ivy Bridge)

[![Licença](https://img.shields.io/badge/licen%C3%A7a-GPL--2.0--or--later-blue.svg)](LICENSE)
[![CI](https://github.com/LucasVentura52/UFC2-IvyBridge-Installer/actions/workflows/ci.yml/badge.svg)](https://github.com/LucasVentura52/UFC2-IvyBridge-Installer/actions/workflows/ci.yml)

Instalador de um clique que faz o **port nativo do UFC 2 (PS4)** rodar em PCs com
CPU antiga — Intel Sandy Bridge / Ivy Bridge (2ª e 3ª geração), Xeon E3 v1/v2 e
AMD pré-Zen — que não têm as instruções `BMI1`, `LZCNT` e `MOVBE`.

**O jogo continua rodando nativamente** (sem emulador de CPU): o código do PS4
é executado direto no seu processador, e apenas as poucas instruções que a sua
CPU não conhece são reescritas para equivalentes que ela entende, no momento em
que a imagem do jogo é montada.

> Nenhum arquivo do jogo é incluído, copiado ou distribuído por este projeto.
> O plano de tradução é gerado **na sua máquina**, a partir do **seu** dump.

---

## O problema

O port do UFC 2 (SacredFire/bbport) transforma o `eboot.bin` do PS4 numa imagem
plana e roda o código original na CPU do PC. Só que esse código foi compilado
para a CPU do PS4 e usa instruções que só existem a partir do Intel Haswell
(4ª geração, 2013):

| Instrução | Onde aparece |
|---|---|
| `BMI1` (`andn`, `bextr`, `blsr`, `blsi`, `blsmsk`, `tzcnt`) | código do jogo e `libc.prx` |
| `LZCNT` | contagem de zeros à esquerda (código do jogo) |
| `MOVBE` | subsystems de áudio e física |

Em CPUs antigas o jogo aborta imediatamente com
`STATUS_ILLEGAL_INSTRUCTION (0xC000001D)`, e o launcher nem deixa abrir.

## A solução

Tradução em tempo de link (*link-time*):

1. o `build_cpu_compat.py` varre o seu `eboot.bin`, `libc.prx` e
   `libSceFios2.prx`, encontra **todas** as instruções fora do seu CPU e gera
   um "plano" com o equivalente de cada uma;
2. o `cpu_compat.py` injeta esses equivalentes (trampolinas) na imagem do jogo
   durante o link, com um segmento de memória extra só de leitura/execução;
3. a `strlen` do `libc.prx` (que usa `AVX2`/`BMI1`) é substituída por uma
   versão baseline em x86-64.

No dump do UFC 2 (`CUSA01968`, update 1.13) isso dá **3.184 pontos de tradução,
0 não tratados** e ~285 KB de trampolinas.

## Requisitos

* Windows 10 (1903+) ou 11, 64 bits
* CPU sem `BMI1`/`LZCNT`/`MOVBE` (Intel Sandy/Ivy Bridge, Xeon E3 v1/v2, AMD pré-Zen)
* GPU com Vulkan 1.3 (NVIDIA, AMD ou Intel Arc)
* O port do UFC 2 (SacredFire) instalado + o **seu** dump do jogo
  (`CUSA01968`, update 1.13) apontado no launcher

## Como usar

1. Baixe o [zip release](https://github.com/LucasVentura52/UFC2-IvyBridge-Installer/releases) e extraia
   em qualquer lugar (fora da pasta do jogo e fora do OneDrive);
2. **Feche** o launcher do jogo;
3. Clique duas vezes em **`instalar.bat`**
   (ou passe o caminho do port: `instalar.bat "D:\UFC 2\PORTHEON"`);
4. Abra o launcher de novo e jogue.

Inside the game, <kbd>Insert</kbd> or <kbd>L3+R3</kbd> opens the port's own menu.

## O que o instalador faz

| # | Etapa | Observação |
|---|---|---|
| 1 | Localiza o port e o dump | aceita o path do PORTHEON ou do port direto |
| 2 | Lê o CPUID | se a CPU já suporta tudo, **não altera nada** e sai |
| 3 | Backup do `link_modules.py` | o backup original nunca é sobrescrito |
| 4 | Copia `cpu_compat.py` / `build_cpu_compat.py` | compara hashes, só reescreve se mudou |
| 5 | Aplica os 6 ganchos no `link_modules.py` | idempotente + auto-verificação |
| 6 | `pip install capstone keystone-engine` | no Python embutido do port (precisa de internet na 1ª vez) |
| 7 | Gera o plano a partir do seu dump | **aborta se sobrar qualquer instrução sem tradução** |
| 8 | Refaz o link e confere | confirma `translated N sites ... unhandled=0` |
| 9 | Define `BB_SKIP_CPU_CHECK=1` | o launcher do port recusa CPUs antigas sem isso |

Desfazer tudo: **`desinstalar.bat`** (restaura o `link_modules.py` original,
remove as ferramentas e apaga a variável de ambiente).

## Diagnóstico

* Logs do jogo: `%LOCALAPPDATA%\UFC2Native\logs` (o launcher tem um botão
  "Abrir logs")
* Relatório do link: `%LOCALAPPDATA%\UFC2Native\out\link.json` → campo
  `cpu_compat` (`patched_sites`, `trampoline_bytes`, `unhandled_count`)

Problemas comuns:

| Sintoma | O que fazer |
|---|---|
| `Nao encontrei o port` | passe o caminho: `instalar.bat "D:\UFC 2\PORTHEON"` |
| `Falha ao instalar capstone` | a primeira vez precisa de internet; rode de novo |
| `unhandled > 0` | seu dump é de outra versão — mande o log no issue do projeto |
| o jogo abre e fecha sozinho | confira `BB_SKIP_CPU_CHECK=1` (Passo 9) e reabra o launcher |

## Correções em relação ao material original

O tradutor do PR #48 ([deanzx06](https://github.com/deanzx06/UFC3-4-IvyBridge-Patch)) foi usado como base. Dois defeitos
foram encontrados **em execução real** e corrigidos aqui:

1. **Operandos de memória não eram isolados.** Ao traduc `andn ecx, eax, dword ptr [rdi + r10*4]`,
   o tradutor usava `r10` como registrador temporário — destruindo o próprio
   endereço que ia ler. Resultado: acesso inválido a memória durante a carga.
   Agora todos os registradores citados em qualquer operando (inclusive dentro
   de `[...]`) são preservados.
2. **Flags de `blsr`/`blsmsk` com fonte zero.** `blsr` precisa de `CF=1` e
   `blsmsk` precisa devolver todos os bits 1 com `CF=1`/`ZF=0`; a tradução
   devolvia `CF=0` e destino zero.

Além disso, operandos RIP-relativos são rejeitados (não há correção de
relocação para eles) e o instalador **falha alto** se algo ficar sem tradução.

## Créditos e licença

* Port base: [SacredFire](https://github.com/T3CHNOLOG1C/SacredFire) /
  [bbport](https://github.com/deadinside28/bloodborne_pc) e o
  [UFC-3-PS4-PORT-LINUX-WINDOWS](https://github.com/GNSB/UFC-3-PS4-PORT-LINUX-WINDOWS) (GNSB)
* Tradução para CPUs legadas: PR #48 de
  [deanzx06](https://github.com/deanzx06/UFC3-4-IvyBridge-Patch), baseado no
  trabalho de [T0ug](https://github.com/T0ug/bloodborne_pc_Ivy-Bridge) e
  [Supermedo](https://github.com/deadinside28/bloodborne_pc)
* Este instalador: correções de registradores/flags e automação em um clique

Licença **GPL-2.0-or-later**, igual aos projetos de origem.

## Aviso legal

Este projeto **não contém** arquivos do jogo (código, modelos, texturas, áudio,
vídeos). Ele apenas instala ferramentas que traduzem o código do PS4 no
processo de inicialização do port, usando o dump que **você** possui e
licencia. O jogo é uma obra da Electronic Arts; este projeto não é afiliado nem
endossado pela EA, pela Sony Interactive Entertainment ou pela UFC.

---

# English

**One-click installer that makes the native UFC 2 (PS4) port run on older CPUs**
(Intel Sandy/Ivy Bridge, Xeon E3 v1/v2, pre-Zen AMD) that lack `BMI1`,
`LZCNT` and `MOVBE`. The game still runs natively — no CPU emulation: only the
instructions your processor does not know are rewritten into equivalent ones
while the game image is being built.

* Requires Windows 10 (1903+)/11 x64, a Vulkan 1.3 GPU, the SacredFire UFC 2
  port and your own `CUSA01968` (update 1.13) dump.
* Run `instalar.bat` (`install.bat` equivalent), then start the game from the
  launcher.
* Nothing from the game is shipped or redistributed: the translation plan is
  generated on your machine, from your own dump.
* `desinstalar.bat` / `uninstall.bat` reverts everything.

See the Portuguese section above for the full details, the installer steps and
the troubleshooting table.
