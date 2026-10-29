// ============================================================
// quickshell/core/CustomThemes.qml — спільна бібліотека власних тем і чернетка редактора.
// ============================================================
import Quickshell.Io
import QtQuick

Item {
  id: root
  visible: false
  required property QtObject palette
  required property QtObject appConfig
  required property QtObject wallpapers

  property var themes: []
  property string activeId: ""
  property string selectedKey: "accent"
  property string editingId: ""
  property string draftName: ""
  property var draft: ({})
  property string status: ""
  property bool failed: false
  property bool libraryValid: true
  property bool saveFailed: false
  readonly property bool busy: applyProc.running
  readonly property bool blocked: busy || wallpapers.applying
  readonly property bool valid: draftName.trim() !== "" && palette.colorKeys.every(function(key) {
    return /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(root.draft[key] ?? "")
  })
  property string pendingId: ""

  FileView {
    id: library
    path: Qt.resolvedUrl("../data/custom-themes.json")
    watchChanges: false
    preload: false
    blockLoading: true
    onSaveFailed: root.saveFailed = true
  }

  Component.onCompleted: {
    var text = library.text()
    if (text.trim() !== "") {
      try {
        var data = JSON.parse(text)
        if (data.version !== 1 || !Array.isArray(data.themes)) throw new Error("Invalid theme library")
        var ids = {}
        for (var i = 0; i < data.themes.length; i++) {
          var theme = data.themes[i]
          if (typeof theme.id !== "string" || !theme.id || ids[theme.id] || typeof theme.name !== "string" || !theme.name.trim() || !theme.colors) throw new Error("Invalid theme")
          ids[theme.id] = true
          if (Object.keys(theme.colors).length !== root.palette.colorKeys.length || !root.palette.colorKeys.every(function(key) {
            return /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(theme.colors[key] ?? "")
          })) throw new Error("Invalid palette")
        }
        root.themes = data.themes
        root.activeId = data.activeId ?? ""
      } catch (error) {
        root.libraryValid = false
        root.message("Cannot read custom-themes.json; repair the file before saving themes.", true)
      }
    }
    root.capture()
    if (root.activeId !== "") root.load(root.activeId)
  }

  function message(text, error) { status = text; failed = error }

  function persist() {
    if (!libraryValid) return false
    saveFailed = false
    library.setText(JSON.stringify({ version: 1, activeId: activeId, themes: themes }, null, 2))
    library.waitForJob()
    if (saveFailed) message("Could not save custom themes. Check file permissions and disk space.", true)
    return !saveFailed
  }

  function capture() {
    if (blocked) return
    var colors = {}
    for (var i = 0; i < palette.colorKeys.length; i++) {
      var key = palette.colorKeys[i]
      colors[key] = palette[key]
    }
    draft = colors
    editingId = ""
    draftName = "My theme"
  }

  function load(id) {
    if (blocked) return
    for (var i = 0; i < themes.length; i++) {
      if (themes[i].id === id) {
        editingId = id
        draftName = themes[i].name
        draft = Object.assign({}, themes[i].colors)
        message("Editing " + draftName, false)
        return
      }
    }
  }

  function setColor(key, value) {
    if (!busy) {
      var colors = Object.assign({}, draft)
      colors[key] = value
      draft = colors
    }
  }

  function save(copy) {
    if (blocked || !valid || !libraryValid) return ""
    var id = copy || editingId === "" ? "theme-" + Date.now() + "-" + Math.floor(Math.random() * 1000000) : editingId
    var theme = { id: id, name: draftName.trim(), colors: Object.assign({}, draft) }
    var old = themes
    var oldActive = activeId
    if (id === activeId && themes.some(function(t) { return t.id === id && JSON.stringify(t.colors) !== JSON.stringify(theme.colors) })) activeId = ""
    var next = themes.filter(function(t) { return t.id !== id })
    next.push(theme)
    themes = next
    if (!persist()) { themes = old; activeId = oldActive; return "" }
    editingId = id
    message("Saved " + theme.name, false)
    return id
  }

  function remove() { removeSaved(editingId) }

  function removeSaved(id) {
    if (blocked || id === "" || !themes.some(function(t) { return t.id === id })) return
    var old = themes
    var oldActive = activeId
    themes = themes.filter(function(t) { return t.id !== id })
    if (activeId === id) activeId = ""
    if (!persist()) { themes = old; activeId = oldActive; return }
    // Видалення пресета не змінює вже застосовані кольори.
    if (editingId === id) capture()
    message("Theme deleted; current colors are unchanged.", false)
  }

  function apply() {
    var id = save(false)
    if (id === "") return
    startApply(id)
  }

  function applySaved(id) {
    if (blocked || !libraryValid || !themes.some(function(t) { return t.id === id })) return
    load(id)
    startApply(id)
  }

  function startApply(id) {
    pendingId = id
    message("Applying custom theme...", false)
    applyProc.command = ["python3", Qt.resolvedUrl("../scripts/update-palette.py").toString().replace("file://", ""), "--custom", id]
    applyProc.running = true
  }

  Process {
    id: applyProc
    stderr: StdioCollector { id: errors; waitForEnd: true }
    onExited: (code) => {
      if (code !== 0) {
        root.message("Theme could not be fully applied. " + errors.text.trim(), true)
        root.palette.reload()
        return
      }
      root.activeId = root.pendingId
      root.appConfig.cfg.themeMode = "custom"
      if (!root.appConfig.flushSave()) {
        root.palette.reload()
        root.message("Colors applied, but Custom mode could not be saved. Check file permissions and disk space.", true)
        return
      }
      if (!root.persist()) { root.palette.reload(); return }
      root.palette.reload()
      footReload.running = true
      root.message("Custom theme applied. Wallpaper changes keep these colors.", false)
    }
  }
  Process { id: footReload; command: ["pkill", "-USR1", "-x", "foot"] }
}
