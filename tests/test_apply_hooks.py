"""Testes do instalador: aplicacao dos ganchos, idempotencia e deteccao de CPU.

Roda sem o port instalado e sem nenhum arquivo do jogo:
    python -m unittest discover -s tests -v
"""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PAYLOAD = ROOT / 'payload'
FIXTURE = Path(__file__).resolve().parent / 'fixture_link_modules.py'

sys.path.insert(0, str(PAYLOAD))
import apply_hooks  # noqa: E402


class TestApplyHooks(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.target = self.tmp / 'link_modules.py'
        shutil.copy(FIXTURE, self.target)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def apply(self):
        return apply_hooks.apply_to(self.target)

    def test_hooks_are_applied(self):
        self.assertEqual(self.apply(), 0)
        text = self.target.read_text(encoding='utf-8')
        for hook in apply_hooks.HOOKS:
            self.assertIn(hook['marker'], text, f"gancho ausente: {hook['name']}")

    def test_hooks_are_idempotent(self):
        self.apply()
        first = self.target.read_text(encoding='utf-8')
        self.apply()
        second = self.target.read_text(encoding='utf-8')
        self.assertEqual(first, second, 'a segunda execucao alterou o arquivo')

    def test_result_is_valid_python(self):
        self.apply()
        import py_compile
        py_compile.compile(str(self.target), doraise=True)

    def test_all_hooks_reported_as_present(self):
        self.apply()
        text = self.target.read_text(encoding='utf-8')
        missing = [h['name'] for h in apply_hooks.HOOKS if h['marker'] not in text]
        self.assertEqual(missing, [])


class TestCpuCheck(unittest.TestCase):
    def test_cpu_check_reports_a_known_state(self):
        out = subprocess.run([sys.executable, str(PAYLOAD / 'cpu_check.py')],
                             capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stderr)
        state = out.stdout.strip()
        self.assertTrue(state == 'OK' or state == 'UNKNOWN' or state.startswith('MISSING:'),
                        f'estado de CPU inesperado: {state!r}')
        if state.startswith('MISSING:'):
            for ext in state.split(':', 1)[1].split(','):
                self.assertIn(ext, ('BMI1', 'LZCNT', 'MOVBE'))


if __name__ == '__main__':
    unittest.main()
