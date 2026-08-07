#!/usr/bin/env python3
# ============================================================
# update-palette.py — генерація палітри та тем зі шпалер
# ============================================================
# Генерує data/palette.json, kitty тему, fish кольори, starship, yazi, foot
# та qt6ct color scheme на основі поточних шпалер через matugen

import sys, json, subprocess, re, os, tempfile

QS_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WP_DIR = os.path.expanduser("~/.config/quickshell/wp")


# Список шпалер з директорії wp/ (найновіші першими), без current.jpg
def list_wallpapers():
    if not os.path.isdir(WP_DIR):
        return
    exts = (".jpg", ".jpeg", ".png")
    files = [
        os.path.join(WP_DIR, f) for f in os.listdir(WP_DIR)
        if f.lower().endswith(exts) and f != "current.jpg"
    ]
    files.sort(key=lambda p: os.path.getmtime(p), reverse=True)
    sys.stdout.write("\n".join(files))


# Атомарний запис: пише у tmp у тій самій директорії, потім os.replace —
# якщо скрипт перерветься на півшляху, файл лишається цілим
def atomic_write(path, content):
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(content)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


if len(sys.argv) >= 2 and sys.argv[1] == "list":
    list_wallpapers()
    sys.exit(0)

if len(sys.argv) < 2:
    print(f"usage: {os.path.basename(sys.argv[0])} <wallpaper> | list", file=sys.stderr)
    sys.exit(1)

wallpaper = sys.argv[1]

result = subprocess.run(
    ["matugen", "image", wallpaper, "--source-color-index", "0", "--mode", "dark", "-j", "hex"],
    capture_output=True, text=True, check=True
)

data = json.loads(result.stdout)
raw = data["colors"]
palettes = data["palettes"]

# Отримує колір з raw
def col(name):
    return raw[name]["dark"]["color"]

# Отримує тон з палітри (neutral, primary, secondary, tertiary)
def tone(palette_name, level):
    return palettes[palette_name][str(level)]["color"]

def parse_hex(h):
    h = h.lstrip("#")
    if len(h) == 8: h = h[2:]
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)

def to_hex(r, g, b):
    return f"#{r:02x}{g:02x}{b:02x}"

# Змішує два кольори з коефіцієнтом t (0-1)
def blend(a, b, t):
    ra, ga, ba = parse_hex(a)
    rb, gb, bb = parse_hex(b)
    r = round(ra + (rb - ra) * t)
    g = round(ga + (gb - ga) * t)
    b = round(ba + (bb - ba) * t)
    return to_hex(r, g, b)

# Додає альфа-канал до кольору
def alpha(h, a):
    r, g, b = parse_hex(h)
    aa = round(max(0, min(1, a)) * 255)
    return f"#{aa:02x}{r:02x}{g:02x}{b:02x}"

# Колір у форматі qt6ct: #AARRGGBB (альфа повністю непрозора)
def qt_argb(h):
    r, g, b = parse_hex(h)
    return f"#ff{r:02x}{g:02x}{b:02x}"

# Гарантує, що qt6ct.conf посилається на нашу color scheme, зберігаючи решту ключів
def ensure_qt6ct_palette(scheme_path):
    conf_path = os.path.expanduser("~/.config/qt6ct/qt6ct.conf")
    os.makedirs(os.path.dirname(conf_path), exist_ok=True)
    lines = open(conf_path).read().splitlines() if os.path.isfile(conf_path) else []
    if not any(l.strip() == "[Appearance]" for l in lines):
        if lines and lines[-1].strip() != "":
            lines.append("")
        lines.append("[Appearance]")

    out = []
    in_appearance = False
    wrote_palette = wrote_custom = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            in_appearance = stripped == "[Appearance]"
        elif in_appearance and "=" in line:
            key = stripped.split("=", 1)[0].strip()
            if key == "color_scheme_path":
                line = f"color_scheme_path={scheme_path}"
                wrote_palette = True
            elif key == "custom_palette":
                line = "custom_palette=true"
                wrote_custom = True
        out.append(line)

    # Додаємо відсутні ключі одразу після [Appearance]
    idx = next((i for i, l in enumerate(out) if l.strip() == "[Appearance]"), -1)
    missing = []
    if not wrote_palette:
        missing.append(f"color_scheme_path={scheme_path}")
    if not wrote_custom:
        missing.append("custom_palette=true")
    if missing:
        out = out[:idx + 1] + missing + out[idx + 1:]

    atomic_write(conf_path, "\n".join(out) + "\n")

fg        = col("on_background")
gray      = col("outline")
green     = tone("primary", 70)
red       = tone("error", 80)
bg0H      = tone("neutral", 20)
bg1       = tone("neutral", 25)
bg2       = tone("neutral", 35)
muted     = col("on_surface_variant")
light     = tone("neutral", 90)
bright    = tone("neutral", 95)
yellow    = col("tertiary")
blue      = col("secondary")
purple    = tone("secondary", 70)
# orange з третинної палітри: раніше був тотожній green (primary 70) —
# копіпаста, через що UI-елементи з orange виглядали зеленими
orange    = tone("tertiary", 70)
aqua      = tone("tertiary", 70)

widgetFg   = blend(col("primary"), col("on_background"), 0.6)
audioVolume = tone("tertiary", 80)
accent     = col("primary")
textLight  = tone("neutral", 95)
mutedAlt   = blend(col("outline"), col("on_background"), 0.3)
danger     = col("error")
bgLayer    = alpha(blend(col("background"), col("on_surface"), 0.15), 0.6)
sepBg      = alpha(col("primary"), 0.6)
outlineVariant = alpha(bg2, 0.4)

# --- Генерація data/palette.json (для PaletteService) ---

palette_values = {
    "font": "JetBrainsMonoNL Nerd Font",
    "fg": fg, "gray": gray, "green": green, "red": red,
    "bg0H": bg0H, "bg1": bg1, "bg2": bg2,
    "muted": muted, "light": light, "bright": bright,
    "yellow": yellow, "blue": blue, "purple": purple, "orange": orange, "aqua": aqua,
    "widgetFg": widgetFg, "audioVolume": audioVolume,
    "hoverOverlay": alpha('#ffffff', 0.08), "pressOverlay": alpha('#ffffff', 0.12),
    "bgAlpha": alpha(bg0H, 0.6),
    "hoverBg": alpha(blend(bg0H, gray, 0.15), 0.6),
    "baseOverlay": alpha(bg0H, 0.6), "softOverlay": alpha(bg0H, 0.65),
    "accent": accent, "textLight": textLight, "mutedAlt": mutedAlt,
    "danger": danger, "bgLayer": bgLayer, "sepBg": sepBg, "outlineVariant": outlineVariant,
}

palette_json = json.dumps(palette_values, indent=2)

qs_dir = QS_DIR

palette_json_path = os.path.join(qs_dir, "data", "palette.json")
os.makedirs(os.path.dirname(palette_json_path), exist_ok=True)
atomic_write(palette_json_path, palette_json)

# --- Генерація colors.js для теми SDDM (екран входу) ---
# Тема живе у ~/.local/share/sddm/themes/selfshell; якщо папки немає —
# SDDM/тема не встановлені, крок пропускається
sddm_colors_path = os.path.join(
    os.path.expanduser("~/.local/share/sddm/themes/selfshell"), "colors.js")
if os.path.isdir(os.path.dirname(sddm_colors_path)):
    sddm_js = "// Generated by update-palette.py — do not edit\n"
    sddm_js += "var Colors = {\n"
    for k, v in palette_values.items():
        sddm_js += f'  "{k}": "{v}",\n'
    sddm_js += "};\n"
    atomic_write(sddm_colors_path, sddm_js)

# --- Генерація kitty current-theme.conf ---

kitty_bg = tone("neutral", 20)

kitty = f"""## Згенеровано update-palette.py

selection_foreground    {fg}
selection_background    {blend(bg0H, accent, 0.35)}

background              {kitty_bg}
foreground              {fg}

color0                  {bg1}
color1                  {red}
color2                  {green}
color3                  {yellow}
color4                  {blue}
color5                  {purple}
color6                  {aqua}
color7                  {light}
color8                  {muted}
color9                  {blend(red, bright, 0.5)}
color10                 {blend(green, bright, 0.5)}
color11                 {orange}
color12                 {blend(blue, bright, 0.5)}
color13                 {blend(purple, bright, 0.5)}
color14                 {blend(aqua, bright, 0.5)}
color15                 {bright}

cursor                  {fg}
cursor_text_color       {bg0H}

url_color               {blue}

active_tab_foreground   {fg}
active_tab_background   {blend(bg0H, accent, 0.5)}
inactive_tab_foreground {muted}
inactive_tab_background {bg0H}
"""

kitty_path = os.path.expanduser("~/.config/kitty/current-theme.conf")
os.makedirs(os.path.dirname(kitty_path), exist_ok=True)
atomic_write(kitty_path, kitty)

# --- Генерація fish conf.d/99-palette.fish ---

fish = f"""# Згенеровано update-palette.py
set -g fish_color_normal "{fg}"
set -g fish_color_command "{green}"
set -g fish_color_quote "{yellow}"
set -g fish_color_redirection "{purple}"
set -g fish_color_end "{purple}"
set -g fish_color_error "{red}"
set -g fish_color_param "{fg}"
set -g fish_color_comment "{muted}"
set -g fish_color_match --background={bg2.strip("#")}
set -g fish_color_selection --background={bg2.strip("#")}
set -g fish_color_search_match --background={bg2.strip("#")}
set -g fish_color_operator "{purple}"
set -g fish_color_escape "{aqua}"
set -g fish_color_autosuggestion "{muted}"
set -g fish_color_cwd "{blue}"
set -g fish_color_user "{green}"
set -g fish_color_host "{gray}"
set -g fish_color_status "{red}"
set -g fish_color_valid_path --underline
"""

fish_dir = os.path.expanduser("~/.config/fish/conf.d")
os.makedirs(fish_dir, exist_ok=True)
atomic_write(os.path.join(fish_dir, "99-palette.fish"), fish)

# --- Оновлення starship config.toml палітри ---

starship_path = os.path.expanduser("~/.config/starship/config.toml")
if os.path.isfile(starship_path):
    with open(starship_path, "r") as f:
        content = f.read()

    palette_map = {
        "background":     bg0H,
        "current_line":   bg2,
        "foreground":     fg,
        "comment":        muted,
        "cyan":           aqua,
        "green":          green,
        "orange":         orange,
        "pink":           blend(red, bright, 0.6),
        "purple":         purple,
        "red":            red,
        "yellow":         yellow,
        "white":          bright,
    }

    lines = content.split("\n")
    in_palette = False
    new_lines = []
    for line in lines:
        stripped = line.strip()
        if stripped == "[palettes.tokyonight]":
            in_palette = True
            new_lines.append(line)
        elif in_palette and stripped.startswith("["):
            in_palette = False
            new_lines.append(line)
        elif in_palette:
            match = re.match(r'^(\s*)(\w+)\s*=\s*"(#[^"]*)"', line)
            if match:
                indent = match.group(1)
                key = match.group(2)
                if key in palette_map:
                    new_lines.append(f'{indent}{key} = "{palette_map[key]}"')
                else:
                    new_lines.append(line)
            else:
                new_lines.append(line)
        else:
            new_lines.append(line)

    atomic_write(starship_path, "\n".join(new_lines))

# --- Генерація foot theme ---

FOOT_DIR = os.path.expanduser("~/.config/foot")

# foot приймає RRGGBB без # та альфа-каналу
def foot_hex(h):
    r, g, b = parse_hex(h)
    return to_hex(r, g, b).strip("#")

# foot 1.27: секція [colors-dark] — дефолтна тема; live-перефарбування
# через SIGUSR1 (pkill -USR1 foot), без рестарту терміналів.
# Формат тільки key=value — foot не приймає роздільник пробілами.
foot = f"""# Згенеровано update-palette.py

[colors-dark]
foreground={foot_hex(fg)}
background={foot_hex(bg0H)}
selection-foreground={foot_hex(fg)}
selection-background={foot_hex(blend(bg0H, accent, 0.35))}

regular0={foot_hex(bg1)}
regular1={foot_hex(red)}
regular2={foot_hex(green)}
regular3={foot_hex(yellow)}
regular4={foot_hex(blue)}
regular5={foot_hex(purple)}
regular6={foot_hex(aqua)}
regular7={foot_hex(light)}

bright0={foot_hex(muted)}
bright1={foot_hex(blend(red, bright, 0.5))}
bright2={foot_hex(blend(green, bright, 0.5))}
bright3={foot_hex(orange)}
bright4={foot_hex(blend(blue, bright, 0.5))}
bright5={foot_hex(blend(purple, bright, 0.5))}
bright6={foot_hex(blend(aqua, bright, 0.5))}
bright7={foot_hex(bright)}

cursor={foot_hex(fg)} {foot_hex(bg0H)}
urls={foot_hex(blue)}
"""

os.makedirs(FOOT_DIR, exist_ok=True)
atomic_write(os.path.join(FOOT_DIR, "colors.ini"), foot)

# foot.ini: створюємо з include, якщо немає; наявні налаштування не чіпаємо
foot_ini_path = os.path.join(FOOT_DIR, "foot.ini")
include_line = "include=~/.config/foot/colors.ini"
if os.path.isfile(foot_ini_path):
    with open(foot_ini_path, "r") as f:
        foot_ini = f.read()
    if "colors.ini" not in foot_ini:
        with open(foot_ini_path, "a") as f:
            f.write(f"\n{include_line}\n")
else:
    atomic_write(foot_ini_path, f"# Згенеровано update-palette.py\n{include_line}\n")

# --- Генерація yazi flavor ---

yazi_flavor_dir = os.path.expanduser("~/.config/yazi/flavors/palette.yazi")
os.makedirs(yazi_flavor_dir, exist_ok=True)

yazi_flavor = f"""# Згенеровано update-palette.py

[mgr]
cwd = {{ fg = "{green}" }}

find_keyword  = {{ fg = "{yellow}", bold = true, italic = true, underline = true }}
find_position = {{ fg = "{purple}", bg = "reset", bold = true, italic = true }}

marker_copied   = {{ fg = "{green}", bg = "{green}" }}
marker_cut      = {{ fg = "{red}", bg = "{red}" }}
marker_marked   = {{ fg = "{green}", bg = "{green}" }}
marker_selected = {{ fg = "{yellow}", bg = "{yellow}" }}

count_copied   = {{ fg = "{bg0H}", bg = "{green}" }}
count_cut      = {{ fg = "{bg0H}", bg = "{red}" }}
count_selected = {{ fg = "{bg0H}", bg = "{yellow}" }}

border_symbol = "│"
border_style  = {{ fg = "{bg2}" }}

[tabs]
active   = {{ fg = "{bg0H}", bg = "{green}", bold = true }}
inactive = {{ fg = "{green}", bg = "{bg1}" }}

[mode]
normal_main = {{ fg = "{bg1}", bg = "{green}", bold = true }}
normal_alt  = {{ fg = "{green}", bg = "{bg2}", bold = true }}

select_main = {{ fg = "{bg1}", bg = "{red}", bold = true }}
select_alt  = {{ fg = "{green}", bg = "{bg2}", bold = true }}

unset_main = {{ fg = "{bg1}", bg = "{green}", bold = true }}
unset_alt  = {{ fg = "{green}", bg = "{bg2}", bold = true }}

[status]
perm_sep   = {{ fg = "{bg0H}" }}
perm_type  = {{ fg = "{green}" }}
perm_read  = {{ fg = "{yellow}" }}
perm_write = {{ fg = "{red}" }}
perm_exec  = {{ fg = "{green}" }}

progress_label  = {{ bold = true }}
progress_normal = {{ fg = "{green}", bg = "{bg0H}" }}
progress_error  = {{ fg = "{red}", bg = "{bg0H}" }}

[pick]
border   = {{ fg = "{green}" }}
active   = {{ fg = "{purple}", bold = true }}
inactive = {{}}

[input]
border   = {{ fg = "{green}" }}
title    = {{}}
value    = {{}}
selected = {{ reversed = true }}

[cmp]
border   = {{ fg = "{green}" }}

[tasks]
border  = {{ fg = "{green}" }}
title   = {{}}
hovered = {{ fg = "{purple}", underline = true }}

[which]
mask            = {{ bg = "{bg0H}" }}
cand            = {{ fg = "{green}" }}
rest            = {{ fg = "{bg0H}" }}
desc            = {{ fg = "{purple}" }}
separator       = "  "
separator_style = {{ fg = "{bg0H}" }}

[help]
on      = {{ fg = "{green}" }}
run     = {{ fg = "{purple}" }}
hovered = {{ reversed = true, bold = true }}
footer  = {{ fg = "{bg0H}", bg = "{light}" }}

[spot]
border   = {{ fg = "{green}" }}
title    = {{ fg = "{green}" }}
tbl_col  = {{ fg = "{green}" }}
tbl_cell = {{ fg = "{yellow}", reversed = true }}

[notify]
title_info  = {{ fg = "{green}" }}
title_warn  = {{ fg = "{yellow}" }}
title_error = {{ fg = "{red}" }}

[filetype]
rules = [
\t{{ mime = "image/*", fg = "{purple}" }},
\t{{ mime = "{{audio,video}}/*", fg = "{purple}" }},
\t{{ mime = "application/{{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}}", fg = "{yellow}" }},
\t{{ mime = "application/{{pdf,doc,rtf}}", fg = "{blue}" }},
\t{{ mime = "vfs/{{absent,stale}}", fg = "{muted}" }},
\t{{ url = "*", fg = "{green}" }},
\t{{ url = "*/", fg = "{green}" }},
]
"""

atomic_write(os.path.join(yazi_flavor_dir, "flavor.toml"), yazi_flavor)

# --- Генерація yazi theme.toml ---

yazi_theme = f"""# Згенеровано update-palette.py

[flavor]
dark = "palette"

[icon]
prepend_dirs = [
    {{ name = "Desktop",   text = "󰟀", fg = "{purple}" }},
    {{ name = "Documents", text = "󰈙", fg = "{green}" }},
    {{ name = "Downloads", text = "󰇚", fg = "{yellow}" }},
    {{ name = "Music",     text = "󰎆", fg = "{purple}" }},
    {{ name = "Pictures",  text = "󰉏", fg = "{blue}" }},
    {{ name = "Videos",    text = "󰕧", fg = "{orange}" }},
    {{ name = "Public",    text = "󰷌", fg = "{green}" }},
    {{ name = "Templates", text = "󰈔", fg = "{gray}" }},
]

prepend_conds = [
    {{ if = "dir", text = "󰉋", fg = "{green}" }},
]
"""

yazi_theme_path = os.path.expanduser("~/.config/yazi/theme.toml")
atomic_write(yazi_theme_path, yazi_theme)

# --- Генерація qt6ct color scheme (Qt акцент) ---
# Qt-додатки (Telegram) читають акцент з QPalette::Highlight.
# Формат — власний формат qt6ct: [ColorScheme] зі списками #AARRGGBB у порядку
# ролей QPalette (Qt 6.11): індекс 12 = Highlight (акцент), 13 = HighlightedText
# (on_primary), 21 = Accent. Три списки (active/inactive/disabled) — тотожні,
# qt6ct латентно кладе їх у відповідні ColorGroup.
qt_roles = [
    fg,        # 0  WindowText
    bg2,       # 1  Button
    bg2,       # 2  Light
    bg2,       # 3  Midlight
    bg0H,      # 4  Dark
    bg1,       # 5  Mid
    fg,        # 6  Text
    bright,    # 7  BrightText
    fg,        # 8  ButtonText
    bg1,       # 9  Base
    bg0H,      # 10 Window
    bg0H,      # 11 Shadow
    accent,    # 12 Highlight
    col("on_primary"),  # 13 HighlightedText
    blue,      # 14 Link
    purple,    # 15 LinkVisited
    bg0H,      # 16 AlternateBase
    bg0H,      # 17 NoRole
    bg2,       # 18 ToolTipBase
    fg,        # 19 ToolTipText
    muted,     # 20 PlaceholderText
    accent,    # 21 Accent
]

qt_roles_str = ", ".join(qt_argb(c) for c in qt_roles)
qt_scheme = f"""[ColorScheme]
active_colors={qt_roles_str}
inactive_colors={qt_roles_str}
disabled_colors={qt_roles_str}
"""

qt_scheme_path = os.path.expanduser("~/.config/qt6ct/colors/Quickshell.conf")
os.makedirs(os.path.dirname(qt_scheme_path), exist_ok=True)
atomic_write(qt_scheme_path, qt_scheme)
ensure_qt6ct_palette(qt_scheme_path)
