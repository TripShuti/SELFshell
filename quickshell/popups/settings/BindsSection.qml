// ============================================================
// settings/BindsSection.qml — розділ Binds: перегляд і переназначення
// гарячих клавіш. Пише ~/.config/hypr/binds.json (читає hypr/modules/
// binds.lua з фолбеком на дефолти) і застосовує через hyprctl reload.
// Захоплення клавіші — без SUPER: він додається автоматично (Hyprland
// перехоплює SUPER-комбінації глобально, тому зловити їх у попапі
// неможливо). Escape під час запису — скасувати.
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"

Item {
  id: root
  required property QtObject sys

  readonly property var ac: sys.ac
  readonly property var window: sys.window
  readonly property string hyprDir: "file://" + Quickshell.env("HOME") + "/.config/hypr"

  implicitWidth: parent?.width ?? 0
  implicitHeight: col.implicitHeight

  // id → {label, default} — дефолти мають збігатися з bindKey(...) у binds.lua
  readonly property var actions: [
    { id: "launcher",  label: "App launcher",     def: "SUPER + R" },
    { id: "settings",  label: "Settings popup",   def: "SUPER + S" },
    { id: "control",   label: "Control center",   def: "SUPER + Escape" },
    { id: "lock",      label: "Lock screen",      def: "SUPER + L" },
    { id: "clipboard", label: "Clipboard history", def: "SUPER + SHIFT + V" },
    { id: "browser",   label: "Browser",          def: "SUPER + W" },
    { id: "terminal",  label: "Terminal",         def: "SUPER + Q" },
    { id: "files",     label: "File manager",     def: "SUPER + E" },
    { id: "suspend",   label: "Suspend key",      def: "" } // дефолт — з env.json
  ]

  // Оверрайди з binds.json (лише змінені користувачем значення)
  property var overrides: ({})
  // suspendKey з env.json — дефолт дії suspend
  property string envSuspend: ""
  property string capturing: ""   // id дії в режимі запису
  property string hint: ""
  property color hintColor: window.palette.mutedAlt
  property string status: ""

  function defaultFor(id) {
    for (var i = 0; i < actions.length; i++)
      if (actions[i].id === id)
        return id === "suspend" ? envSuspend : actions[i].def
    return ""
  }

  function valueFor(id) {
    return overrides[id] !== undefined ? overrides[id] : defaultFor(id)
  }

  function labelFor(id) {
    for (var i = 0; i < actions.length; i++)
      if (actions[i].id === id) return actions[i].label
    return id
  }

  // Нормалізація для порівняння конфліктів: регістр/пробіли/порядок модифікаторів
  function norm(combo) {
    if (!combo) return ""
    var parts = combo.toUpperCase().split("+")
    var out = []
    for (var i = 0; i < parts.length; i++) {
      var p = parts[i].trim()
      if (p !== "") out.push(p)
    }
    if (out.length > 1) out.sort()
    return out.join("|")
  }

  function conflictWith(id, combo) {
    for (var i = 0; i < actions.length; i++) {
      if (actions[i].id === id) continue
      if (norm(valueFor(actions[i].id)) !== "" && norm(valueFor(actions[i].id)) === norm(combo))
        return actions[i].label
    }
    return ""
  }

  function apply() {
    var out = {}
    for (var i = 0; i < actions.length; i++) {
      var id = actions[i].id
      var v = overrides[id]
      if (v !== undefined && norm(v) !== norm(defaultFor(id)))
        out[id] = v
    }
    _bindsFile.setText(JSON.stringify(out, null, 2) + "\n")
    status = "Reloading Hyprland..."
    _reloadProc.running = true
  }

  function resetAll() {
    overrides = {}
    _bindsFile.setText("{}\n")
    status = "Reloading Hyprland..."
    _reloadProc.running = true
  }

  Component.onCompleted: {
    try { _bindsFile.reload() } catch (e) {}
    try { _envFile.reload() } catch (e) {}
  }

  function parseBinds(text) {
    var data = {}
    try { data = text ? JSON.parse(text) : {} } catch (e) { data = {} }
    var clean = {}
    for (var k in data)
      if (typeof data[k] === "string" && data[k] !== "") clean[k] = data[k]
    overrides = clean
  }

  FileView {
    id: _bindsFile
    path: root.hyprDir + "/binds.json"
    watchChanges: false
    onFileChanged: this.reload()
    onDataChanged: root.parseBinds(this.text())
  }

  FileView {
    id: _envFile
    path: root.hyprDir + "/env.json"
    watchChanges: false
    onDataChanged: {
      try {
        var data = JSON.parse(this.text() || "{}")
        root.envSuspend = typeof data.suspendKey === "string" ? data.suspendKey : ""
      } catch (e) { root.envSuspend = "" }
    }
  }

  Process {
    id: _reloadProc
    command: ["hyprctl", "reload"]
    onExited: (code) => {
      root.status = code === 0 ? "Applied" : "hyprctl reload failed"
    }
  }

  ColumnLayout {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 12

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Keybindings" }

      // Підказка режиму запису
      Text {
        visible: root.capturing !== ""
        text: "Press a key for \"" + root.labelFor(root.capturing) +
              "\" (SUPER is added automatically). Escape cancels."
        color: root.window.palette.accent
        font.family: root.window.palette.font
        font.pixelSize: root.window.appConfig.scaled(10)
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
      }

      Text {
        visible: root.hint !== ""
        text: root.hint
        color: root.hintColor
        font.family: root.window.palette.font
        font.pixelSize: root.window.appConfig.scaled(10)
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
      }

      // Невидимий ловець клавіш — фокусується лише під час запису
      Item {
        id: captureArea
        visible: root.capturing !== ""
        width: 1; height: 1
        focus: visible

        Keys.onPressed: (event) => {
          event.accepted = true
          var k = event.key
          // модифікатори самі по собі — чекаємо основну клавішу
          if (k === Qt.Key_Shift || k === Qt.Key_Control || k === Qt.Key_Alt
              || k === Qt.Key_Meta || k === Qt.Key_AltGr
              || k === Qt.Key_Super_L || k === Qt.Key_Super_R) return
          if (k === Qt.Key_Escape) {
            root.capturing = ""
            root.hint = ""
            return
          }

          var name = root.keyName(k)
          if (name === "") {
            root.hint = "This key is not supported"
            root.hintColor = root.window.palette.danger
            return
          }

          var id = root.capturing
          var combo
          if (id === "suspend") {
            // одиночна клавіша без модифікаторів
            combo = name
          } else {
            combo = "SUPER"
            if (event.modifiers & Qt.ShiftModifier) combo += " + SHIFT"
            if (event.modifiers & Qt.ControlModifier) combo += " + CTRL"
            if (event.modifiers & Qt.AltModifier) combo += " + ALT"
            combo += " + " + name
          }

          var conflict = root.conflictWith(id, combo)
          if (conflict !== "") {
            root.hint = "Already used by \"" + conflict + "\""
            root.hintColor = root.window.palette.danger
            return
          }

          var next = Object.assign({}, root.overrides)
          next[id] = combo
          root.overrides = next
          root.capturing = ""
          root.hint = ""
          root.apply()
        }
      }

      Repeater {
        model: root.actions

        delegate: Rectangle {
          id: rowRoot
          required property var modelData
          property bool hovered: false

          readonly property string val: root.valueFor(modelData.id)
          readonly property bool modified: root.overrides[modelData.id] !== undefined

          Layout.fillWidth: true
          implicitHeight: 28
          radius: 5
          color: hovered ? root.window.palette.bg2 : root.window.palette.bgAlpha
          Behavior on color { ColorAnimation { duration: root.ac.anim(120) } }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            Text {
              text: modelData.label
              color: root.window.palette.fg
              font.family: root.window.palette.font
              font.pixelSize: root.window.appConfig.scaled(10)
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            Text {
              visible: rowRoot.modified
              text: "modified"
              color: root.window.palette.accent
              font.family: root.window.palette.font
              font.pixelSize: root.window.appConfig.scaled(8)
              font.italic: true
            }

            Text {
              text: rowRoot.val === "" ? "(unset)" : rowRoot.val
              color: rowRoot.val === "" ? root.window.palette.mutedAlt : root.window.palette.muted
              font.family: root.window.palette.font
              font.pixelSize: root.window.appConfig.scaled(10)
            }
          }

          MouseArea {
            id: delegateRoot
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: parent.hovered = true
            onExited: parent.hovered = false
            onClicked: {
              root.capturing = modelData.id
              root.hint = ""
              root.hintColor = root.window.palette.mutedAlt
              root.status = ""
              captureArea.forceActiveFocus()
            }
          }
        }
      }

      Text {
        text: "SUPER is always part of app/shell shortcuts. Suspend uses a single key (e.g. XF86Launch1)."
        color: root.window.palette.mutedAlt
        font.family: root.window.palette.font
        font.pixelSize: root.window.appConfig.scaled(9)
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
      }
    }

    SetCard {
      sys: root.sys
      SetLabel { sys: root.sys; text: "Apply" }

      Text {
        visible: root.status !== ""
        text: root.status
        color: root.status === "Applied" ? root.window.palette.green : root.window.palette.muted
        font.family: root.window.palette.font
        font.pixelSize: root.window.appConfig.scaled(10)
        Layout.fillWidth: true
      }

      SetButton {
        sys: root.sys
        text: "Reset all keybindings to defaults"
        onClicked: root.resetAll()
      }
    }
  }

  // Qt.Key → рядок-ксибсім Hyprland. Порожній рядок = клавіша не підтримується.
  function keyName(k) {
    if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k)
    if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k)
    if (k >= Qt.Key_F1 && k <= Qt.Key_F12) return "F" + (k - Qt.Key_F1 + 1)

    var special = [
      [Qt.Key_Escape, "Escape"], [Qt.Key_Minus, "minus"], [Qt.Key_Equal, "equal"],
      [Qt.Key_BracketLeft, "bracketleft"], [Qt.Key_BracketRight, "bracketright"],
      [Qt.Key_Semicolon, "semicolon"], [Qt.Key_Apostrophe, "apostrophe"],
      [Qt.Key_Comma, "comma"], [Qt.Key_Period, "period"], [Qt.Key_Slash, "slash"],
      [Qt.Key_Backslash, "backslash"], [Qt.Key_Grave, "grave"],
      [Qt.Key_Tab, "Tab"], [Qt.Key_Backslash, "backslash"],
      [Qt.Key_ScrollLock, "Scroll_Lock"], [Qt.Key_Pause, "Pause"]
    ]
    for (var i = 0; i < special.length; i++)
      if (k === special[i][0]) return special[i][1]

    // XF86-мультимедійні/launch-клавіші (наявність константи залежить від Qt)
    var xf86 = [
      [Qt.Key_Launch1, "XF86Launch1"], [Qt.Key_Launch2, "XF86Launch2"],
      [Qt.Key_Launch3, "XF86Launch3"], [Qt.Key_Launch4, "XF86Launch4"],
      [Qt.Key_Calculator, "XF86Calculator"], [Qt.Key_Mail, "XF86Mail"],
      [Qt.Key_HomePage, "XF86HomePage"], [Qt.Key_Search, "XF86Search"],
      [Qt.Key_Explorer, "XF86Explorer"], [Qt.Key_Tools, "XF86Tools"],
      [Qt.Key_AudioMedia, "XF86AudioMedia"], [Qt.Key_Favorites, "XF86Favorites"]
    ]
    for (var j = 0; j < xf86.length; j++)
      if (xf86[j][0] !== undefined && k === xf86[j][0]) return xf86[j][1]

    return ""
  }
}
