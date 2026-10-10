#!/usr/bin/env python3
# ============================================================
# quickshell/scripts/update_config.py — підготовка, перевірка та відкат оновлення встановлених компонентів.
# ============================================================
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import sys
import tarfile
import tempfile
import subprocess

COMPONENTS = ('quickshell', 'hypr', 'fish', 'kitty', 'starship', 'yazi', 'fastfetch')
LOCAL = ('data/config.json', 'data/palette.json', 'data/eq.json',
         'data/calendar-tasks.json', 'data/control-state.json',
         'data/launcher-usage.json', 'data/updates.json', 'data/last-shot.txt',
         'scripts/.env', 'scripts/.genshin_state.json', 'scripts/.genshin_requests.log',
         'wp', '.qmlls.ini', '.opencode', '.selfshell-install.json')
HYPR_LOCAL = ('env.json', 'binds.json', 'visual.json', 'local.lua')
GENERATED = {'kitty': ('current-theme.conf',), 'fish': ('conf.d/99-palette.fish', 'fish_variables'),
             'yazi': ('yazi.toml', 'keymap.toml', 'theme.toml', 'flavors/palette.yazi'), 'starship': ('config.toml',)}
MANIFEST = '.selfshell-install.json'


def personal(component, name):
    local = LOCAL if component == 'quickshell' else HYPR_LOCAL if component == 'hypr' else GENERATED.get(component, ())
    return any(name == p or name.startswith(p + '/') for p in local) or '__pycache__' in Path(name).parts


def refresh_personal(entry):
    component = entry.get('component')
    paths = LOCAL if component == 'quickshell' else HYPR_LOCAL if component == 'hypr' else GENERATED.get(component, ())
    for name in paths:
        if name == MANIFEST:
            continue
        live, staged = Path(entry['target'])/name, Path(entry['stage'])/name
        exists = live.exists() or live.is_symlink()
        if not exists and name not in entry.get('personalExisted', []):
            continue
        if staged.is_symlink() or staged.is_file():
            staged.unlink()
        elif staged.is_dir():
            shutil.rmtree(staged)
        if exists:
            staged.parent.mkdir(parents=True, exist_ok=True)
            if live.is_dir() and not live.is_symlink():
                shutil.copytree(live, staged, symlinks=True)
            else:
                shutil.copy2(live, staged, follow_symlinks=False)


def owned_files(directory, component):
    return sorted(str(p.relative_to(directory)) for p in directory.rglob('*')
                  if (p.is_file() or p.is_symlink()) and not personal(component, str(p.relative_to(directory))))


def read_manifest(config):
    path = config / MANIFEST
    if not path.exists():
        return {'schema': 1, 'components': ['quickshell'], 'files': {}, 'userUnit': False}
    data = json.loads(path.read_text())
    if not isinstance(data, dict) or data.get('schema') != 1 or not isinstance(data.get('components'), list):
        raise ValueError('Unsupported installation manifest')
    if 'quickshell' not in data['components'] or any(c not in COMPONENTS for c in data['components']):
        raise ValueError('Invalid managed components')
    if len(set(data['components'])) != len(data['components']):
        raise ValueError('Duplicate managed components')
    if not isinstance(data.get('files', {}), dict) or not isinstance(data.get('hashes', {}), dict):
        raise ValueError('Invalid owned files/hashes')
    for names in data.get('files', {}).values():
        if not isinstance(names, list):
            raise ValueError('Invalid owned files')
        for name in names:
            if not isinstance(name, str) or Path(name).is_absolute() or '..' in Path(name).parts:
                raise ValueError('Invalid owned path')
    for component, values in data.get('hashes', {}).items():
        if component not in data['components'] or not isinstance(values, dict):
            raise ValueError('Invalid component hashes')
        for name, digest in values.items():
            if name not in data.get('files', {}).get(component, []) or not isinstance(digest, str) or len(digest) != 64:
                raise ValueError('Invalid owned hash')
    return data


def record_install(source, config, components):
    files = {c: owned_files(source / c, c) for c in components}
    data = {'schema': 1, 'components': list(components),
            'userUnit': (config.parent/'systemd/user/qs-bt-agent.service').is_file(),
            'paletteIntegrations': [c for c in components if c in ('kitty','fish','starship','yazi')],
            'files': files, 'hashes': {c: hashes(source/c, files[c]) for c in components}}
    if data['userUnit']:
        data['unitHash'] = hashlib.sha256((config.parent/'systemd/user/qs-bt-agent.service').read_bytes()).hexdigest()
    atomic_json(config / MANIFEST, data)


def adopt_install(source, config, components):
    # Реєстрація наявної інсталяції не має приховувати локальні зміни
    # чи вмикати генерацію тем без попереднього вибору користувача.
    data = read_manifest(config)
    selected = list(dict.fromkeys([*data['components'], *components]))
    if any(c not in COMPONENTS for c in selected):
        raise ValueError('Unknown managed component')
    for component in selected:
        target = config if component == 'quickshell' else config.parent/component
        if not target.is_dir() or target.is_symlink():
            raise ValueError('Not an installed component directory: ' + str(target))
        names = owned_files(source/component, component)
        if not (source/component).is_dir():
            raise ValueError('Missing source component: ' + component)
        for name in names:
            path = target/name
            if path.is_symlink() or not path.is_file() or path.read_bytes() != (source/component/name).read_bytes():
                raise ValueError('Installed source differs; merge before adopting: ' + str(path))
        previous = [n for n in data.get('files', {}).get(component, []) if not personal(component, n)]
        data.setdefault('files', {})[component] = sorted(set(previous + names))
        previous_hashes = {n: h for n, h in data.get('hashes', {}).get(component, {}).items() if n in previous}
        data.setdefault('hashes', {})[component] = {**previous_hashes, **hashes(source/component, names)}
    data['components'] = selected
    unit = config.parent/'systemd/user/qs-bt-agent.service'
    if unit.is_file() and not unit.is_symlink() and unit.read_bytes() == (source/'quickshell/services/qs-bt-agent.service').read_bytes():
        data['userUnit'] = True
        data['unitHash'] = hashlib.sha256(unit.read_bytes()).hexdigest()
    atomic_json(config/MANIFEST, data)


def atomic_json(path, data):
    tmp = path.with_name(path.name + '.tmp')
    tmp.write_text(json.dumps(data, indent=2) + '\n')
    tmp.replace(path)


def hashes(directory, names):
    return {n: hashlib.sha256((directory/n).read_bytes()).hexdigest() for n in names}


def unpack(archive, destination):
    with tarfile.open(archive, 'r:gz') as tf:
        tf.extractall(destination, filter='data')
    candidates = [p for p in destination.iterdir() if p.is_dir() and (p/'quickshell/shell.qml').is_file()]
    if len(candidates) != 1:
        raise ValueError('Archive must contain one SELFshell repository')
    return candidates[0]


def prepare(archive, config):
    for journal in config.parent.glob('.selfshell-update-*/transaction.json'):
        previous = json.loads(journal.read_text())
        if not previous.get('complete') and (previous.get('pending') or previous.get('applied')):
            raise ValueError('Unfinished update; roll it back before retrying: ' + str(journal.parent))
    manifest = read_manifest(config)
    transaction = Path(tempfile.mkdtemp(prefix='.selfshell-update-', dir=config.parent))
    try:
        source_dir = transaction/'source'
        source_dir.mkdir()
        source = unpack(archive, source_dir)
        if any(p.is_symlink() for p in source.rglob('*')):
            raise ValueError('Package files must not be symlinks')
        for name in ('data/config.json', 'data/palette.json'):
            json.loads((source/'quickshell'/name).read_text())
        for file in ('shell.qml', 'Bar.qml', 'VERSION', 'scripts/selfshell', 'scripts/update_config.py', 'scripts/config_ctl.py', 'scripts/sleep_guard.py'):
            if not (source/'quickshell'/file).is_file():
                raise ValueError('Incomplete Quickshell archive: ' + file)
        subprocess_check(source)
        entries = []
        for component in manifest['components']:
            new = source/component
            if not new.is_dir():
                raise ValueError('Archive is missing managed component: ' + component)
            target = config if component == 'quickshell' else config.parent/component
            if target.is_symlink():
                raise ValueError('Managed component is a symlink: ' + str(target))
            stage = transaction/('stage-' + component)
            if target.exists():
                shutil.copytree(target, stage, symlinks=True)
            else:
                stage.mkdir()
            for name, previous in manifest.get('hashes', {}).get(component, {}).items():
                old = stage/name
                if old.is_file() and not personal(component, name):
                    actual = hashlib.sha256(old.read_bytes()).hexdigest()
                    if actual != previous and (not (new/name).is_file() or old.read_bytes() != (new/name).read_bytes()):
                        raise ValueError('Locally edited managed file; resolve before updating: ' + str(target/name))
            # Видаляємо лише файли, якими володів попередній пакет.
            # Невідомі користувацькі файли та персональний стан лишаються.
            for name in manifest.get('files', {}).get(component, []):
                if not personal(component, name) and not (new/name).exists():
                    old = stage/name
                    if old.is_file() or old.is_symlink():
                        old.unlink()
            for path in new.rglob('*'):
                name = str(path.relative_to(new))
                if personal(component, name) and (stage/name).exists():
                    continue
                out = stage/name
                if path.is_dir():
                    if out.is_symlink():
                        raise ValueError('Refusing to write through symlink: ' + str(out))
                    out.mkdir(parents=True, exist_ok=True)
                else:
                    previous_files = manifest.get('files', {}).get(component)
                    if previous_files is not None and name not in previous_files and not personal(component, name) and out.is_file() and out.read_bytes() != path.read_bytes():
                        raise ValueError('New package file conflicts with a user file: ' + str(target/name))
                    # Збережений локальний symlink не має спрямувати запис поза stage.
                    if out.is_symlink():
                        out.unlink()
                    if path.is_symlink():
                        raise ValueError('Package files must not be symlinks: ' + name)
                    shutil.copy2(path, out)
            manifest.setdefault('files', {})[component] = owned_files(new, component)
            manifest.setdefault('hashes', {})[component] = hashes(new, manifest['files'][component])
            local = LOCAL if component == 'quickshell' else HYPR_LOCAL if component == 'hypr' else GENERATED.get(component, ())
            entries.append({'target': str(target), 'stage': str(stage), 'component': component,
                            'personalExisted': [n for n in local if (target/n).exists() or (target/n).is_symlink()],
                            'backup': str(transaction/('backup-' + component))})
        atomic_json(transaction/'stage-quickshell'/MANIFEST, manifest)
        if manifest.get('userUnit'):
            target = config.parent/'systemd/user/qs-bt-agent.service'
            unit = source/'quickshell/services/qs-bt-agent.service'
            previous = manifest.get('unitHash')
            if previous and target.is_file() and hashlib.sha256(target.read_bytes()).hexdigest() != previous and target.read_bytes() != unit.read_bytes():
                raise ValueError('Locally edited managed unit; resolve before updating: ' + str(target))
            target.parent.mkdir(parents=True, exist_ok=True)
            stage = transaction/'stage-agent.service'
            shutil.copy2(unit, stage)
            manifest['unitHash'] = hashlib.sha256(unit.read_bytes()).hexdigest()
            atomic_json(transaction/'stage-quickshell'/MANIFEST, manifest)
            entries.append({'target': str(target), 'stage': str(stage),
                            'backup': str(transaction/'backup-agent.service')})
        atomic_json(transaction/'transaction.json', {'entries': entries, 'applied': [], 'pending': None})
        return transaction
    except BaseException:
        shutil.rmtree(transaction)
        raise


def subprocess_check(source):
    subprocess.run(['bash', '-n', str(source/'quickshell/scripts/selfshell')], check=True)
    compile((source/'quickshell/scripts/update_config.py').read_text(), 'update_config.py', 'exec')
    if shutil.which('qs') and os.environ.get('WAYLAND_DISPLAY'):
        compile_qml(source/'quickshell')


def compile_qml(config):
    paths = [p.resolve().as_uri() for p in config.rglob('*.qml')]
    if not paths:
        raise ValueError('No QML files to validate')
    with tempfile.TemporaryDirectory(prefix='ss-qml-') as tmp:
        root = Path(tmp)
        (root/'runtime').mkdir(mode=0o700)
        qml = '''import Quickshell
import Quickshell.Wayland
import QtQuick
ShellRoot { Timer { interval: 1; running: true; onTriggered: {
  var paths = %s;
  var failed = 0;
  for (var i=0; i<paths.length; i++) {
    var c = Qt.createComponent(paths[i], Component.PreferSynchronous);
    if (c.status !== Component.Ready) {
      console.error("SELF_COMPILE_ERROR", paths[i], c.errorString()); failed++;
    }
  }
  console.log("SELF_COMPILE_DONE", paths.length, failed);
} } }
''' % json.dumps(paths)
        (root/'shell.qml').write_text(qml)
        env = dict(os.environ, QT_QPA_PLATFORM='wayland', XDG_RUNTIME_DIR=str(root/'runtime'))
        display = os.environ.get('WAYLAND_DISPLAY', '')
        if not display:
            raise ValueError('QML validation needs a Wayland compositor (use headless Weston in CI)')
        if not os.path.isabs(display):
            display = os.path.join(os.environ.get('XDG_RUNTIME_DIR', ''), display)
        env['WAYLAND_DISPLAY'] = display
        proc = subprocess.Popen(['qs', '-p', str(root), '--no-color'], env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        try:
            output, _ = proc.communicate(timeout=3)
        except subprocess.TimeoutExpired:
            proc.terminate()
            output, _ = proc.communicate(timeout=3)
        marker = 'SELF_COMPILE_DONE ' + str(len(paths)) + ' 0'
        if marker not in output or 'SELF_COMPILE_ERROR' in output:
            raise ValueError('QML validation failed:\n' + output)
        print('QML compile: ' + str(len(paths)) + ' components passed', file=sys.stderr)


def rollback(transaction, data):
    if data.get('complete'):
        raise ValueError('Update is already committed; remaining backups are cleanup files')
    entries = list(data['applied'])
    if data.get('pending') is not None:
        entries.append(data['pending'])
    for entry in reversed(entries):
        target, backup = Path(entry['target']), Path(entry['backup'])
        if backup.exists() or backup.is_symlink():
            if target.is_dir() and not target.is_symlink():
                shutil.rmtree(target)
            elif target.exists() or target.is_symlink():
                target.unlink()
            os.replace(backup, target)
        elif not entry.get('existed', True):
            if target.is_dir():
                shutil.rmtree(target)
            elif target.exists() or target.is_symlink():
                target.unlink()
    data['applied'] = []
    data['pending'] = None
    atomic_json(transaction/'transaction.json', data)


def apply(transaction):
    journal = transaction/'transaction.json'
    data = json.loads(journal.read_text())
    if data.get('complete') or data.get('applied') or data.get('pending'):
        raise ValueError('Transaction already applied or interrupted; recover before retrying')
    try:
        # Shell зупинено CLI перед apply; підхоплюємо зміни, зроблені
        # користувачем під час завантаження й перевірки пакета.
        for entry in data['entries']:
            refresh_personal(entry)
        for entry in data['entries']:
            target, stage, backup = (Path(entry[k]) for k in ('target', 'stage', 'backup'))
            entry['existed'] = target.exists() or target.is_symlink()
            data['pending'] = entry
            atomic_json(journal, data)
            if entry['existed']:
                os.replace(target, backup)
            os.replace(stage, target)
            data['applied'].append(entry)
            data['pending'] = None
            atomic_json(journal, data)
    except BaseException:
        rollback(transaction, data)
        raise


def commit(transaction):
    data = json.loads((transaction/'transaction.json').read_text())
    if data.get('pending') is not None or len(data['applied']) != len(data['entries']):
        raise ValueError('Cannot commit an incomplete update')
    data['complete'] = True
    atomic_json(transaction/'transaction.json', data)
    try:
        shutil.rmtree(transaction)
    except OSError as exc:
        print('warning: Update committed; remove leftover backups: ' + str(exc), file=sys.stderr)


def discard(transaction):
    data = json.loads((transaction/'transaction.json').read_text())
    if data.get('applied') or data.get('pending'):
        raise ValueError('Cannot discard recovery files of an applied update')
    shutil.rmtree(transaction)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('prepare', 'apply', 'record', 'adopt', 'check', 'commit', 'rollback', 'discard', 'enable', 'disable'))
    parser.add_argument('path', type=Path)
    parser.add_argument('config', nargs='?', type=Path)
    parser.add_argument('components', nargs='*')
    args = parser.parse_args()
    # SIGTERM/INT проходять через finally/rollback замість обриву транзакції.
    def interrupted(_signum, _frame):
        raise InterruptedError('Update interrupted')
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        if args.action in ('enable', 'disable'):
            component = str(args.config)
            if component not in ('kitty', 'fish', 'starship', 'yazi', 'foot', 'qt6ct'):
                raise ValueError('Unknown palette integration: ' + component)
            data = read_manifest(args.path)
            enabled = set(data.get('paletteIntegrations', []))
            if args.action == 'enable':
                enabled.add(component)
            else:
                enabled.discard(component)
            data['paletteIntegrations'] = sorted(enabled)
            atomic_json(args.path/MANIFEST, data)
        elif args.action == 'check':
            compile_qml(args.path)
        elif args.action == 'record':
            record_install(args.path, args.config, args.components)
        elif args.action == 'adopt':
            import fcntl
            with (Path(os.environ['XDG_RUNTIME_DIR'])/'selfshell-update.lock').open('a') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                adopt_install(args.path, args.config, args.components)
        elif args.action == 'prepare':
            print(prepare(args.path, args.config))
        elif args.action == 'commit':
            commit(args.path)
        elif args.action == 'rollback':
            rollback(args.path, json.loads((args.path/'transaction.json').read_text()))
        elif args.action == 'discard':
            discard(args.path)
        else:
            apply(args.path)
    except Exception as exc:
        print('error: ' + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
