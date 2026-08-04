---
name: quickshell
description: QuickShell QML conventions for desktop shell development on Wayland. Use when working with QuickShell projects.
license: MIT
---

# QuickShell Conventions

QML-specific rules for QuickShell desktop shell development on Wayland.

## Structure

- Entry point is `shell.qml` with `ShellRoot` as the root object
- One QML type per file — filename matches the type name (PascalCase)
- Use `pragma Singleton` + `Singleton {}` root for shared state (clocks, services, settings)
- Singletons are accessed by filename — no import or instantiation needed
- Use `Scope {}` to group shared resources outside `Variants` — avoids duplicating processes/timers per screen
- Use `Variants` with `model: Quickshell.screens` + `delegate: Component {}` for multi-monitor support

## Idioms

- Prefer property bindings over imperative JS — let the engine handle reactivity
- Use `required property` for component inputs — enforces callers provide them
- Use `readonly property` for derived/computed values
- Use `id` only when something else needs to reference the object — don't assign ids to everything
- Inline components (`component Foo: Bar {}`) for file-scoped reusable pieces only
- Use `LazyLoader` for heavy popups and panels — set `loading: true` to preload in background

## QML/JS Caveats

- QML JS engine is **not full ES6** — no spread syntax (`...`), no destructuring, no template literals in all contexts
- Use `Qt.formatDateTime()` for date formatting, not JS Date methods
- `SystemClock` is preferred over shelling out to `date` — respects precision settings and saves battery

## Process & I/O

- Use `Process` + `StdioCollector` for shell command output
- Set `running: true` to start a process, re-set it to restart
- Pair `Process` with `Timer` for polling — keep both in the same `Scope` or `Singleton`
- Avoid spawning processes inside `Variants` delegates — hoist to parent `Scope`

## Windows

- `PanelWindow` for bars/panels — use `anchors { top: true; left: true; right: true }` for edge docking
- `PopupWindow` for dropdowns/menus — set `parentWindow` and position with `relativeX`/`relativeY`
- `FloatingWindow` for free-positioned overlay windows
- Set `screen: modelData` when inside a `Variants` delegate

## Style

- Properties before children, signals before functions
- Group related properties with comments only when the block is large
- Keep component files small — extract when a component exceeds ~80 lines
- Prefer Qt Quick Layouts (`ColumnLayout`, `RowLayout`) over manual anchoring for lists
