#!/usr/bin/env python3
# ============================================================
# tests/qml_smoke.py — ізольований runtime-контракт AppConfig та IPC
# без вікон, системних дій і запису до живого конфігу.
# ============================================================
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='selfshell-qml-smoke-') as tmp:
    base = Path(tmp)
    (base/'core').mkdir()
    (base/'data').mkdir()
    (base/'scripts').mkdir()
    (base/'runtime').mkdir(mode=0o700)
    shutil.copy2(ROOT/'quickshell/core/AppConfig.qml', base/'core/AppConfig.qml')
    shutil.copy2(ROOT/'quickshell/scripts/selfshell', base/'scripts/selfshell')
    (base/'data/config.json').write_text('{"themeMode":"black","uiScale":1.25}')
    (base/'shell.qml').write_text('''import Quickshell
import Quickshell.Io
import QtQuick
import "core"
ShellRoot {
  AppConfig { id: config }
  IpcHandler {
    target: "lockscreen"
    function isLocked(): bool { return false }
    function quitIfUnlocked(): void { if (config.flushSave()) Qt.quit() }
  }
  IpcHandler {
    target: "test"
    function set(key: string, value: string): bool { return config.setValue(key, value) }
    function pendingScale(): void { config.cfg.uiScale = 1.3; config.saveSoon() }
    function stop(): void { Qt.quit() }
  }
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM='wayland', XDG_RUNTIME_DIR=str(base/'runtime'))
    display = os.environ['WAYLAND_DISPLAY']
    if not os.path.isabs(display):
        display = os.path.join(os.environ['XDG_RUNTIME_DIR'], display)
    env['WAYLAND_DISPLAY'] = display
    log = (base/'qs.log').open('w+')
    proc = subprocess.Popen(['qs','-p',str(base),'--no-color'], env=env, stdout=log, stderr=subprocess.STDOUT)
    def ipc(*args):
        return subprocess.run(['qs','ipc','-p',str(base),'call','test',*args], env=env,
                              capture_output=True, text=True, timeout=3)
    def diagnostics():
        paths = [base/'qs.log', *(base/'runtime').rglob('log.log')]
        return '\n'.join(str(path) + '\n' + path.read_text(errors='replace') for path in paths)
    def wait_for_stop():
        for _ in range(50):
            listed = subprocess.run(['qs','list','-p',str(base),'--json'], env=env,
                                    capture_output=True, text=True, timeout=3)
            assert listed.returncode == 0, listed.stderr
            if listed.stdout.startswith('No running instances for ') or listed.stdout.strip() == '[]':
                return
            time.sleep(.1)
        raise AssertionError('Test shell did not stop:\n' + listed.stdout + diagnostics())
    try:
        result = None
        for _ in range(50):
            result = ipc('set','themeMode','"matugen"')
            if result.returncode == 0:
                break
            if proc.poll() is not None:
                log.seek(0)
                raise AssertionError(log.read())
            time.sleep(.1)
        assert result.returncode == 0, result.stderr
        assert result.stdout.strip() == 'true', result.stdout
        listed = subprocess.run(['qs','list','-p',str(base),'--json'], env=env,
                                capture_output=True, text=True, check=True)
        assert isinstance(json.loads(listed.stdout), list) and json.loads(listed.stdout)
        for _ in range(30):
            data = json.loads((base/'data/config.json').read_text())
            if data.get('themeMode') == 'matugen':
                break
            time.sleep(.1)
        assert data['themeMode'] == 'matugen', data
        assert data['uiScale'] == 1.25, data
        assert ipc('set','uiScale','true').stdout.strip() == 'false'
        for attempt in range(2):
            assert ipc('pendingScale').returncode == 0
            reload = subprocess.run(['bash', str(base/'scripts/selfshell'), 'reload'], env=env,
                                    capture_output=True, text=True, timeout=10)
            assert reload.returncode == 0, f'Reload {attempt + 1}:\n' + reload.stdout + reload.stderr + diagnostics()
            assert not reload.stderr, reload.stderr
            assert json.loads((base/'data/config.json').read_text())['uiScale'] == 1.3
        ipc('stop')
        wait_for_stop()
        started = subprocess.run(['bash', str(base/'scripts/selfshell'), 'reload'], env=env,
                                 capture_output=True, text=True, timeout=10)
        assert started.returncode == 0, started.stdout + started.stderr + diagnostics()
        assert not started.stderr, started.stderr
        ipc('stop')
        wait_for_stop()
        proc.wait(timeout=3)
        print('QML runtime: scoped IPC, AppConfig persistence, consecutive reloads and stopped startup passed')
    finally:
        try:
            ipc('stop')
        except (OSError, subprocess.TimeoutExpired):
            pass
        if proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=3)
        log.close()
