#!/usr/bin/env python3
# ============================================================
# quickshell/scripts/pacman_updates.py — список оновлень pacman + AUR одним JSON для секції System
# ============================================================
"""Без root і TTY збирає все, що можна знати про доступні оновлення:
офіційні репозиторії через `checkupdates` (він сам синхронізує тимчасову
базу, системну не чіпає), AUR через `yay -Qua` / `paru -Qua` (перший
знайдений хелпер). Деталі (репозиторій, опис, розмір) добирає з тимчасової
бази checkupdates. Друкує один JSON і завжди виходить з кодом 0, якщо сам
скрипт відпрацював (навіть коли оновлень нема або мережа недоступна) —
QML розрізняє стани за полями ok/error."""

import json
import os
import re
import shutil
import subprocess
import sys

ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")
# необов'язковий префікс `repo/` (yay/paru іноді його додають), далі
# `ім'я стара -> нова` — формат `pacman -Qu` / `yay -Qua`
LINE_RE = re.compile(
    r"^(?:([A-Za-z0-9._+-]+)/)?([A-Za-z0-9@._+-]+)\s+(\S+)\s+->\s+(\S+)\s*$")
SIZE_RE = re.compile(r"^\s*([\d.]+)\s*([KMGT]?I?B)\s*$", re.IGNORECASE)

UNIT_MULT = {"B": 1, "KB": 1000, "MB": 1000 ** 2, "GB": 1000 ** 3,
             "KIB": 1024, "MIB": 1024 ** 2, "GIB": 1024 ** 3,
             "TIB": 1024 ** 4}


def strip_ansi(text):
    """Зносить кольорові коди — пайп не TTY, але страхуємось."""
    return ANSI_RE.sub("", text or "")


def parse_update_line(line):
    """(name, old, new, repo|None) з рядка `pkg old -> new`, None — сміття."""
    m = LINE_RE.match(strip_ansi(line).strip())
    if not m:
        return None
    return (m.group(2), m.group(3), m.group(4), m.group(1))


def parse_si_block(block):
    """(name, {repo, desc, download}) з одного блока `pacman -Si`."""
    fields = {}
    for line in block.splitlines():
        if ":" not in line or line[0] in (" ", "\t"):
            continue
        key, _, val = line.partition(":")
        fields[key.strip()] = val.strip()
    if "Name" not in fields:
        return None
    return (fields["Name"], {
        "repo": fields.get("Repository", ""),
        "desc": fields.get("Description", ""),
        "download": fields.get("Download Size", ""),
    })


def size_to_bytes(text):
    """`3.60 MiB` -> байти, None — нерозпізнаний формат."""
    m = SIZE_RE.match((text or "").strip().upper())
    if not m:
        return None
    mult = UNIT_MULT.get(m.group(2))
    if mult is None:
        return None
    try:
        return int(float(m.group(1)) * mult)
    except ValueError:
        return None


def human_bytes(num):
    """Байти -> короткий рядок для статус-рядка."""
    for unit in ("B", "KiB", "MiB", "GiB"):
        if num < 1024 or unit == "GiB":
            return ("%d %s" % (num, unit)) if unit == "B" \
                else ("%.1f %s" % (num, unit))
        num /= 1024.0
    return "%d B" % num


def run(cmd, timeout):
    """(rc, stdout) — відсутній бінарник дає rc 127, а не виняток."""
    if shutil.which(cmd[0]) is None:
        return (127, "")
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True,
                              timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return (1, "")
    return (proc.returncode, proc.stdout or "")


def default_dbpath():
    """Тимчасова база checkupdates (та сама, куди він синхронізував)."""
    if os.environ.get("CHECKUPDATES_DB"):
        return os.environ["CHECKUPDATES_DB"]
    tmp = os.environ.get("TMPDIR", "/tmp")
    return os.path.join(tmp, "checkup-db-%d" % os.getuid())


def collect_official():
    """(packages, error) — список кортежів (name, old, new) з репозиторіїв."""
    rc, out = run(["checkupdates", "--nocolor"], timeout=180)
    if rc == 127:
        return (None, "missing")
    if rc == 2:
        return ([], "")  # exit 2 за codом checkupdates = оновлень нема
    if rc != 0:
        return (None, "Check failed (offline or sync error)")
    pkgs = []
    for line in out.splitlines():
        parsed = parse_update_line(line)
        if parsed is not None:
            name, old, new, _repo = parsed
            pkgs.append((name, old, new))
    return (pkgs, "")


def find_helper():
    """yay має пріоритет (його ставить install.sh), далі paru."""
    for helper in ("yay", "paru"):
        if shutil.which(helper) is not None:
            return helper
    return ""


def collect_aur(helper):
    """(packages, error) — список (name, old, new) з AUR, [] без хелпера."""
    if not helper:
        return ([], "")
    rc, out = run([helper, "-Qua"], timeout=180)
    if rc != 0:
        return ([], "")  # AUR-недоступність не валить весь чек
    pkgs = []
    for line in out.splitlines():
        parsed = parse_update_line(line)
        if parsed is not None:
            name, old, new, _repo = parsed
            pkgs.append((name, old, new))
    return (pkgs, "")


def enrich_official(names):
    """{name: {repo, desc, download}} одним викликом `pacman -Si`."""
    if not names:
        return {}
    dbpath = default_dbpath()
    if not os.path.isdir(os.path.join(dbpath, "sync")):
        return {}
    rc, out = run(["pacman", "--dbpath", dbpath, "-Si", "--"] + names,
                  timeout=60)
    if rc != 0:
        return {}
    info = {}
    for block in out.split("\n\n"):
        parsed = parse_si_block(block)
        if parsed is not None:
            info[parsed[0]] = parsed[1]
    return info


def collect():
    """Головна збірка — словник під JSON.parse в QML."""
    official, err = collect_official()
    if official is None:
        if err == "missing":
            return {"ok": False, "missing_checkupdates": True,
                    "error": "checkupdates not found",
                    "packages": [], "repo_count": 0, "aur_count": 0,
                    "helper": "", "total_download": ""}
        return {"ok": False, "missing_checkupdates": False, "error": err,
                "packages": [], "repo_count": 0, "aur_count": 0,
                "helper": "", "total_download": ""}
    helper = find_helper()
    aur, _aur_err = collect_aur(helper)
    details = enrich_official([n for n, _o, _w in official])
    packages = []
    total = 0
    for name, old, new in official:
        det = details.get(name, {})
        dl = det.get("download", "")
        size = size_to_bytes(dl)
        if size is not None:
            total += size
        packages.append({"name": name, "old": old, "new": new,
                         "repo": det.get("repo", ""),
                         "desc": det.get("desc", ""), "download": dl})
    for name, old, new in aur:
        packages.append({"name": name, "old": old, "new": new,
                         "repo": "aur", "desc": "", "download": ""})
    return {"ok": True, "missing_checkupdates": False, "error": "",
            "packages": packages, "repo_count": len(official),
            "aur_count": len(aur), "helper": helper,
            "total_download": human_bytes(total) if total else ""}


def main():
    print(json.dumps(collect()))


if __name__ == "__main__":
    main()
