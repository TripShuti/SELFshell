#!/usr/bin/env python3
# ============================================================
# quickshell/scripts/config_ctl.py — валідація CLI-налаштувань та офлайн-запис конфігурації.
# ============================================================
import argparse
import json
import math
from pathlib import Path
import re
from update_config import atomic_json

ROOT = Path(__file__).resolve().parents[1]

DESCRIPTIONS = {'launcherEnabled': 'Launcher',
 'workspacesEnabled': 'Workspaces',
 'mprisEnabled': 'MPRIS player',
 'clockEnabled': 'Clock',
 'timerEnabled': 'Timer',
 'selftrackEnabled': 'Time tracking widget (requires selftrack daemon)',
 'genshinEnabled': 'Genshin widget',
 'keyboardEnabled': 'Keyboard layout',
 'audioEnabled': 'Audio',
 'controlEnabled': 'Control center',
 'clipboardEnabled': 'Clipboard history',
 'btEnabled': 'Bluetooth',
 'netEnabled': 'Network',
 'trayEnabled': 'System tray',
 'batteryEnabled': 'Battery (the widget hides itself when no battery exists)',
 'kcdEnabled': 'Phone (kcd/KDE Connect) — battery, ping/ring, share, clipboard, SFTP, notifications',
 'kcdDndEnabled': 'Phone DND — only popup history, no toasts/sound/ControlCenter (kcd only)',
 'dndEnabled': 'Do-not-disturb — hides all notifications',
 'autoPowerSaver': 'Auto power-saver — drop to the power-saver power profile at low battery (≤15%), restore '
                   'the manual profile on charge (Settings → System)',
 'timerSoundPath': 'Custom timer sound ("" = from assets/)',
 'idleLockTimeout': 'Idle time before the screen locks, seconds (0 = never)',
 'idleDpmsTimeout': 'Idle time before the screen turns off (DPMS off), seconds (0 = never)',
 'idleSuspendTimeout': 'Idle time before suspend, seconds (0 = never)',
 'audioStep': 'Mouse-wheel volume step (0–1)',
 'brightnessStep': 'Mouse-wheel brightness step (0–100)',
 'barHeight': 'Bar height in pixels',
 'barRadius': 'Bar pill corner radius',
 'barPos': 'Bar edge: top or bottom',
 'edgeMargin': 'Gap from the screen edge to the side pills, px',
 'pillPadding': 'Inner padding of a pill, px',
 'contentSpacing': 'Gap between widgets inside a pill, px',
 'barAutoHide': 'Slide the bar behind the screen edge; hover the 6px edge strip to bring it back',
 'leftPillEnabled': 'Show the left pill as a whole (its widgets stay configured)',
 'centerPillEnabled': 'Show the center pill as a whole',
 'rightPillEnabled': 'Show the right pill as a whole',
 'leftOrder': 'Widget names in the left pill (including sep-N)',
 'centerOrder': 'Widget names in the center pill',
 'rightOrder': 'Widget names in the right pill',
 'popupBgOpacity': 'Popup background opacity (0.0–1.0)',
 'popupBgLighten': 'Popup background gradient lighten; 1.0 = flat color (1.0–2.0)',
 'popupRadius': 'Popup corner radius, px (0–24)',
 'popupBorderWidth': 'Popup border width, px (0–4)',
 'toastRadius': 'Notification toast corner radius, px (0–24)',
 'toastLighten': 'Toast background gradient lighten (1.0–2.0)',
 'toastBgOpacity': 'Toast background opacity (0.0–1.0)',
 'osdRadius': 'OSD corner radius, px (0–24)',
 'osdLighten': 'OSD background gradient lighten (1.0–2.0)',
 'osdBgOpacity': 'OSD background opacity (0.0–1.0)',
 'barLighten': 'Bar pill gradient lighten; 1.0 = flat color (1.0–2.0)',
 'barBgOpacity': 'Pill background opacity multiplier; 1.0 = palette color as-is (0.0–1.0)',
 'barBorderWidth': 'Pill outline width, px; 0 = no border (0–4)',
 'barBackEnabled': 'Solid full-width bar behind the floating pills',
 'barBackOpacity': 'Solid bar background opacity (0–1.0)',
 'barBackLighten': 'Solid bar gradient lighten; 1.0 = flat color (1.0–2.0)',
 'barBackBorderWidth': 'Edge line width on the inner bar edge, px; 0 = no line (0–4)',
 'separatorOpacity': 'Separator line opacity between widget groups (0–1.0)',
 'separatorGlowOpacity': 'Separator glow opacity (0–0.5)',
 'uiScale': 'Global multiplier for all text/icon-glyph sizes in bar, popups and settings (0.8–1.5)',
 'animationsEnabled': 'Master switch for all shell animations (hover, popups, sliders, lock screen)',
 'animSpeed': 'Multiplier for every animation duration; e.g. 1.5 = 50% slower, 0.5 = 2× faster (0.5–2.0)',
 'preferredPlayer': 'Favorite media player identity substring (spotify, chromium …), shared by bar widget '
                    'and popup',
 'themeMode': 'Theming mode: black (static mono #121212 + one steel accent via update-palette.py --theme '
              'black, wallpapers switch without regeneration) or matugen (dynamic palette from wallpaper via '
              'update-palette.sh)'}

PALETTE_APPS = ("kitty", "fish", "starship", "yazi", "foot", "qt6ct")


def qml_object(name):
    text = (ROOT/'core/AppConfig.qml').read_text()
    body = re.search(r'property var ' + name + r': \(\{(.*?)\n  \}\)', text, re.S).group(1)
    return json.loads('{' + re.sub(r'\b(\w+)\s*:', r'"\1":', body) + '}')


def defaults():
    return qml_object('defaultCfg')


def parsed_value(raw):
    try:
        return json.loads(raw)
    except ValueError:
        return raw


def validate(key, value):
    schema = defaults()
    if key not in schema:
        raise ValueError('Unknown configuration key: ' + key)
    expected = schema[key]
    if isinstance(expected, list):
        valid = isinstance(value, list) and all(isinstance(v, str) for v in value)
    elif isinstance(expected, (int, float)) and not isinstance(expected, bool):
        valid = isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)
        if isinstance(expected, int):
            valid = valid and isinstance(value, int)
    else:
        valid = type(value) is type(expected)
    if not valid:
        raise ValueError('Invalid value type for ' + key)
    if key == 'themeMode' and value not in ('black', 'matugen'):
        raise ValueError('themeMode must be black or matugen')
    if key == 'barPos' and value not in ('top', 'bottom'):
        raise ValueError('barPos must be top or bottom')
    if key == 'preferredPlayer' and not value:
        raise ValueError('preferredPlayer must not be empty')
    bounds = qml_object('numericRanges').get(key)
    if bounds and not bounds[0] <= value <= bounds[1]:
        raise ValueError(f'{key} must be between {bounds[0]} and {bounds[1]}; received {value}')
    return value


def validate_snapshot(data):
    if not isinstance(data, dict):
        raise ValueError('Configuration must be an object')
    for key, value in data.items():
        validate(key, value)
    effective = defaults() | data
    active = [effective[k] for k in ('idleLockTimeout', 'idleDpmsTimeout', 'idleSuspendTimeout') if effective[k] != 0]
    if active != sorted(active) or len(active) != len(set(active)):
        raise ValueError('Idle timeouts must increase: lock < dpms < suspend (0 disables a level)')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('encode', 'set', 'reset', 'check', 'list', 'describe', 'get', 'palette-list'))
    parser.add_argument('path', type=Path)
    parser.add_argument('key', nargs='?')
    parser.add_argument('value', nargs='?')
    args = parser.parse_args()
    if args.action == 'palette-list':
        manifest = args.path.parent.parent/'.selfshell-install.json'
        enabled = json.loads(manifest.read_text()).get('paletteIntegrations', []) if manifest.exists() else []
        print(f'{"APP":<12} ENABLED')
        for app in PALETTE_APPS:
            print(f'{app:<12} {"yes" if app in enabled else "no"}')
        return
    if args.action in ('list', 'describe', 'get'):
        schema = defaults()
        current = schema | (json.loads(args.path.read_text()) if args.path.exists() else {})
        if args.action == 'list':
            print(f'{"KEY":<26} VALUE')
            for key in sorted(schema):
                if not args.key or args.key.lower() in key.lower():
                    print(f'{key:<26} {json.dumps(current[key], ensure_ascii=False)}')
            return
        if not args.key or args.key not in schema:
            raise ValueError('Unknown configuration key: ' + str(args.key) + '. Run selfshell config list.')
        key = args.key
        if args.action == 'get':
            value = current[key]
            print(value if isinstance(value, str) else json.dumps(value, ensure_ascii=False))
            return
        value = schema[key]
        kind = 'boolean' if isinstance(value, bool) else 'integer' if isinstance(value, int) else 'number' if isinstance(value, float) else 'string[]' if isinstance(value, list) else 'string'
        print(DESCRIPTIONS[key])
        print('Type: ' + kind)
        bounds = qml_object('numericRanges').get(key)
        if bounds:
            print(f'Range: {bounds[0]}–{bounds[1]}')
        if key in ('themeMode', 'barPos'):
            print('Choices: ' + ('black, matugen' if key == 'themeMode' else 'top, bottom'))
        print('Default: ' + json.dumps(value))
        print('Current: ' + json.dumps(current[key]))
        if key.startswith('idle'):
            print('Active timeouts must increase: lock < dpms < suspend; 0 disables a level.')
        if key == 'themeMode':
            print('Use selfshell theme set to apply the palette and wallpaper as well.')
        import shlex
        print('Example: selfshell config set ' + key + ' ' + shlex.quote(value if isinstance(value, str) else json.dumps(value)))
        return
    if args.action == 'reset':
        atomic_json(args.path, defaults())
        return
    if args.action == 'check':
        data = json.loads(args.path.read_text())
        validate_snapshot(data)
        return
    value = validate(args.key, parsed_value(args.value))
    if args.action == 'encode':
        print(json.dumps(value))
        return
    data = json.loads(args.path.read_text())
    if not isinstance(data, dict):
        raise ValueError('Configuration must be an object')
    data[args.key] = value
    validate_snapshot(data)
    atomic_json(args.path, data)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError) as exc:
        raise SystemExit('error: ' + str(exc))
