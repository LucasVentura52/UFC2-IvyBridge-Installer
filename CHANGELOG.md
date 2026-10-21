# Changelog

Todas as mudancas relevantes deste projeto.

## 1.0.0 - 2026-10-21

Primeira versao publica.

### Adicionado

- `instalar.bat` / `instalar-ivybridge.ps1`: instalador de um clique que
  - localiza o port do UFC 2 e o dump do usuario;
  - le o CPUID e aborta sem alterar nada se a CPU ja suporta
    `BMI1`/`LZCNT`/`MOVBE`;
  - cria (e nunca sobrescreve) o backup do `link_modules.py` original;
  - copia `cpu_compat.py` e `build_cpu_compat.py` para o port;
  - aplica os 6 ganchos de traducao no `link_modules.py` de forma idempotente,
    com auto-verificacao;
  - instala `capstone` e `keystone-engine` no Python embutido do port;
  - gera o plano de traducao a partir do dump do usuario e **aborta** se
    sobrar qualquer instrucao sem traducao;
  - refaz o link da imagem e confere `unhandled=0`;
  - define `BB_SKIP_CPU_CHECK=1` no usuario.
- `desinstalar.bat` / `desinstalar-ivybridge.ps1`: reverte tudo.
- `payload/cpu_check.py`: deteccao de CPU via CPUID, sem dependencias.
- `payload/apply_hooks.py`: aplicacao idempotente dos ganchos.
- `payload/build_cpu_compat.py`: gerador do plano, com as correcoes de
  registradores (operandos de memoria) e de flags (`blsr`/`blsmsk` com
  fonte zero) em relacao a implementacao de origem.
- Testes automatizados dos ganchos e da checagem de CPU, rodados no CI.

### Validado em

- CPU: Intel Core i7-3770 (Ivy Bridge, 4 nucleos / 8 threads @ 3,40 GHz)
- GPU: AMD Radeon RX 580 2048SP (8 GB, Vulkan 1.3)
- RAM: 16 GB DDR3 · Windows 10 Pro 19045
- Dump: UFC 2 `CUSA01968`, update 1.13
- Resultado: **3.184 pontos de traducao, 0 nao tratados**; jogo inicializou,
  renderizou 7.200 frames (1920x1080) e 1.800 frames em um teste de 90 s
  com saida limpa, sem `STATUS_ILLEGAL_INSTRUCTION` e sem falha de memoria.
