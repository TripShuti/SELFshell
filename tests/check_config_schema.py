# ============================================================
# tests/check_config_schema.py — валідація quickshell/data/config.json
# та hypr/env.json за схемою з docs/CONFIG_FORMAT.md, плюс синхрон
# binds.json-дій (BindsSection/binds.lua/доки) і visual.json-ключів
# (hyprDefaults/general.lua+rules.lua/доки): дефолти дубльовано вручну.
# Типі?поля відсутні — лише перевірка присутніх, бо всі поля опційні.
# ============================================================
import json
import os
import re
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
    "timerEnabled", "selftrackEnabled", "genshinEnabled", "keyboardEnabled", "audioEnabled",
    "controlEnabled", "clipboardEnabled", "btEnabled", "netEnabled", "trayEnabled",
    "batteryEnabled", "kcdEnabled", "kcdDndEnabled", "dndEnabled", "autoPowerSaver", "barAutoHide",
    "leftPillEnabled", "centerPillEnabled", "rightPillEnabled",
    "animationsEnabled",
]
NUM_FIELDS = {
    # 0 = never (рівень вимкнено, випадає з ordering-обмеження)
    "idleLockTimeout": (0, 86400), "idleDpmsTimeout": (0, 86400),
    "idleSuspendTimeout": (0, 86400),
    "audioStep": (0.0, 1.0), "brightnessStep": (0, 100),
    "barHeight": (1, 200), "barRadius": (0, 100),
    "edgeMargin": (0, 200), "pillPadding": (0, 100), "contentSpacing": (0, 100),
    "popupBgOpacity": (0.0, 1.0), "popupBgLighten": (1.0, 2.0),
    "popupRadius": (0, 24), "popupBorderWidth": (0, 4),
    "toastRadius": (0, 24), "toastLighten": (1.0, 2.0), "toastBgOpacity": (0.0, 1.0),
    "osdRadius": (0, 24), "osdLighten": (1.0, 2.0), "osdBgOpacity": (0.0, 1.0),
    "barLighten": (1.0, 2.0),
    "barBgOpacity": (0.0, 1.0), "barBorderWidth": (0, 4),
    "separatorOpacity": (0.0, 1.0), "separatorGlowOpacity": (0.0, 0.5),
    "uiScale": (0.8, 1.5),
    "animSpeed": (0.5, 2.0),
}
STR_FIELDS = ["barPos", "themeMode"]
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
    if "themeMode" in cfg:
        # white видалено повністю (без міграції): допустимі лише black/matugen
        check(cfg["themeMode"] in ("black", "matugen"),
              f"config themeMode: expected black/matugen, got {cfg['themeMode']!r}")
    for field in ORDER_FIELDS:
        if field in cfg:
            check(isinstance(cfg[field], list) and all(isinstance(x, str) for x in cfg[field]),
                  f"config {field}: expected string[]")
    if "preferredPlayer" in cfg:
        check(isinstance(cfg["preferredPlayer"], str) and cfg["preferredPlayer"] != "",
              f"config preferredPlayer: expected non-empty string, got {cfg['preferredPlayer']!r}")
    # Часові ліміти мають зростати: lock < dpms < suspend (0 = never, випадає з порівняння)
    keys = ["idleLockTimeout", "idleDpmsTimeout", "idleSuspendTimeout"]
    vals = [cfg[k] for k in keys if k in cfg]
    if len(vals) == 3:
        active = [v for v in vals if v != 0]
        check(active == sorted(active) and len(active) == len(set(active)),
              f"config: idle timeouts must ascend (0=never exempt), got {vals}")
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

def read_text(path):
    try:
        with open(path) as f:
            return f.read()
    except OSError as e:
        failures.append(f"{os.path.basename(path)}: cannot read ({e})")
        return None


# --- binds.json action ids: BindsSection vs binds.lua vs CONFIG_FORMAT.md ---
# Набір дій має збігатися в трьох місцях (дефолти живуть у Lua,
# UI їх дублює, доки документують)
_binds_qml = read_text(os.path.join(ROOT, "quickshell", "popups", "settings", "BindsSection.qml"))
_binds_lua = read_text(os.path.join(ROOT, "hypr", "modules", "binds.lua"))
_docs = read_text(os.path.join(ROOT, "docs", "CONFIG_FORMAT.md"))
if _binds_qml is not None and _binds_lua is not None and _docs is not None:
    qml_ids = set(re.findall(r'\{\s*id:\s*"([a-z]+)"', _binds_qml))
    lua_ids = set(re.findall(r'bindKey\("([a-z]+)"', _binds_lua))
    check(len(qml_ids) > 0 and len(lua_ids) > 0, "binds actions: empty extraction (regex drift?)")
    check(len(_docs.split("Action ids:")) == 2, "binds actions: 'Action ids:' paragraph not found in CONFIG_FORMAT.md")
    if len(_docs.split("Action ids:")) == 2:
        doc_ids = set(re.findall(r'`([a-z]+)`', _docs.split("Action ids:")[1].split(".")[0]))
        check(qml_ids == lua_ids,
              f"binds actions: BindsSection {sorted(qml_ids)} != binds.lua {sorted(lua_ids)}")
        check(qml_ids == doc_ids,
              f"binds actions: BindsSection {sorted(qml_ids)} != CONFIG_FORMAT.md {sorted(doc_ids)}")


# --- visual.json keys: hyprDefaults vs general.lua/rules.lua vs CONFIG_FORMAT.md ---
# Дефолти дубльовано вручну (general.lua так і каже: "мають збігатися"),
# тест ловить дрейф у будь-який бік
_hypr_qml = read_text(os.path.join(ROOT, "quickshell", "popups", "settings", "HyprlandSection.qml"))
_general = read_text(os.path.join(ROOT, "hypr", "modules", "general.lua"))
_rules = read_text(os.path.join(ROOT, "hypr", "modules", "rules.lua"))
if _hypr_qml is not None and _general is not None and _rules is not None and _docs is not None:
    m = re.search(r'hyprDefaults:\s*\(\{(.*?)\}\)', _hypr_qml, re.S)
    check(m is not None, "visual keys: hyprDefaults block not found in HyprlandSection.qml")
    check("## Hyprland: visual.json" in _docs, "visual keys: section not found in CONFIG_FORMAT.md")
    if m is not None and "## Hyprland: visual.json" in _docs:
        qml_keys = set(re.findall(r'([A-Za-z_]+)\s*:', m.group(1)))
        lua_keys = set(re.findall(r'V\.([A-Za-z_]+)', _general + _rules))
        doc_sec = _docs.split("## Hyprland: visual.json")[1].split("\n---")[0]
        doc_block = re.search(r'```json\n(\{.*?\n\})', doc_sec, re.S)
        check(doc_block is not None, "visual keys: example block not found in CONFIG_FORMAT.md")
        if doc_block is not None:
            doc_keys = set(re.findall(r'"([a-z_]+)"\s*:', doc_block.group(1)))
            check(len(qml_keys) > 0 and len(lua_keys) > 0 and len(doc_keys) > 0,
                  "visual keys: empty extraction (regex drift?)")
            check(qml_keys == lua_keys,
                  f"visual keys: HyprlandSection-only {sorted(qml_keys - lua_keys)}, lua-only {sorted(lua_keys - qml_keys)}")
            check(qml_keys == doc_keys,
                  f"visual keys: HyprlandSection-only {sorted(qml_keys - doc_keys)}, docs-only {sorted(doc_keys - qml_keys)}")


# --- AppConfig: adapter defaults vs defaultCfg (Reset повертає заводські) ---
# Обидва списки дублюються вручну — тест ловить дрейф у будь-який бік
_appcfg = read_text(os.path.join(ROOT, "quickshell", "core", "AppConfig.qml"))
if _appcfg is not None:
    m = re.search(r'adapter:\s*JsonAdapter\s*\{(.*?)\n    \}', _appcfg, re.S)
    check(m is not None, "appconfig: JsonAdapter block not found")
    m2 = re.search(r'readonly property var defaultCfg:\s*\(\{(.*?)\n  \}\)', _appcfg, re.S)
    check(m2 is not None, "appconfig: defaultCfg block not found")
    if m is not None and m2 is not None:
        adapter_defs = dict(re.findall(r'property\s+\S+\s+([A-Za-z]+)\s*:\s*(.+)', m.group(1)))
        cfg_defs = dict(re.findall(r'([A-Za-z]+)\s*:\s*(\[[^\]]*\]|"[^"]*"|[^,\]]+)', m2.group(1)))
        check(len(adapter_defs) > 0 and len(cfg_defs) > 0, "appconfig: empty extraction (regex drift?)")
        normval = lambda s: re.sub(r'\s+', '', s).rstrip(',')
        check(set(adapter_defs) == set(cfg_defs),
              f"appconfig: adapter-only {sorted(set(adapter_defs) - set(cfg_defs))}, "
              f"defaultCfg-only {sorted(set(cfg_defs) - set(adapter_defs))}")
        drifts = sorted(k for k in adapter_defs
                       if k in cfg_defs and normval(adapter_defs[k]) != normval(cfg_defs[k]))
        check(not drifts, f"appconfig: default drift: {drifts}")


if failures:
    print("\n".join("SCHEMA: " + f for f in failures))
    sys.exit(1)
print("ok: config schema (data/config.json + hypr/env.json + binds/visual/appconfig sync)")