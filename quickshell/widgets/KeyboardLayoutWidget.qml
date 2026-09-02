// ============================================================
// quickshell/widgets/KeyboardLayoutWidget.qml — розкладка клавіатури на панелі
// ============================================================
import Quickshell.Io
import "../core"
import QtQuick

// Віджет розкладки клавіатури — показує поточну мову (UA, RU, US тощо)
Item {
  id: root

  required property QtObject window
  property string layout: "US"

  // ПКМ — запит попапа зі списком розкладок (обробляється в Bar.qml)
  signal openPopup(Item anchor)

  // Hover-стан для фідбеку (HoverText-рецепт: колір + масштаб)
  property bool hovered: false

  // hyprctl -j друкує pretty-printed JSON (поле на рядок), тому SplitParser
  // ріже його по рядках і JSON.parse одного рядка завжди падає. Накопичуємо
  // рядки в буфер і парсимо лише коли накопичився повний документ.
  property string initialBuf: ""
  property string devsBuf: ""

  readonly property string displayText: {
    var l = root.layout
    if (l.indexOf("Ukrainian") >= 0) return "UA"
    if (l.indexOf("Russian") >= 0) return "RU"
    if (l.indexOf("German") >= 0) return "DE"
    if (l.indexOf("French") >= 0) return "FR"
    if (l.indexOf("(UK)") >= 0) return "UK"
    if (l.indexOf("English") >= 0 || l.indexOf("(US)") >= 0) return "US"
    // Невідома розкладка — перші 3 літери першого слова (Persian → PER)
    var first = String(l).split(/[\s(-]+/)[0] ?? ""
    return first.slice(0, 3).toUpperCase()
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
        root.initialBuf += (data ?? "")
        var obj = null
        try { obj = JSON.parse(root.initialBuf) } catch (e) {}
        if (obj === null) return
        root.initialBuf = ""
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

    // Скидання буфера на старті: без цього залишок попереднього виводу
    // (напр. хвостовий чанк після успішного парсу) клеївся до нового
    // JSON, і він вже не парсився ніколи — клік-перемикачок умирав
    onStarted: root.devsBuf = ""

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        root.devsBuf += (data ?? "")
        var obj = null
        try { obj = JSON.parse(root.devsBuf) } catch (e) {}
        if (obj === null) return
        root.devsBuf = ""
        var mainName = ""
        var keyboards = obj.keyboards ?? []
        for (var i = 0; i < keyboards.length; ++i) {
          if (keyboards[i].main === true) { mainName = keyboards[i].name; break }
        }
        if (mainName === "" && keyboards.length > 0) mainName = keyboards[0].name
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
    color: root.hovered ? window.palette.green : window.palette.widgetFg
    font.family: window.palette.font
    font.pixelSize: window.appConfig.scaled(14)
    anchors.verticalCenter: parent.verticalCenter
    scale: root.hovered ? 1.08 : 1.0

    Behavior on color { ColorAnimation { duration: window.appConfig.anim(220) } }
    Behavior on scale {
      NumberAnimation { duration: window.appConfig.anim(120); easing.type: Easing.OutBack; easing.overshoot: 2.5 }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    onEntered: root.hovered = true
    onExited: root.hovered = false
    onClicked: mouse => {
      if (mouse.button === Qt.LeftButton) devsProc.running = true
      else root.openPopup(root)
    }
  }

  Component.onCompleted: {
    initialProc.running = true
    socketProc.running = true
  }
  Component.onDestruction: socketProc.running = false
}
