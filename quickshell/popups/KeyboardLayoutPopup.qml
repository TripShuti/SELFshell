// ============================================================
// quickshell/popups/KeyboardLayoutPopup.qml — вибір розкладки клавіатури
// ============================================================
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../core"

// Відкривається ПКМ на віджеті розкладки. Показує список розкладок
// з input:kb_layout; клік — перемикання через switchxkblayout.
AnimatedPopup {
  id: root

  required property QtObject window
  required property QtObject anchorItem
  palette: window.palette
  appConfig: window.appConfig

  popupWindow: window
  anchorTarget: anchorItem

  implicitWidth: 170

  // Готова модель рядків: [{ label, active }]
  property var layoutsModel: []
  // Сирі дані: код розкладки, ім'я main-клавіатури, активна розкладка
  property var rawCodes: []
  property string mainKeyboard: ""
  property string activeKeymap: ""
  property bool devsDone: false
  property bool layoutsDone: false

  // hyprctl -j друкує pretty-printed JSON (поле на рядок), тому SplitParser
  // ріже його по рядках і JSON.parse одного рядка завжди падає. Накопичуємо
  // рядки в буфер і парсимо лише коли накопичився повний документ.
  property string devsBuf: ""
  property string layoutsBuf: ""

  Component.onCompleted: { anchor.window = window }

  onVisibleChanged: {
    if (visible) {
      root.positionUnderAnchor()
      root.refresh()
    }
  }

  function refresh() {
    root.devsDone = false
    root.layoutsDone = false
    devsProc.running = true
    layoutProc.running = true
  }

  // Перекладає код розкладки (us, ua, de...) в коротку мітку
  function layoutLabel(code) {
    var map = {
      us: "US", ua: "UA", ru: "RU", de: "DE", fr: "FR", gb: "GB", uk: "UK",
      es: "ES", it: "IT", pl: "PL", cz: "CZ", se: "SE", fi: "FI", no: "NO",
      tr: "TR", il: "IL", br: "BR", pt: "PT", nl: "NL", be: "BE", ch: "CH",
      jp: "JP", kr: "KR", cn: "CN"
    }
    var key = String(code).toLowerCase().split(/[\s(-]+/)[0]
    return map[key] || String(code).toUpperCase()
  }

  // Визначає індекс активної розкладки за active_keymap
  function activeIndex(activeKeymap, codes) {
    var ak = String(activeKeymap || "").toLowerCase()
    var words = {
      us: "us", ua: "ukrain", ru: "russi", de: "german", fr: "french",
      gb: "english (uk)", uk: "english (uk)", es: "spanish", it: "italian",
      pl: "polish", cz: "czech", se: "swedish", fi: "finnish", tr: "turkish",
      il: "hebrew", br: "brazil", pt: "portuguese", nl: "dutch", jp: "japanese",
      kr: "korean", cn: "chinese"
    }
    for (var i = 0; i < codes.length; ++i) {
      var c = String(codes[i]).toLowerCase()
      var w = words[c]
      if (w && ak.indexOf(w) >= 0) return i
    }
    for (var i = 0; i < codes.length; ++i) {
      var c = String(codes[i]).toLowerCase().replace(/[^a-z]/g, "")
      if (c !== "" && ak.replace(/[^a-z]/g, "").indexOf(c) >= 0) return i
    }
    return -1
  }

  // Модель готовить тільки коли є обидва джерела даних
  function rebuildModel() {
    if (!root.devsDone || !root.layoutsDone) return
    var idx = root.activeIndex(root.activeKeymap, root.rawCodes)
    var out = []
    for (var i = 0; i < root.rawCodes.length; ++i) {
      out.push({ label: root.layoutLabel(root.rawCodes[i]), active: i === idx })
    }
    root.layoutsModel = out
  }

  // Ім'я main-клавіатури + активна розкладка (для підсвітки)
  Process {
    id: devsProc
    command: ["hyprctl", "devices", "-j"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        root.devsBuf += (data ?? "")
        var obj = null
        try { obj = JSON.parse(root.devsBuf) } catch (e) {}
        if (obj === null) return
        root.devsBuf = ""
        var keyboards = obj.keyboards ?? []
        for (var i = 0; i < keyboards.length; ++i) {
          if (keyboards[i].main === true) {
            root.mainKeyboard = keyboards[i].name
            root.activeKeymap = keyboards[i].active_keymap ?? ""
            break
          }
        }
        if (root.mainKeyboard === "" && keyboards.length > 0) {
          root.mainKeyboard = keyboards[0].name
          root.activeKeymap = keyboards[0].active_keymap ?? ""
        }
        root.devsDone = true
        root.rebuildModel()
      }
    }
  }

  // Список розкладок з input:kb_layout
  Process {
    id: layoutProc
    command: ["hyprctl", "getoption", "input:kb_layout", "-j"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        root.layoutsBuf += (data ?? "")
        var obj = null
        try { obj = JSON.parse(root.layoutsBuf) } catch (e) {}
        if (obj === null) return
        root.layoutsBuf = ""
        var codes = String(obj.str ?? "").split(",")
        var out = []
        for (var i = 0; i < codes.length; ++i) {
          var code = codes[i].trim()
          if (code !== "") out.push(code)
        }
        root.rawCodes = out
        root.layoutsDone = true
        root.rebuildModel()
      }
    }
  }

  Process {
    id: switchProc
    command: ["hyprctl", "switchxkblayout", "", ""]
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 10
    spacing: 4

    Text {
      text: "Keyboard Layout"
      color: window.palette.gray
      font.family: window.palette.font
      font.pixelSize: appConfig.scaled(9)
      font.bold: true
    }

    Repeater {
      model: root.layoutsModel

      delegate: Rectangle {
        required property var modelData
        required property int index
        readonly property bool isActive: modelData.active

        Layout.fillWidth: true
        height: 26
        radius: 5
        color: rowArea.containsMouse ? window.palette.bg2 : "transparent"
        Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }

        Text {
          anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
          text: modelData.label
          color: isActive ? window.palette.green : window.palette.fg
          font.family: window.palette.font
          font.pixelSize: appConfig.scaled(11)
          font.bold: isActive
        }

        Rectangle {
          // Fade замість visible: плавна поява точки активної розкладки
          opacity: isActive ? 1 : 0
          scale: isActive ? 1 : 0.4
          anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
          width: 6
          height: 6
          radius: 3
          color: window.palette.green
          Behavior on opacity { NumberAnimation { duration: appConfig.anim(150); easing.type: Easing.OutCubic } }
          Behavior on scale {
            NumberAnimation { duration: appConfig.anim(150); easing.type: Easing.OutBack; easing.overshoot: 1.5 }
          }
        }

        MouseArea {
          id: rowArea
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true
          onClicked: {
            if (root.mainKeyboard !== "") {
              switchProc.command = ["hyprctl", "switchxkblayout", root.mainKeyboard, String(index)]
              switchProc.running = true
            }
            root.close()
          }
        }
      }
    }

    // Порожній стан — не вдалось отримати список розкладок
    Text {
      visible: root.layoutsDone && root.layoutsModel.length === 0
      text: "No layouts"
      color: window.palette.muted
      font.family: window.palette.font
      font.pixelSize: appConfig.scaled(10)
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
