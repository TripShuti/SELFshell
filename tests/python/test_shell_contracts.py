# ============================================================
# tests/python/test_shell_contracts.py — контракти конфігурації CLI
# та циклу delay-inhibitor без доступу до logind чи живої сесії.
# ============================================================
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'quickshell/scripts'))
import config_ctl
from sleep_guard import SleepGuard


class ConfigTest(unittest.TestCase):
    def test_defaults_match_all_shipped_configuration_keys(self):
        current = json.loads((ROOT/'quickshell/data/config.json').read_text())
        self.assertEqual(set(config_ctl.defaults()), set(current))
        for key, value in current.items():
            config_ctl.validate(key, value)

    def test_rejects_unknown_keys_invalid_types_and_out_of_range_values(self):
        for key, value in [('unknown', True), ('uiScale', True), ('uiScale', 3),
                           ('barHeight', 1.5), ('themeMode', 'white'),
                           ('leftOrder', [3]), ('popupBgOpacity', -1)]:
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                config_ctl.validate(key, value)

    def test_offline_mutation_preserves_other_keys_and_reset_is_functional(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp)/'config.json'
            target.write_text('{"themeMode":"black","uiScale":1.2}')
            base = [sys.executable, str(ROOT/'quickshell/scripts/config_ctl.py')]
            subprocess.run([*base, 'set', str(target), 'themeMode', 'matugen'], check=True)
            self.assertEqual(json.loads(target.read_text()), {'themeMode': 'matugen', 'uiScale': 1.2})
            subprocess.run([*base, 'reset', str(target)], check=True)
            self.assertEqual(json.loads(target.read_text()), config_ctl.defaults())


class SleepGuardTest(unittest.TestCase):
    def test_inhibitor_released_on_secure_ack_and_reacquired_after_resume(self):
        class Manager:
            calls = 0
            def Inhibit(self, *_args):
                self.calls += 1
                value = self.calls
                return type('FD', (), {'take': lambda _: value})()
        manager, events, closed = Manager(), [], []
        guard = SleepGuard(manager, events.append, closed.append)
        guard.acquire()
        guard.acquire()
        guard.secure(0)
        self.assertEqual(closed, [])
        guard.prepare(True)
        self.assertEqual(events, [{'sleeping': True, 'cycle': 1}])
        self.assertEqual(closed, [])
        guard.secure(1)
        guard.secure(1)
        self.assertEqual(closed, [1])
        guard.prepare(False)
        self.assertEqual(manager.calls, 2)
        guard.prepare(True)
        guard.secure(1)
        self.assertEqual(closed, [1])
        guard.secure(2)
        self.assertEqual(closed, [1, 2])
