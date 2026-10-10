# ============================================================
# tests/python/test_install.py — повний запуск інсталятора з підставними
# системними командами та ізольованими файловими шляхами.
# ============================================================
import json
import os
import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

# Тільки HOME-посилання у копії інсталятора перенаправляються в sandbox;
# прапорці Bash, entrypoint і traps залишаються справжніми.
DRIVER = r'''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
root=Path(os.environ['INSTALL_TEST_ROOT'])
name=Path(sys.argv[0]).name
args=sys.argv[1:]
with (root/'commands').open('a') as f: f.write(json.dumps([name,*args])+'\n')
if name=='sudo':
    name,args=args[0],args[1:]
    if name=='-v': sys.exit(0)
    args=[str(root/'system'/a.lstrip('/')) if a.startswith('/etc/') else a for a in args]
if name=='pacman':
    sys.exit(1 if os.getenv('FAIL_PACKAGES') and ('-Qi' in args or '-S' in args) else 0)
if name=='systemctl':
    if 'greetd' in args and 'enable' in args:
        alias=root/'system/etc/systemd/system/display-manager.service'
        alias.parent.mkdir(parents=True,exist_ok=True)
        alias.unlink(missing_ok=True)
        alias.symlink_to('/usr/lib/systemd/system/greetd.service')
        if os.getenv('FAIL_GREETD'):sys.exit(1)
    sys.exit(0)
if name=='cp' and os.getenv('FAIL_COPY') and args[-1].endswith('/.config/quickshell'):
    Path(args[-1]).mkdir(parents=True,exist_ok=True)
    (Path(args[-1])/'partial').write_text('partial')
    sys.exit(1)
if name=='tee':
    Path(args[-1]).write_text(sys.stdin.read());sys.exit(0)
if name in ('cp','mv','rm','mkdir','test'):
    os.execv('/usr/bin/'+name,[name,*args])
sys.exit(0)
'''


class InstallerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='selfshell-install-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root/'home'
        self.home.mkdir()
        self.repo = self.root/'repo'
        self.repo.mkdir()
        script = (ROOT/'install.sh').read_text().replace('$HOME', '${INSTALL_TEST_HOME}')
        (self.repo/'install.sh').write_text(script)
        for name in ('quickshell/scripts', 'quickshell/services', 'quickshell/wp',
                     'hypr', 'fish', 'kitty', 'yazi', 'starship', 'fastfetch'):
            (self.repo/name).mkdir(parents=True, exist_ok=True)
        cli = self.repo/'quickshell/scripts/selfshell'
        cli.write_text('#!/bin/bash\nexit "${FAIL_DOCTOR:-0}"\n')
        cli.chmod(0o755)
        shutil.copy2(ROOT/'quickshell/scripts/update_config.py', self.repo/'quickshell/scripts/update_config.py')
        (self.repo/'quickshell/services/qs-bt-agent').write_text('agent')
        (self.repo/'quickshell/services/qs-bt-agent.service').write_text('new unit')
        (self.repo/'quickshell/shell.qml').write_text('new shell')
        (self.repo/'fish/config.fish').write_text('exec uwsm start hyprland.desktop\n')
        bindir = self.root/'bin'
        bindir.mkdir()
        driver = bindir/'driver'
        driver.write_text(DRIVER)
        driver.chmod(0o755)
        for name in ('sudo','pacman','systemctl','systemd-detect-virt','rfkill',
                     'yay','kcd','selftrack','ya','magick','gsettings','sleep','cp'):
            (bindir/name).symlink_to(driver)
        runtime = self.root/'runtime'
        runtime.mkdir()
        self.env = dict(os.environ, INSTALL_TEST_ROOT=str(self.root),
                        INSTALL_TEST_HOME=str(self.home), XDG_RUNTIME_DIR=str(runtime),
                        PATH=str(bindir)+':'+os.environ['PATH'])

    def run_install(self, *args, input='', **env):
        return subprocess.run(['bash', str(self.repo/'install.sh'), *args],
                              env=dict(self.env, **env), input=input,
                              capture_output=True, text=True, timeout=15)

    def commands(self):
        path = self.root/'commands'
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def seed_existing(self):
        target = self.home/'.config/quickshell'
        target.mkdir(parents=True)
        (target/'original').write_text('old shell')
        unit = self.home/'.config/systemd/user/qs-bt-agent.service'
        unit.parent.mkdir(parents=True)
        unit.write_text('old unit')
        cli = self.home/'.local/bin/selfshell'
        cli.parent.mkdir(parents=True)
        cli.symlink_to('/old/cli')

    def test_no_is_read_only_on_fresh_and_existing_setup(self):
        self.assertEqual(self.run_install('--no').returncode, 0)
        self.assertEqual(list(self.home.iterdir()), [])
        self.seed_existing()
        self.assertEqual(self.run_install('--no').returncode, 0)
        self.assertEqual(self.commands(), [])
        self.assertTrue((self.home/'.config/quickshell/original').exists())

    def test_decline_precedes_system_changes(self):
        self.seed_existing()
        self.assertEqual(self.run_install(input='n\n').returncode, 0)
        self.assertEqual(self.commands(), [])

    def test_dependency_failure_stops_before_config_copy(self):
        result = self.run_install('--yes', FAIL_PACKAGES='1')
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertFalse((self.home/'.config/quickshell').exists())

    def test_partial_copy_is_removed_on_fresh_install(self):
        self.assertNotEqual(self.run_install('--yes', FAIL_COPY='1').returncode, 0)
        self.assertFalse((self.home/'.config/quickshell').exists())

    def test_partial_copy_restores_existing_config(self):
        self.seed_existing()
        self.assertNotEqual(self.run_install('--yes', FAIL_COPY='1').returncode, 0)
        self.assertEqual((self.home/'.config/quickshell/original').read_text(), 'old shell')
        self.assertFalse((self.home/'.config/quickshell/partial').exists())

    def test_doctor_failure_restores_files_and_never_enables_greetd(self):
        self.seed_existing()
        result = self.run_install('--yes', FAIL_DOCTOR='1')
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual((self.home/'.config/systemd/user/qs-bt-agent.service').read_text(), 'old unit')
        self.assertEqual(os.readlink(self.home/'.local/bin/selfshell'), '/old/cli')
        self.assertFalse((self.home/'Screenshots').exists())
        self.assertFalse(any('enable' in cmd for cmd in self.commands()))

    def test_display_manager_failure_restores_previous_alias(self):
        alias = self.root/'system/etc/systemd/system/display-manager.service'
        alias.parent.mkdir(parents=True)
        alias.symlink_to('/usr/lib/systemd/system/sddm.service')
        result = self.run_install('--yes', FAIL_GREETD='1')
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(os.readlink(alias), '/usr/lib/systemd/system/sddm.service')
        self.assertFalse((self.home/'.config/quickshell').exists())

    def test_success_keeps_current_session_and_uses_detected_selftrack(self):
        result = self.run_install('--yes')
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertFalse(any('stop' in cmd or 'disable' in cmd for cmd in self.commands()))
        unit = (self.home/'.config/systemd/user/selftrack-daemon.service').read_text()
        self.assertIn(str(self.root/'bin/selftrack'), unit)


if __name__ == '__main__':
    unittest.main()
