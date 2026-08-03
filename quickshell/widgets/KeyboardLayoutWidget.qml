// ============================================================
// KeyboardLayoutWidget.qml — розкладка клавіатури на панелі
// ============================================================
import Quickshell.Io
import "../core"
import QtQuick

// Віджет розкладки клавіатури — показує поточну мову (UA, RU, US тощо)
Item {
  id: root

  required property QtObject window
  property string layout: "US"

  readonly property string displayText: {
    var l = root.layout
    if (l.indexOf("Ukrainian") >= 0) return "UA"
    if (l.indexOf("Russian") >= 0) return "RU"
    if (l.indexOf("German") >= 0) return "DE"
    if (l.indexOf("French") >= 0) return "FR"
    return "US"
  }

  implicitWidth: txt.implicitWidth
  implicitHeight: parent?.height ?? 36

  // Отримує поточну розкладку при старті
  Process {
    id: initialProc
    command: ["hyprctl", "devices", "-j"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        var text = (data ?? "").trim()
        if (text === "") return
        try {
          var obj = JSON.parse(text)
          var keyboards = obj.keyboards ?? []
          for (var i = 0; i < keyboards.length; ++i) {
            if (keyboards[i].active_keymap && keyboards[i].main === true) {
              root.layout = keyboards[i].active_keymap; return
            }
          }
          for (var i = 0; i < keyboards.length; ++i) {
            var k = keyboards[i]
            if (k.active_keymap && k.name.indexOf("keyboard") < 0 && k.name.indexOf("system") < 0 && k.name.indexOf("consumer") < 0) {
              root.layout = k.active_keymap; return
            }
          }
          if (keyboards.length > 0 && keyboards[0].active_keymap) {
            root.layout = keyboards[0].active_keymap
          }
        } catch (e) {}
      }
    }
  }

  // Стежить за змінами розкладки через Hyprland socket
  Process {
    id: socketProc
    command: ["sh", "-c", "while true; do socat - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock 2>/dev/null; sleep 1; done"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        var text = (data ?? "").trim()
        if (text === "") return
        if (text.indexOf("activelayout") === 0) {
          var eventParts = text.split(">>")
          if (eventParts.length >= 2) {
            var dataParts = eventParts[1].split(",")
            root.layout = dataParts[dataParts.length - 1].trim()
          }
        }
      }
    }
  }

  // Перемикає розкладку при кліку: спершу знаходимо ім'я main-клавіатури,
  // потім запускаємо switchxkblayout прямими аргументами
  // (раніше — sh -c з python one-liner усередині)
  Process {
    id: devsProc
    command: ["hyprctl", "devices", "-j"]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        var text = (data ?? "").trim()
        if (text === "") return
        var mainName = ""
        try {
          var obj = JSON.parse(text)
          var keyboards = obj.keyboards ?? []
          for (var i = 0; i < keyboards.length; ++i) {
            if (keyboards[i].main === true) { mainName = keyboards[i].name; break }
          }
          if (mainName === "" && keyboards.length > 0) mainName = keyboards[0].name
        } catch (e) {}
        if (mainName !== "") {
          switchProc.command = ["hyprctl", "switchxkblayout", mainName, "next"]
          switchProc.running = true
        }
      }
    }
  }

  Process {
    id: switchProc
    command: ["hyprctl", "switchxkblayout", "", "next"]
  }

  Text {
    id: txt
    text: root.displayText
    color: window.palette.widgetFg
    font.family: window.palette.font
    font.pixelSize: 12
    anchors.verticalCenter: parent.verticalCenter
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: devsProc.running = true
  }

  Component.onCompleted: {
    initialProc.running = true
    socketProc.running = true
  }
}
