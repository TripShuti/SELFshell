# ============================================================
# tests/python/test_update_config.py — регресії підготовки, застосування
# та відкату оновлень без системних процесів і мережі.
# ============================================================
import importlib.util
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('update_config', ROOT/'quickshell/scripts/update_config.py')
u = importlib.util.module_from_spec(spec)
spec.loader.exec_module(u)


class UpdateFixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='selfshell-update-test-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.config = self.root/'config/quickshell'
        self.source = self.root/'source'
        for base in (self.config, self.source/'quickshell'):
            (base/'data').mkdir(parents=True)
            (base/'scripts').mkdir()
            for name in ('config.json', 'palette.json'):
                (base/'data'/name).write_text('{}')
            for name in ('shell.qml','Bar.qml','VERSION','scripts/selfshell','scripts/update_config.py','scripts/config_ctl.py','scripts/sleep_guard.py'):
                (base/name).write_text('old')
        (self.source/'hypr').mkdir()
        (self.source/'hypr/hyprland.lua').write_text('new hypr')
        u.record_install(self.source, self.config, ['quickshell', 'hypr'])
        manifest = u.read_manifest(self.config)
        manifest['userUnit'] = False
        u.atomic_json(self.config/u.MANIFEST, manifest)
        (self.source/'quickshell/shell.qml').write_text('new')
        self.archive = self.root/'update.tar.gz'
        self.addCleanup(patch.stopall)
        patch.object(u, 'subprocess_check').start()

    def prepare(self):
        with tarfile.open(self.archive, 'w:gz') as tf:
            tf.add(self.source, arcname='SELFshell-main')
        return u.prepare(self.archive, self.config)


class UpdateTest(UpdateFixture):
    def test_apply_keeps_personal_changes_made_after_preparation(self):
        (self.config/'data/calendar-tasks.json').write_text('old tasks')
        transaction = self.prepare()
        (self.config/'data/config.json').write_text('{"latest":true}')
        (self.config/'data/calendar-tasks.json').unlink()
        (self.config/'wp').mkdir()
        (self.config/'wp/personal.jpg').write_bytes(b'latest wallpaper')
        u.apply(transaction)
        self.assertEqual((self.config/'data/config.json').read_text(), '{"latest":true}')
        self.assertFalse((self.config/'data/calendar-tasks.json').exists())
        self.assertEqual((self.config/'wp/personal.jpg').read_bytes(), b'latest wallpaper')
        self.assertEqual(u.read_manifest(self.config)['hashes']['quickshell']['shell.qml'],
                         u.hashlib.sha256(b'new').hexdigest())
        u.commit(transaction)

    def test_adoption_rejects_unmerged_source_and_preserves_manifest(self):
        before = (self.config/u.MANIFEST).read_bytes()
        with self.assertRaisesRegex(ValueError, 'merge before adopting'):
            u.adopt_install(self.source, self.config, ['hypr'])
        self.assertEqual((self.config/u.MANIFEST).read_bytes(), before)

    def test_adoption_preserves_personal_files_and_palette_choices(self):
        (self.source/'quickshell/shell.qml').write_text('old')
        for component in ('hypr', 'yazi'):
            (self.source/component).mkdir(exist_ok=True)
            (self.config.parent/component).mkdir()
            (self.source/component/'managed.conf').write_text('managed')
            (self.config.parent/component/'managed.conf').write_text('managed')
        (self.config.parent/'hypr/hyprland.lua').write_text('new hypr')
        for component, name in [('hypr','local.lua'), ('yazi','yazi.toml'), ('yazi','keymap.toml')]:
            (self.source/component/name).write_text('package')
            (self.config.parent/component/name).write_text('personal')
        manifest = u.read_manifest(self.config)
        manifest['paletteIntegrations'] = ['kitty']
        u.atomic_json(self.config/u.MANIFEST, manifest)
        u.adopt_install(self.source, self.config, ['hypr', 'yazi'])
        adopted = u.read_manifest(self.config)
        self.assertEqual(adopted['components'], ['quickshell', 'hypr', 'yazi'])
        self.assertEqual(adopted['paletteIntegrations'], ['kitty'])
        transaction = self.prepare()
        u.apply(transaction)
        for component, name in [('hypr','local.lua'), ('yazi','yazi.toml'), ('yazi','keymap.toml')]:
            self.assertEqual((self.config.parent/component/name).read_text(), 'personal')
        u.commit(transaction)

    def test_stages_preserves_state_and_updates_all_managed_components(self):
        (self.config/'data/config.json').write_text('{"custom":true}')
        (self.config/'user.txt').write_text('personal')
        transaction = self.prepare()
        self.assertEqual((self.config/'shell.qml').read_text(), 'old')
        u.apply(transaction)
        self.assertEqual((self.config/'shell.qml').read_text(), 'new')
        self.assertEqual((self.config/'data/config.json').read_text(), '{"custom":true}')
        self.assertEqual((self.config/'user.txt').read_text(), 'personal')
        self.assertEqual((self.config.parent/'hypr/hyprland.lua').read_text(), 'new hypr')
        self.assertTrue((transaction/'backup-quickshell').is_dir())
        u.commit(transaction)
        self.assertFalse(transaction.exists())

    def test_modified_owned_file_rejects_before_applying(self):
        (self.config/'shell.qml').write_text('my edit')
        with self.assertRaisesRegex(ValueError, 'Locally edited'):
            self.prepare()
        self.assertEqual((self.config/'shell.qml').read_text(), 'my edit')
        self.assertFalse(list(self.config.parent.glob('.selfshell-update-*')))

    def test_removed_owned_files_deleted_but_unknown_files_preserved(self):
        (self.source/'quickshell/obsolete.qml').write_text('obsolete')
        (self.config/'obsolete.qml').write_text('obsolete')
        manifest = u.read_manifest(self.config)
        manifest['files']['quickshell'].append('obsolete.qml')
        u.atomic_json(self.config/u.MANIFEST, manifest)
        (self.source/'quickshell/obsolete.qml').unlink()
        (self.config/'custom.qml').write_text('keep')
        transaction = self.prepare()
        u.apply(transaction)
        self.assertFalse((self.config/'obsolete.qml').exists())
        self.assertTrue((self.config/'custom.qml').exists())

    def test_apply_failure_restores_old_tree_and_new_component(self):
        transaction = self.prepare()
        rename = u.os.replace
        def fail_stage_hypr(src, dst):
            if str(src).endswith('stage-hypr'):
                raise OSError('injected rename failure')
            return rename(src, dst)
        with patch.object(u.os, 'replace', side_effect=fail_stage_hypr):
            with self.assertRaises(OSError):
                u.apply(transaction)
        self.assertEqual((self.config/'shell.qml').read_text(), 'old')
        self.assertFalse((self.config.parent/'hypr').exists())
        u.rollback(transaction, json.loads((transaction/'transaction.json').read_text()))
        self.assertEqual((self.config/'shell.qml').read_text(), 'old')

    def test_failed_startup_can_roll_back_and_rollback_is_repeatable(self):
        transaction = self.prepare()
        u.apply(transaction)
        for _ in range(2):
            u.rollback(transaction, json.loads((transaction/'transaction.json').read_text()))
        self.assertEqual((self.config/'shell.qml').read_text(), 'old')
        self.assertFalse((self.config.parent/'hypr').exists())

    def test_incomplete_transaction_cannot_commit(self):
        transaction = self.prepare()
        with self.assertRaisesRegex(ValueError, 'incomplete'):
            u.commit(transaction)
        self.assertTrue(transaction.exists())

    def test_symlink_component_rejected(self):
        (self.config.parent/'hypr').symlink_to(self.source/'hypr', target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            self.prepare()
        self.assertEqual((self.source/'hypr/hyprland.lua').read_text(), 'new hypr')

    def test_manifest_rejects_path_traversal(self):
        manifest = u.read_manifest(self.config)
        manifest['files']['quickshell'].append('../escape')
        u.atomic_json(self.config/u.MANIFEST, manifest)
        with self.assertRaisesRegex(ValueError, 'owned path'):
            self.prepare()

    def test_new_file_conflict_preserves_unowned_user_file(self):
        (self.config/'custom.qml').write_text('personal')
        (self.source/'quickshell/custom.qml').write_text('new package file')
        with self.assertRaisesRegex(ValueError, 'conflicts with a user file'):
            self.prepare()
        self.assertEqual((self.config/'custom.qml').read_text(), 'personal')

    def test_interrupted_pending_rename_is_recoverable_and_blocks_next_update(self):
        transaction = self.prepare()
        journal = transaction/'transaction.json'
        data = json.loads(journal.read_text())
        entry = data['entries'][0]
        entry['existed'] = True
        data['pending'] = entry
        u.atomic_json(journal, data)
        u.os.replace(entry['target'], entry['backup'])
        with self.assertRaisesRegex(ValueError, 'Unfinished update'):
            self.prepare()
        u.rollback(transaction, data)
        self.assertEqual((self.config/'shell.qml').read_text(), 'old')
        u.discard(transaction)
        self.assertFalse(transaction.exists())


class UpdateCliTest(UpdateFixture):
    def setUp(self):
        super().setUp()
        import os
        import shutil
        for name in ('selfshell', 'update_config.py', 'config_ctl.py', 'sleep_guard.py'):
            for base in (self.config, self.source/'quickshell'):
                shutil.copy2(ROOT/'quickshell/scripts'/name, base/'scripts'/name)
        for base in (self.config, self.source/'quickshell'):
            (base/'core').mkdir()
            shutil.copy2(ROOT/'quickshell/core/AppConfig.qml', base/'core/AppConfig.qml')
        # Фіксуємо власність до зміни пакета; helper тепер справжній.
        (self.source/'quickshell/shell.qml').write_text('old')
        u.record_install(self.source, self.config, ['quickshell', 'hypr'])
        (self.source/'quickshell/shell.qml').write_text('new')
        self.bin = self.root/'bin'
        self.bin.mkdir()
        driver = self.bin/'driver'
        driver.write_text(r'''#!/usr/bin/python3
import json, os, sys, shutil
from pathlib import Path
root=Path(os.environ['UPDATE_TEST_ROOT'])
name=Path(sys.argv[0]).name
args=sys.argv[1:]
with (root/'calls').open('a') as f: f.write(json.dumps([name,*args])+'\n')
if name=='curl':
    shutil.copy2(root/'update.tar.gz',args[args.index('-o')+1]);sys.exit(0)
if name=='git':sys.exit(1)
if name in ('sleep','systemctl'):sys.exit(0)
if name=='qs':
    config=Path(args[args.index('-p')+1])
    state=root/'running'
    if '--json' in args:
        bad=os.getenv('BAD_LIST')
        if bad and (not os.getenv('BAD_LIST_AFTER_STOP') or not state.exists()) and (not os.getenv('BAD_LIST_AFTER_START') or (root/'started-new').exists()):
            if bad=='command':
                print('injected list failure',file=sys.stderr);sys.exit(1)
            print({'empty':'', 'invalid':'invalid', 'object':'{}', 'string':'"running"'}[bad]);sys.exit(0)
        if state.exists():print('[{}]')
        elif os.getenv('EMPTY_LIST_JSON'):print('[]')
        else:print(f'No running instances for "{config.resolve()}/shell.qml"\nUse --all to list all instances.')
        sys.exit(0)
    if '-d' in args:
        if os.getenv('FAIL_NEW') and (config/'shell.qml').read_text()=='new':sys.exit(1)
        if (config/'shell.qml').read_text()=='new':(root/'started-new').touch()
        state.write_text('running');sys.exit(0)
    if 'isLocked' in args:
        print('true' if os.getenv('LOCKED') else 'false');sys.exit(0)
    if 'quitIfUnlocked' in args:
        if not os.getenv('LOCKED'):state.unlink(missing_ok=True)
        sys.exit(0)
sys.exit(1)
''')
        driver.chmod(0o755)
        for name in ('qs','curl','git','sleep','systemctl'):
            (self.bin/name).symlink_to(driver)
        runtime = self.root/'runtime'
        runtime.mkdir(mode=0o700)
        self.env = dict(os.environ, UPDATE_TEST_ROOT=str(self.root), XDG_RUNTIME_DIR=str(runtime),
                        PATH=str(self.bin)+':'+os.environ['PATH'])
        self.env.pop('WAYLAND_DISPLAY', None)
        (self.root/'running').write_text('running')

    def run_update(self, **env):
        import subprocess
        with tarfile.open(self.archive, 'w:gz') as tf:
            tf.add(self.source, arcname='SELFshell-main')
        return subprocess.run(['bash', str(self.config/'scripts/selfshell'), 'update', '--yes'],
                              env=dict(self.env, **env), capture_output=True, text=True, timeout=15)

    def test_cli_failed_new_start_restores_files_restarts_old_and_returns_failure(self):
        result = self.run_update(FAIL_NEW='1')
        self.assertNotEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual((self.config/'shell.qml').read_text(), 'old')
        self.assertTrue((self.root/'running').exists())
        self.assertFalse((self.config.parent/'hypr').exists())
        self.assertFalse(list(self.config.parent.glob('.selfshell-update-*')))
        self.assertNotIn('Traceback', result.stderr)

    def test_cli_locked_update_never_stops_or_mutates_active_tree(self):
        result = self.run_update(LOCKED='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Unlock', result.stderr)
        self.assertEqual((self.config/'shell.qml').read_text(), 'old')
        calls = [json.loads(line) for line in (self.root/'calls').read_text().splitlines()]
        self.assertFalse(any('quitIfUnlocked' in call for call in calls))
        self.assertFalse(list(self.config.parent.glob('.selfshell-update-*')))

    def test_cli_success_commits_and_only_addresses_selected_config(self):
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stderr, '')
        self.assertEqual((self.config/'shell.qml').read_text(), 'new')
        self.assertTrue((self.root/'running').exists())
        self.assertFalse(list(self.config.parent.glob('.selfshell-update-*')))
        calls = [json.loads(line) for line in (self.root/'calls').read_text().splitlines()]
        for call in calls:
            if call[0] == 'qs':
                self.assertIn('-p', call)
                self.assertEqual(call[call.index('-p')+1], str(self.config))

    def test_cli_update_while_stopped_accepts_text_and_json_empty_lists(self):
        (self.root/'running').unlink()
        for empty_json in ('', '1'):
            with self.subTest(empty_json=empty_json):
                result = self.run_update(EMPTY_LIST_JSON=empty_json)
                self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
                self.assertEqual(result.stderr, '')
                self.assertFalse((self.root/'running').exists())

    def test_cli_failed_or_malformed_list_aborts_before_stop_or_apply(self):
        for bad in ('command', 'empty', 'invalid', 'object', 'string'):
            with self.subTest(bad=bad):
                result = self.run_update(BAD_LIST=bad)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('Traceback', result.stderr)
                self.assertNotIn('Managed components updated', result.stdout)
                self.assertEqual((self.config/'shell.qml').read_text(), 'old')
                self.assertTrue((self.root/'running').exists())
                self.assertFalse(list(self.config.parent.glob('.selfshell-update-*')))
        calls = [json.loads(line) for line in (self.root/'calls').read_text().splitlines()]
        self.assertFalse(any('quitIfUnlocked' in call for call in calls))

    def test_cli_list_failure_after_quit_does_not_apply_new_files(self):
        result = self.run_update(BAD_LIST='command', BAD_LIST_AFTER_STOP='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.config/'shell.qml').read_text(), 'old')
        self.assertFalse(list(self.config.parent.glob('.selfshell-update-*')))

    def test_cli_unknown_shell_state_blocks_offline_config_mutations(self):
        import subprocess
        original = (self.config/'data/config.json').read_text()
        for args in (['set', 'themeMode', 'black'], ['reset'], ['edit']):
            with self.subTest(args=args):
                result = subprocess.run(['bash', str(self.config/'scripts/selfshell'), 'config', *args],
                                        env=dict(self.env, BAD_LIST='command', EDITOR='false'),
                                        capture_output=True, text=True, timeout=5)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('Cannot list Quickshell', result.stderr)
                self.assertEqual((self.config/'data/config.json').read_text(), original)

    def test_cli_unknown_state_after_activation_retains_recovery_files(self):
        result = self.run_update(BAD_LIST='command', BAD_LIST_AFTER_START='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Rollback deferred', result.stderr)
        self.assertNotIn('Traceback', result.stderr)
        self.assertEqual((self.config/'shell.qml').read_text(), 'new')
        self.assertTrue((self.root/'running').exists())
        transactions = list(self.config.parent.glob('.selfshell-update-*'))
        self.assertEqual(len(transactions), 1)
        self.assertEqual((transactions[0]/'backup-quickshell/shell.qml').read_text(), 'old')
