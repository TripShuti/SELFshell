# ============================================================
# tests/check_config_schema.py — валідація quickshell/data/config.json
# та hypr/env.json за схемою з docs/CONFIG_FORMAT.md.
# Типі?поля відсутні — лише перевірка присутніх, бо всі поля опційні.
# ============================================================
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CONFIG_PATH = os.path.join(ROOT, "quickshell", "data", "config.json")
ENV_PATH = os.path.join(ROOT, "hypr", "env.json")

failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        failures.append(f"{os.path.basename(path)}: broken JSON ({e})")
        return None


# --- config.json ---
BOOL_FIELDS = [
    "launcherEnabled", "workspacesEnabled", "mprisEnabled", "clockEnabled",
    "timerEnabled", "genshinEnabled", "keyboardEnabled", "audioEnabled",
    "controlEnabled", "clipboardEnabled", "btEnabled", "netEnabled", "trayEnabled",
    "batteryEnabled", "kcdEnabled", "dndEnabled", "barAutoHide",
    "leftPillEnabled", "centerPillEnabled", "rightPillEnabled",
]
NUM_FIELDS = {
    "idleLockTimeout": (1, 86400), "idleDpmsTimeout": (1, 86400),
    "idleSuspendTimeout": (1, 86400),
    "audioStep": (0.0, 1.0), "brightnessStep": (0, 100),
    "barHeight": (1, 200), "barRadius": (0, 100),
    "edgeMargin": (0, 200), "pillPadding": (0, 100), "contentSpacing": (0, 100),
    "popupBgOpacity": (0.0, 1.0), "popupBgLighten": (1.0, 2.0),
    "popupRadius": (0, 24), "popupBorderWidth": (0, 4),
    "toastRadius": (0, 24), "toastLighten": (1.0, 2.0), "toastBgOpacity": (0.0, 1.0),
    "osdRadius": (0, 24), "osdLighten": (1.0, 2.0), "osdBgOpacity": (0.0, 1.0),
    "barLighten": (1.0, 2.0),
    "barBgOpacity": (0.0, 1.0), "barBorderWidth": (0, 4),
    "separatorOpacity": (0.0, 1.0), "separatorGlowOpacity": (0.0, 1.0),
    "uiScale": (0.5, 2.0),
}
STR_FIELDS = ["barPos"]
ORDER_FIELDS = ["leftOrder", "centerOrder", "rightOrder"]

cfg = load(CONFIG_PATH)
if cfg is not None:
    for field in BOOL_FIELDS:
        if field in cfg:
            check(isinstance(cfg[field], bool), f"config {field}: expected boolean")
    for field, (lo, hi) in NUM_FIELDS.items():
        if field in cfg:
            v = cfg[field]
            ok = isinstance(v, (int, float)) and not isinstance(v, bool) and lo <= v <= hi
            check(ok, f"config {field}: expected number in [{lo},{hi}], got {v!r}")
    if "timerSoundPath" in cfg:
        check(isinstance(cfg["timerSoundPath"], str), "config timerSoundPath: expected string")
    for field in STR_FIELDS:
        if field in cfg:
            check(isinstance(cfg[field], str), f"config {field}: expected string")
    if "barPos" in cfg:
        check(cfg["barPos"] in ("top", "bottom"),
              f"config barPos: expected top/bottom, got {cfg['barPos']!r}")
    for field in ORDER_FIELDS:
        if field in cfg:
            check(isinstance(cfg[field], list) and all(isinstance(x, str) for x in cfg[field]),
                  f"config {field}: expected string[]")
    # Часові ліміти мають зростати: lock < dpms < suspend
    keys = ["idleLockTimeout", "idleDpmsTimeout", "idleSuspendTimeout"]
    vals = [cfg[k] for k in keys if k in cfg]
    if len(vals) == 3:
        check(vals[0] < vals[1] < vals[2],
              f"config: idle timeouts must ascend, got {vals}")
    # sep-N суф інкатор для порядків — унікальні в межах кожного списку
    for field in ORDER_FIELDS:
        if field in cfg:
            seps = [s for s in cfg[field] if s.startswith("sep-")]
            check(len(seps) == len(set(seps)),
                  f"config {field}: duplicate separator IDs")
            for s in seps:
                check(s[4:].isdigit(), f"config {field}: separator {s!r} must be sep-<number>")


# --- env.json ---
env = load(ENV_PATH)
if env is not None:
    STR_FIELDS = ["mod", "terminal", "fileManager", "browser", "cursorTheme",
                  "kbLayout", "kbOptions", "suspendKey"]
    for field in STR_FIELDS:
        if field in env:
            check(isinstance(env[field], str), f"env {field}: expected string")
    if "cursorSize" in env:
        check(isinstance(env["cursorSize"], int) and not isinstance(env["cursorSize"], bool)
              and 1 <= env["cursorSize"] <= 100, f"env cursorSize: expected int 1..100")
    if "autostart" in env:
        check(isinstance(env["autostart"], list), "env autostart: expected array")
        for i, item in enumerate(env["autostart"]):
            check(isinstance(item, dict) and isinstance(item.get("command"), str),
                  f"env autostart[{i}]: expected {{command: string}}")
            if "workspace" in item:
                check(isinstance(item["workspace"], int) and not isinstance(item["workspace"], bool),
                      f"env autostart[{i}].workspace: expected number")
    if "devices" in env:
        check(isinstance(env["devices"], list), "env devices: expected array")
        for i, item in enumerate(env["devices"]):
            check(isinstance(item, dict) and isinstance(item.get("name"), str),
                  f"env devices[{i}]: expected {{name: string}}")
            for k in ("sensitivity", "scroll_factor"):
                if k in item:
                    check(isinstance(item[k], (int, float)) and not isinstance(item[k], bool),
                          f"env devices[{i}].{k}: expected number")
            if "accel_profile" in item:
                check(item["accel_profile"] in ("flat", "adaptive"),
                      f"env devices[{i}].accel_profile: expected flat/adaptive")
    if "windowRules" in env:
        check(isinstance(env["windowRules"], list), "env windowRules: expected array")
        for i, item in enumerate(env["windowRules"]):
            check(isinstance(item, dict) and isinstance(item.get("name"), str)
                  and isinstance(item.get("match"), dict),
                  f"env windowRules[{i}]: expected {{name: string, match: object}}")

if failures:
    print("\n".join("SCHEMA: " + f for f in failures))
    sys.exit(1)
print("ok: config schema (data/config.json + hypr/env.json)")