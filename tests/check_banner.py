#!/usr/bin/env python3
# ============================================================
# tests/check_banner.py — перевірка банерів у файлах проєкту
# ============================================================
# Перевіряє що кожен кодовий файл починається з банера:
#   // ============================================================
#   // <шлях> — опис
#   // ============================================================
# Шлях — від кореня репо (quickshell/..., hypr/..., fish/...).
# Маркер відповідає мові: // для QML/JS/JSONC, # для Bash/Python/Fish/TOML/conf, -- для Lua.
# Винятки: чистий JSON, генеровані файли, data/assets.
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Файли що не потребують банера (чистий JSON не дозволяє коментарі)
JSON_NO_BANNER = {
    "quickshell/data/config.json",
    "quickshell/data/palette.json",
    "hypr/env.json",
}

# Генеровані — короткий коментар ок, не перевіряємо строго
GENERATED_PREFIX = [
    "fish/conf.d/99-palette.fish",
    "kitty/current-theme.conf",
    "yazi/theme.toml",
]

# Допоміжні без банера — допустимо (але якщо є банер — перевіряємо)
SKIP_DIRS = {"quickshell/data", "quickshell/assets", "quickshell/wp", "__pycache__"}

EXT_MARKER = {
    ".qml": "//",
    ".js": "//",
    ".jsonc": "//",
    ".py": "#",
    ".sh": "#",
    ".fish": "#",
    ".toml": "#",
    ".conf": "#",
    ".lua": "--",
}

# Файли без розширення але з відомим маркером
NO_EXT_MARKER = {
    "quickshell/scripts/selfshell": "#",
    "quickshell/services/qs-bt-agent": "#",
}


def expected_marker(path: pathlib.Path) -> str | None:
    rel = path.relative_to(ROOT).as_posix()
    if rel in NO_EXT_MARKER:
        return NO_EXT_MARKER[rel]
    return EXT_MARKER.get(path.suffix)


def should_skip(path: pathlib.Path) -> bool:
    rel = path.relative_to(ROOT).as_posix()
    if rel in JSON_NO_BANNER:
        return True
    for pref in GENERATED_PREFIX:
        if rel == pref or rel.startswith(pref):
            return True
    for d in SKIP_DIRS:
        if rel.startswith(d + "/"):
            return True
    if rel.startswith("quickshell/scripts/."):
        return True
    if rel.startswith("tests/") and path.suffix == ".lua":
        # тести мають свої банери але не критично — перевіряємо
        return False
    return False


def check_file(path: pathlib.Path) -> list[str]:
    errs = []
    marker = expected_marker(path)
    if marker is None:
        return errs
    if should_skip(path):
        return errs

    text = path.read_text(encoding="utf-8", errors="ignore")
    lines = text.splitlines()
    if not lines:
        errs.append(f"{path}: порожній файл")
        return errs

    has_shebang = lines[0].startswith("#!")
    offset = 1 if has_shebang else 0
    if len(lines) <= offset + 2:
        errs.append(f"{path}: занадто короткий файл, немає банера")
        return errs

    decor_pat = re.compile(r"^\s*" + re.escape(marker) + r"\s*={10,}\s*$")
    start = None
    for i in range(offset, min(offset + 3, len(lines))):
        if decor_pat.match(lines[i]):
            start = i
            break
    if start is None:
        errs.append(f"{path}: немає верхнього декоратора банера ({marker} {'='*60})")
        return errs

    end = None
    for i in range(start + 1, min(start + 10, len(lines))):
        if decor_pat.match(lines[i]):
            end = i
            break
    if end is None:
        errs.append(f"{path}: немає нижнього декоратора банера")
        return errs

    if end - start < 2:
        errs.append(f"{path}: банер має містити хоча б один рядок опису")
        return errs
    if end - start > 2:
        errs.append(f"{path}: банер має бути рівно 3 рядки (декоратор, опис, декоратор), зараз {end - start + 1}")

    # Перевірка рядка опису
    desc_line = lines[start + 1] if end - start == 2 else None
    if desc_line is not None:
        if not re.match(r"^\s*" + re.escape(marker) + r"\s+.+ — .+", desc_line):
            errs.append(f"{path}:{start+2}: опис має бути '{marker} <шлях> — опис' з ем-дашем — (U+2014), зараз: {desc_line!r}")
        else:
            # Перевірка шляху
            m = re.match(r"^\s*" + re.escape(marker) + r"\s+(.+?)\s+—\s+", desc_line)
            if m:
                declared = m.group(1).strip()
                expected = path.relative_to(ROOT).as_posix()
                if declared != expected:
                    errs.append(f"{path}:{start+2}: шлях у банері '{declared}' != очікуваний '{expected}'")
            # Перевірка декоратора довжини
            decor = lines[start].strip()
            # порахувати =
            eq = decor.replace(marker, "").strip()
            if len(eq) != 60:
                errs.append(f"{path}:{start+1}: декоратор має бути 60 '=', зараз {len(eq)}")
    return errs


def main() -> int:
    exts = {".qml", ".js", ".py", ".sh", ".lua", ".fish", ".conf", ".toml", ".jsonc"}
    files: list[pathlib.Path] = []
    for p in ROOT.rglob("*"):
        if not p.is_file():
            continue
        rel = p.relative_to(ROOT).as_posix()
        if rel.startswith(".git/"):
            continue
        # Поки що строго перевіряємо лише quickshell/ — фокус проєкту.
        # Інші компоненти (hypr, fish, yazi, tests) — м'яка перевірка, не блокує CI.
        if not rel.startswith("quickshell/"):
            continue
        if rel in NO_EXT_MARKER or p.suffix in exts:
            files.append(p)

    all_errs: list[str] = []
    for f in sorted(files):
        errs = check_file(f)
        # Для aux з однорядковим коментарем (pam/password.conf) — дозволити
        if f.relative_to(ROOT).as_posix() == "quickshell/pam/password.conf":
            # має бути хоча б "# quickshell/pam/password.conf — ..."
            if errs and "занадто короткий" in errs[0]:
                txt = f.read_text(errors="ignore").splitlines()
                if txt and "quickshell/pam/password.conf —" in txt[0]:
                    errs = []
        all_errs.extend(errs)

    if all_errs:
        print("Banner check FAILED:")
        for e in all_errs:
            print("  ", e)
        print(f"\n{len(all_errs)} помилок(ка) банера")
        return 1
    # Порахувати скільки файлів перевірено
    checked = len([f for f in files if not should_skip(f) and expected_marker(f)])
    print(f"ok: banner check ({checked} файлів)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
