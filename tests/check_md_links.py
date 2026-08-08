# ============================================================
# tests/check_md_links.py — перевірка відносних посилань в усіх
# .md-файлах репо. HTTP(S)/mailto/tel та якорі (#...) пропускаються.
# Запуск: python3 tests/check_md_links.py
# ============================================================
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LINK_RE = re.compile(r"\]\(([^)]+)\)")
SKIP_PREFIXES = ("http://", "https://", "mailto:", "tel:", "#", "{{", "<")


def md_files(root):
    for dirname, _subdirs, files in os.walk(root):
        if ".git" in dirname:
            continue
        for name in files:
            if name.endswith(".md"):
                yield os.path.join(dirname, name)


failures = []
for path in sorted(md_files(ROOT)):
    with open(path, encoding="utf-8") as f:
        content = f.read()
    base = os.path.dirname(path)
    for m in LINK_RE.finditer(content):
        target = m.group(1).strip()
        if not target or target.startswith(SKIP_PREFIXES):
            continue
        clean = target.split("#", 1)[0].split("?", 1)[0]
        if not clean:
            continue
        resolved = os.path.normpath(os.path.join(base, clean))
        if not os.path.exists(resolved):
            failures.append(f"{os.path.relpath(path, ROOT)}: broken link -> {target}")

if failures:
    print("\n".join("BROKEN: " + f for f in failures))
    sys.exit(1)
print("ok: all relative markdown links resolve")