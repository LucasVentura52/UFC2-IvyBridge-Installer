"""Detecta se a CPU do PC precisa da traducao de instrucoes (BMI1/LZCNT/MOVBE).

Imprime uma linha:
    OK       -> a CPU ja suporta tudo (nao precisa do patch)
    MISSING  -> a CPU e legada (Intel Sandy/Ivy Bridge, Xeon E3 v1/v2, AMD pre-Zen)
    UNKNOWN  -> nao foi possivel ler o CPUID

Nao depende de nenhum modulo externo.
"""
import ctypes

# push rbx; mov eax,ecx; mov ecx,edx; cpuid; mov [r8],eax; mov [r8+4],ebx;
# mov [r8+8],ecx; mov [r8+12],edx; pop rbx; ret
CPUID_CODE = bytes.fromhex('5389c889d10fa241890041895804418948084189500c5bc3')

HOST_EXTENSIONS = {
    'BMI1': (7, 1, 3),            # EBX bit 3
    'LZCNT': (0x80000001, 2, 5),  # ECX bit 5
    'MOVBE': (1, 2, 22),          # ECX bit 22
}


def _cpuid_windows():
    k32 = ctypes.WinDLL('kernel32', use_last_error=True)
    k32.VirtualAlloc.restype = ctypes.c_void_p
    k32.VirtualAlloc.argtypes = (ctypes.c_void_p, ctypes.c_size_t, ctypes.c_uint32, ctypes.c_uint32)
    k32.VirtualFree.argtypes = (ctypes.c_void_p, ctypes.c_size_t, ctypes.c_uint32)
    mem = k32.VirtualAlloc(None, len(CPUID_CODE), 0x3000, 0x40)  # MEM_COMMIT|MEM_RESERVE, PAGE_EXECUTE_READWRITE
    if not mem:
        return None
    ctypes.memmove(mem, CPUID_CODE, len(CPUID_CODE))
    fn = ctypes.CFUNCTYPE(None, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p)(mem)

    def cpuid(leaf, subleaf=0):
        regs = (ctypes.c_uint32 * 4)()
        fn(leaf, subleaf, ctypes.addressof(regs))
        return tuple(regs)

    return cpuid, lambda: k32.VirtualFree(mem, 0, 0x8000)


def missing_extensions():
    try:
        found = _cpuid_windows()
    except Exception:
        return None
    if not found:
        return None
    cpuid, cleanup = found
    try:
        top = cpuid(0)[0]
        extended = cpuid(0x80000000)[0]
        missing = []
        for name, (leaf, reg, bit) in HOST_EXTENSIONS.items():
            avail = top if leaf < 0x80000000 else extended
            if leaf > avail or not (cpuid(leaf)[reg] >> bit & 1):
                missing.append(name)
        return missing
    except Exception:
        return None
    finally:
        cleanup()


if __name__ == '__main__':
    missing = missing_extensions()
    if missing is None:
        print('UNKNOWN')
    elif missing:
        print('MISSING:' + ','.join(missing))
    else:
        print('OK')
