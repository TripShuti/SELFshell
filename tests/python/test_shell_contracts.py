# ============================================================
# tests/python/test_shell_contracts.py — контракти конфігурації CLI
# та циклу delay-inhibitor без доступу до logind чи живої сесії.
# ============================================================
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'quickshell/scripts'))
import config_ctl
from sleep_guard import SleepGuard


class ConfigTest(unittest.TestCase):
    def test_discovery_and_get_use_defaults_without_mutating_file(self):
        self.assertEqual(set(config_ctl.DESCRIPTIONS), set(config_ctl.defaults()))
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/'config.json'
            path.write_text('{"barHeight":40}')
            base = [sys.executable, str(ROOT/'quickshell/scripts/config_ctl.py')]
            def run(*args):
                return subprocess.run([*base, args[0], str(path), *args[1:]], capture_output=True, text=True)
            self.assertEqual(run('get', 'barHeight').stdout.strip(), '40')
            self.assertEqual(run('get', 'dndEnabled').stdout.strip(), 'false')
            self.assertNotEqual(run('get', 'unknown').returncode, 0)
            listing = run('list', 'idle').stdout
            self.assertIn('idleLockTimeout', listing)
            self.assertNotIn('barHeight', listing)
            description = run('describe', 'barHeight').stdout
            self.assertIn('Current: 40', description)
            self.assertIn('Default: 36', description)
            self.assertIn('Range: 1–200', description)
            self.assertEqual(path.read_text(), '{"barHeight":40}')

    def test_palette_list_reads_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/'data/config.json'
            (Path(tmp)/'.selfshell-install.json').write_text('{"paletteIntegrations":["kitty"]}')
            result = subprocess.run([sys.executable, str(ROOT/'quickshell/scripts/config_ctl.py'), 'palette-list', str(path)], capture_output=True, text=True, check=True)
            self.assertRegex(result.stdout, r'kitty\s+yes')
            self.assertRegex(result.stdout, r'yazi\s+no')

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


class PaletteCliTest(unittest.TestCase):
    def test_enable_disable_and_invalid_arguments(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp)/'quickshell'
            scripts = config/'scripts'
            scripts.mkdir(parents=True)
            for name in ('selfshell', 'update_config.py'):
                shutil.copy2(ROOT/'quickshell/scripts'/name, scripts/name)
            manifest = config/'.selfshell-install.json'
            manifest.write_text(json.dumps({'schema': 1, 'components': ['quickshell']}))
            env = dict(os.environ, XDG_RUNTIME_DIR=tmp)
            command = ['bash', str(scripts/'selfshell'), 'palette']

            for action, app, expected in [('enable', 'kitty', ['kitty']),
                                          ('enable', 'yazi', ['kitty', 'yazi']),
                                          ('disable', 'kitty', ['yazi'])]:
                result = subprocess.run([*command, action, app], env=env,
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(manifest.read_text())['paletteIntegrations'], expected)

            previous = manifest.read_text()
            for arguments in [('enable',), ('disable',), ('enable', 'unknown')]:
                result = subprocess.run([*command, *arguments], env=env,
                                        capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(manifest.read_text(), previous)


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
