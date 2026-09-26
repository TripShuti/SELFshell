# Contributing

## Language
- Code and comments — **Ukrainian** (tags `FIXME`/`TODO`/`HACK`/`NOTE` allowed as English prefix, but explanation after `—`/`:` — Ukrainian)
- Documentation (`docs/`, README), UI strings, commit messages — English
- Variable/function/component names — English (the programming language)

## Code style
- Every project file must start with a banner (for shebang files — right after `#!/...`):
  ```
  // ============================================================
  // <path>/<name> — short one-sentence description
  // ============================================================
  ```
  `<path>` is relative to the component root (`quickshell/core/AppConfig.qml`, `hypr/modules/env.lua`, `fish/config.fish`). Marker matches the file language: `//` for QML/JS/JSONC, `#` for Bash/Python/Fish/TOML/conf, `--` for Lua. Separator is 60 `=`, em dash `—` (U+2014) on line 2, one-sentence description.
  Exceptions:
  - pure JSON (`*.json` — `data/config.json`, `data/palette.json`, `hypr/env.json`) — no banner (JSON forbids comments);
  - generated files (`fish/conf.d/99-palette.fish`, `kitty/current-theme.conf`, `yazi/theme.toml`) — short one-line comment, language per generator;
  - auxiliary files (data, simple config) — a shorter one-line comment is enough.
  Comment markers matching the file's language (`#`, `//`, `--`).

- **Formatting (incremental, no mass refactor):**
  - `import`: `Quickshell*` → `QtQuick*` → local (`"core"`, `"widgets"`, `"popups"`). Don't reorder old files — follow for new code.
  - `property` order: `id` → `required property` → `implicit*`/`property` → `signal` → `function` → children. Avoid mixing `signal` inside `property`.
  - QML JS: `var` (canonical for QML), not `let`/`const` — to keep one style (`widgets/BluetoothWidget.qml:23` is an exception until next touch).
  - Quotes: QML — double (`"..."`), JS inside QML also double; single only if it saves escaping. No mass `'` → `"` churn.
  - Anchors: `anchors { left: }` vs `anchors.left:` — both valid, keep one style per file.
  - 2-space indent, no trailing whitespace, no mass `qmlformat` — large diff breaks `git blame` and risks binding loops (`Bar.qml` `Layout.fillHeight` on `Loader`).

## When to write a comment
- The decision is not obvious from the code (architectural choice, bug workaround, trade-off)
- There is a known workaround around a framework bug
- The data format is not self-evident
- There is a known fragility/edge case deliberately left unresolved

Do not write a comment that just repeats the variable/function name — that is noise.

## Commits
Commit messages are **English**, following the
[Conventional Commits](https://www.conventionalcommits.org) spec:

```
<type>(<scope>): <imperative summary>
```

- Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `perf`
- `scope` is optional (e.g. `feat(cli):`, `fix(lock):`)
- Summary in imperative mood, lowercase, no trailing period
- One commit per logical change; if you change logic, update the adjacent
  comment in the same commit

## Validation
Run the whole suite locally: `bash tests/run.sh` (skips tools you don't have).

Per layer:
- Bash scripts (`install.sh`, `scripts/selfshell`, `update-palette.sh`,
  `pacman_upgrade.sh`, `update-wallpaper-only.sh`, `tests/install_test.sh`):
  `bash -n <file>`; CI additionally runs `shellcheck -S warning`
- `install.sh` helpers (backup/rollback/prompts/retry): functional tests —
  `bash tests/install_test.sh` (extracts the real functions and runs them
  in a sandbox HOME)
- Lua: `lua5.4 -e "assert(loadfile(...))"` for syntax + unit tests via
  luajit (`luajit tests/lua/json_test.lua <root>` — json.lua must return
  `nil` on any broken input; `env_rules_test.lua`, `binds_test.lua`,
  `visual_test.lua` mock the global `hl`)
- Python scripts: stdlib tests always
  (`test_sysinfo`/`test_update_palette`/`test_pacman_updates`/`test_tracklist`
  one by one); `test_genshin.py` only with `requests`+`dotenv` installed
  (CI installs both and runs full `discover`)
- Config schemas: `python3 tests/check_config_schema.py` validates
  `data/config.json` and `hypr/env.json` against `CONFIG_FORMAT.md`,
  plus `binds.json` action ids, `visual.json` keys and
  `AppConfig` adapter/defaultCfg parity
- Docs: `python3 tests/check_md_links.py` — all relative links in `*.md`
  must resolve
- File banners: `python3 tests/check_banner.py` (see Code style above);
  repo URL must use the canonical `TripShuti/SELFshell` case
- Fish: `fish -n` on scripts; `tests/fake_upower.sh` fixtures the upower
  output contract parsed by `BatteryWidget`
- QML: quickshell has no `--check` — `selfshell reload` and check `qs log`
  for "Configuration Loaded"
- After changing hypr configs: `hyprctl reload` + `selfshell doctor`

## Changelog
- User-visible changes go into the `## [Unreleased]` section of
  `CHANGELOG.md` (Keep a Changelog categories: Added / Changed / Fixed /
  Removed / Deprecated / Security). The release workflow rejects a version
  tag without a matching changelog section.

## Releasing
Cutting a release is a documented manual procedure — see
[RELEASING.md](RELEASING.md).

## Before a PR
Read [ARCHITECTURE.md](ARCHITECTURE.md) — required.
