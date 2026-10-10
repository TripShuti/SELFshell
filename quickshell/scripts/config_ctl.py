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
        raise ValueError('Value outside allowed range: ' + key)
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
    parser.add_argument('action', choices=('encode', 'set', 'reset', 'check'))
    parser.add_argument('path', type=Path)
    parser.add_argument('key', nargs='?')
    parser.add_argument('value', nargs='?')
    args = parser.parse_args()
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
