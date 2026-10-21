"""Aplica (de forma idempotente) o suporte a CPUs legadas no link_modules.py do port.

O port do UFC 2/UFC 3/UFC 4 (SacredFire/bbport) transforma o dump do PS4 numa imagem
plana. Em CPUs sem BMI1/LZCNT/MOVBE (Intel Sandy/Ivy Bridge) o codigo do jogo usa
instrucoes que o processador nao executa, causando STATUS_ILLEGAL_INSTRUCTION.

Este script insere no link_modules.py o gancho que chama cpu_compat.patch_image(),
aplicando o plano de traducao gerado localmente a partir do dump do usuario.

Pode ser executado varias vezes: cada gancho e detectado antes de ser inserido.
"""
import re
import sys
from pathlib import Path

MARK_IMPORT = 'from cpu_compat import'
MARK_LIBC = 'libc_changes = []'
MARK_PATCH_LIBC = 'patch_libc(m)'
MARK_PATCH_IMAGE = 'patch_image('
MARK_REPORT = 'cpu_compat=compat'
MARK_PRINT = "if compat.get('enabled'):"

HOOKS = [
    dict(
        name='import cpu_compat',
        marker=MARK_IMPORT,
        pattern=r'(?m)^import game_check\s*$',
        after_line="{marker} atomic_output, patch_image, patch_libc  # CPU legada (Ivy/Sandy Bridge)",
    ),
    dict(
        name='inicializar libc_changes',
        marker=MARK_LIBC,
        pattern=r'(?m)^(?P<indent>[ \t]*)table = \[\]\s*$',
        after_line='{indent}libc_changes = []',
    ),
    dict(
        name='patch_libc no modulo libc',
        marker=MARK_PATCH_LIBC,
        pattern=r"(?m)^(?P<indent>[ \t]*)m = module\(game_check\.module_file\(game, filename\)\).*$",
        after_lines=[
            "{indent}if filename == 'libc.prx':",
            "{indent}    libc_changes = patch_libc(m)",
        ],
    ),
    dict(
        name='patch_image antes de gravar boot-linked.bin',
        marker=MARK_PATCH_IMAGE,
        pattern=r"(?m)^(?P<indent>[ \t]*)procparam = next\(p for p in main\['ph'\] if p\['type'\] == 0x61000001\)\s*$",
        after_lines=[
            "{indent}image, segments, compat = patch_image(image, segments, main, table, relocs)",
            "{indent}compat['libc'] = libc_changes",
        ],
    ),
    dict(
        name='relatorio com cpu_compat',
        marker=MARK_REPORT,
        pattern=r'(?m)^(?P<indent>[ \t]*)(?P<pre>[^\n]*?)unresolved_imports=unresolved\)(?P<tail>.*)$',
        replace='{indent}{pre}unresolved_imports=unresolved, cpu_compat=compat){tail}',
    ),
    dict(
        name='mensagem no console',
        marker=MARK_PRINT,
        pattern=r"(?m)^(?P<indent>[ \t]*)\(out / 'link\.json'\)\.write_text\(.*\)\s*$",
        after_lines=[
            "{indent}if compat.get('enabled'):",
            "{indent}    print(f\"CPU compatibility: translated {compat['patched_sites']} instruction sites (CPU legada); \"",
            "{indent}          f\"trampolines={compat['trampoline_bytes']} bytes; unhandled={compat['unhandled_count']}\")",
        ],
    ),
]


def apply_hook(text, hook):
    """Insere o gancho uma unica vez. Devolve (texto, 'ja aplicado'|'aplicado')."""
    if hook['marker'] in text:
        return text, 'ja aplicado'
    match = re.search(hook['pattern'], text)
    if not match:
        raise SystemExit(
            f"ERRO: nao encontrei o ponto de insercao para o gancho '{hook['name']}'.\n"
            "A versao do link_modules.py deste port e diferente da esperada; "
            "aplique as alteracoes manualmente ou use um port atualizado."
        )
    indent = match.groupdict().get('indent', '')
    if 'replace' in hook:
        new_line = hook['replace'].replace('{indent}', indent).replace('{tail}', match.groupdict().get('tail', '')).replace('{pre}', match.groupdict().get('pre', ''))
        text = text[:match.start()] + new_line + text[match.end():]
        insert_at = match.start() + len(new_line)
    else:
        insert_at = match.end()
    extra = []
    if 'after_line' in hook:
        extra.append(hook['after_line'].replace('{indent}', indent).replace('{marker}', hook['marker']))
    for line in hook.get('after_lines', []):
        extra.append(line.replace('{indent}', indent))
    if extra:
        text = text[:insert_at] + '\n' + '\n'.join(extra) + text[insert_at:]
    return text, 'aplicado'


def apply_to(path):
    """Aplica os ganchos no arquivo indicado. Devolve 0 em sucesso, 1 em erro."""
    path = Path(path)
    if not path.exists():
        print(f'ERRO: arquivo nao encontrado: {path}')
        return 1
    text = path.read_text(encoding='utf-8')
    original = text
    for hook in HOOKS:
        try:
            text, state = apply_hook(text, hook)
        except SystemExit as exc:
            print(str(exc))
            return 1
        print(f'  gancho "{hook["name"]}": {state}')
    if text != original:
        path.write_text(text, encoding='utf-8')
        print(f'  link_modules.py atualizado: {path}')
    else:
        print('  nada a fazer (os ganchos ja estavam presentes)')
    # auto-verificacao: todo gancho anunciado tem de estar de fato no arquivo
    missing = [h['name'] for h in HOOKS if h['marker'] not in text]
    if missing:
        print('ERRO: ganchos ausentes apos a edicao: ' + ', '.join(missing))
        return 1
    print('  verificacao: todos os ganchos presentes no arquivo')
    return 0


def main():
    if len(sys.argv) < 2:
        raise SystemExit('uso: apply_hooks.py <caminho/link_modules.py>')
    return apply_to(sys.argv[1])


if __name__ == '__main__':
    sys.exit(main())
