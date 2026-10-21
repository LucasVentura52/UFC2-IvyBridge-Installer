"""Fixture: um link_modules.py sintetico com os pontos de insercao dos ganchos.

Nao e o arquivo real do port (o real depende do dump), apenas um modelo com as
mesmas linhas-ancora, usado pelos testes.
"""
import collections
import hashlib
import json
from pathlib import Path
import struct
from prepare import parse_self, span, unpack
from link_libc import encode_id
import game_check

DEFAULT_MODULES = ('libc.prx', 'libSceFios2.prx')
FS_LOAD = bytes.fromhex('64488b042500000000')


def module(path):
    return dict(elf=b'', header=None, ph=[], tags={}, symbols=[], relocs=[],
                identity=None, libraries={}, modules={}, sha256=hashlib.sha256(b'').hexdigest(),
                missing=[])


def link(game, out, module_names=DEFAULT_MODULES):
    main = module(game / 'eboot.bin')
    image = bytearray()
    segments = []
    relocs = []
    table = []
    base = 0
    exports, by_nid = {}, collections.defaultdict(list)
    names = []
    identities = {}

    def imported(symbol):
        return 0

    for filename in module_names:
        m = module(game_check.module_file(game, filename))
        table.append(dict(file=filename, base=base, size=0, init=0, tls_address=0,
                          tls_memsz=0, tls_filesz=0, tls_module=0, exports=0, sha256=''))
        base += 0x10000

    main_tls = None
    main_tls_values = (0, 0, 0, 0)
    procparam = next(p for p in main['ph'] if p['type'] == 0x61000001)
    with (out / 'boot-linked.bin').open('wb') as f:
        f.write(b'')
    report = dict(modules=[], bindings=0, imports=0, fs_loads_patched=0,
                  main_tls={},
                  unresolved_imports=unresolved)
    (out / 'link.json').write_text(json.dumps(report, indent=2) + '\n')
    summary = 'ok'
    print(f'Linked modules: {summary}')


if __name__ == '__main__':
    import argparse
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('game', type=Path)
    p.add_argument('--out', type=Path, default=Path(__file__).resolve().parent.parent / 'out')
    p.add_argument('--modules', nargs='*', default=list(DEFAULT_MODULES))
    a = p.parse_args()
    link(a.game, a.out, a.modules)
