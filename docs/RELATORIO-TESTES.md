# Relatório de testes (em hardware real)

Ambiente usado para validar este instalador.

## Máquina

| Item | Valor |
|---|---|
| CPU | Intel Core i7-3770 (Ivy Bridge, 4 núcleos / 8 threads, 3,40 GHz) |
| Placa-mãe | Intel B75 (LGA1155) |
| RAM | 16 GB DDR3 |
| GPU | AMD Radeon RX 580 2048SP — **7936 MiB (8 GB)**, driver 2.0.279, Vulkan 1.3.260 |
| SO | Windows 10 Pro 19045 (64 bits) |
| Port | SacredFire / UFC 2 `ufc2-v0.1.0-test5` (via PORTHEON 1.4) |
| Dump | UFC 2 `CUSA01968`, update 1.13 |

## Sintoma original

O launcher recusava abrir e, com `BB_SKIP_CPU_CHECK=1`, o jogo morria logo
depois de `Runtime: application heap API registered`:

```
ERROR: this CPU lacks BMI1, MOVBE, LZCNT. The game's code was compiled for
the PS4's CPU and uses these instructions directly: it needs an Intel
Haswell (4th generation Core, 2013) or newer, or an AMD Ryzen.
...
Fault: exception 0xc000001d at guest offset 0x2540652
  #0 guest offset 0x251f28e
```

A instrução faultada era `ANDN` (BMI1), dentro do `libc.prx` ligado.

## O que o instalador produz

```
CPU compatibility: replaced BMI1 strlen in generated libc image (Ivy Bridge support)
CPU compatibility: translated 3182 instruction sites (CPU legada); trampolines=284682 bytes; unhandled=0
```

Plano: **3.184 sites** (`bextr` 2.064, `andn` 644, `movbe` 326, `tzcnt` 59,
`lzcnt` 50, `blsi` 40, `blsmsk` 1) — **0 não tratados**.

## Resultados de execução

| Teste | Resultado |
|---|---|
| Boot do jogo com a imagem traduzida | passa do ponto do crash, threads e áudio (WASAPI) inicializados |
| Sessão longa | `Flip 7200` — 7.200 frames em 1920x1080, saída limpa (código 0) ao fechar a janela |
| Teste de 90 s com `--timeout 90` | `Flip 1800`, encerramento pelo watchdog do port, sem fault |
| Erros de memória / instrução illegal | nenhum |
| Arquivos de interface ausentes | alguns `.lreq` opcionais (FTUE, medidor de vantagem) não encontrados — o dump não traz `samplegame/ui`;不影响 o arranque |

## Defeitos encontrados no tradutor de origem e corrigidos aqui

1. **Operandos de memória não isolados** — em `andn ecx, eax, dword ptr [rdi + r10*4]`
   o tradutor escolhia `r10` como temporário e destruía o endereço que ia ler,
   causando leitura inválida (`0x14193D9FAC`). Todos os registradores citados
   em qualquer operando (inclusive dentro de `[...]`) passaram a ser preservados.
2. **Flags de `blsr`/`blsmsk` com fonte zero** — `blsr` precisa de `CF=1`;
   `blsmsk` precisa devolver todos os bits 1 com `CF=1` e `ZF=0`. A tradução
   original devolvia `CF=0` e destino zero.
3. **Operandos RIP-relativos** passaram a ser rejeitados (não há correção de
   relocação para eles) em vez de gerar código inválido.
4. **Gancho de import silenciosamente perdido** — o aplicador reportava
   "aplicado" sem inserir nada; agora há auto-verificação que falha alto.

## Instalador: casos testados

| Cenário | Resultado |
|---|---|
| Instalação do zero (port original, sem plano, sem variável de ambiente) | 9 etapas, plano 3184/0, link OK |
| Execução repetida (idempotência) | ganchos "já aplicado", arquivo inalterado |
| `desinstalar.bat` | original restaurado, payload removido, variável removida |
| Reinstalação após desinstalar | funciona igual à primeira vez |
| CPU moderna (`OK` no CPUID) | nenhuma alteração feita, sai com aviso |
