#!/usr/bin/env python3
# ============================================================
# tests/theme_smoke.py — ізольована перевірка редактора, збереження й застосування власних тем.
# ============================================================
from pathlib import Path
import tempfile, shutil, subprocess, os
repo=Path(__file__).resolve().parents[1]/'quickshell'
with tempfile.TemporaryDirectory(prefix='selfshell-theme-test-') as directory:
    base=Path(directory)
    for name in ('core','popups','scripts','data'):
        shutil.copytree(repo/name,base/name)
    (base/'runtime').mkdir(mode=0o700)
    (base/'bin').mkdir()
    (base/'bin/pkill').write_text('#!/bin/sh\nexit 0\n')
    (base/'bin/pkill').chmod(0o755)
    (base/'shell.qml').write_text('''import Quickshell
import QtQuick
import "core"
import "popups"
ShellRoot {
  PaletteService { id: pal }
  AppConfig { id: ac }
  Item { id: wp; property bool applying: false }
  CustomThemes { id: themes; palette: pal; appConfig: ac; wallpapers: wp }
  PanelWindow { id: win; visible: false; property var palette: pal; property var appConfig: ac; property var customThemes: themes; property var wallpaperController: wp }
  SettingsPopup { id: settingsPopup; window: win; section: 3; visible: false }
  Component.onCompleted: ac.cfg.themeMode = "custom"
  function find(item, name) {
    if (item.objectName === name) return item
    var children = item.children ?? []
    for (var i = 0; i < children.length; i++) {
      var found = find(children[i], name)
      if (found) return found
    }
    return null
  }
  property int phase: 0
  property int attempts: 0
  Timer { interval: 150; running: true; repeat: true; onTriggered: {
    try {
      if (phase === 0) {
        if (ac.cfg.themeMode !== "custom") { ac.cfg.themeMode = "custom"; return }
        var content = settingsPopup.content[0]
        var section = find(content, "settingsSectionLoader")
        if (!section || section.status === Loader.Loading) { if (++attempts > 30) throw new Error("Appearance load timeout"); return }
        if (section.status !== Loader.Ready || section.item.implicitHeight <= 0) throw new Error("Appearance failed to load")
        var editor = find(content, "customThemeEditorLoader")
        if (!editor || editor.status === Loader.Loading) { if (++attempts > 30) throw new Error("Custom editor load timeout"); return }
        if (editor.status !== Loader.Ready || editor.item.implicitHeight <= 0) throw new Error("Custom editor failed to load: " + editor.status)
        var preview = find(content, "themePreview")
        if (!preview || preview.status !== Loader.Ready || preview.height <= 0) throw new Error("Theme preview failed to load")
        if (pal.colorKeys.length !== 30) throw new Error("Missing palette fields")
        themes.capture()
        themes.draftName = "Runtime test"
        themes.setColor("accent", "#abcdef")
        if (preview.item.c("accent") !== "#abcdef") throw new Error("Preview did not update")
        themes.setColor("hoverOverlay", "#37123456")
        var id = themes.save(false)
        if (!id) throw new Error(themes.status)
        themes.load(id)
        if (themes.draft.accent !== "#abcdef") throw new Error("Save/load failed")
        themes.setColor("accent", "#ff0000")
        themes.applySaved(id)
        phase = 1
      } else {
        if (themes.busy) { if (++attempts > 50) throw new Error("Apply timeout"); return }
        if (themes.failed) throw new Error(themes.status)
        if (ac.cfg.themeMode !== "custom") throw new Error("Mode not committed")
        if (pal.accent !== "#abcdef" || pal.hoverOverlay !== "#37123456") throw new Error("Palette not applied")
        themes.draftName = "Copy"
        themes.save(true)
        if (themes.themes.length !== 2) throw new Error("Duplicate failed")
        themes.removeSaved(themes.editingId)
        if (themes.themes.length !== 1) throw new Error("Delete failed")
        console.log("CUSTOM_RUNTIME_PASS")
        Qt.quit()
      }
    } catch (e) { console.error("CUSTOM_RUNTIME_FAIL", e); Qt.quit() }
  } }
}''')
    env=dict(os.environ, HOME=str(base), PATH=str(base/'bin')+':'+os.environ['PATH'], QT_QPA_PLATFORM='wayland', XDG_RUNTIME_DIR=str(base/'runtime'), WAYLAND_DISPLAY=str(Path(os.environ['XDG_RUNTIME_DIR'])/os.environ['WAYLAND_DISPLAY']))
    proc=subprocess.run(['qs','-p',str(base),'--no-color'],env=env,capture_output=True,text=True,timeout=20)
    output=proc.stdout+proc.stderr
    print(output)
    if 'CUSTOM_RUNTIME_PASS' not in output or 'CUSTOM_RUNTIME_FAIL' in output:
        raise SystemExit(1)
