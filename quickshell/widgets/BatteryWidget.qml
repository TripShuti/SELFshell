// ============================================================
// quickshell/widgets/BatteryWidget.qml — віджет заряду батареї на панелі
// ============================================================
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Віджет батареї: іконка + відсоток, червоний < 15% без зарядки.
// Джерело — UPower через `upower` (зовнішня програма, без читання файлів).
Item {
  id: root

  required property QtObject window
  property int percent: -1
  property string state: ""
  property string device: ""

  // Прихований на машинах без батареї (десктоп)
  readonly property bool available: device !== ""
  visible: available

  // Hover-стан для фідбеку (HoverText-рецепт: колір + масштаб)
  property bool hovered: false

  implicitWidth: rowLayout.implicitWidth
  implicitHeight: parent?.height ?? 36

  readonly property bool charging: state === "charging" || state === "pending-charge"
  readonly property bool low: percent >= 0 && percent <= 15 && !root.charging

  // Сповіщення про низький заряд: один раз за цикл розряду (не спамимо
  // кожні 30 с опитування), скидається при зарядці або > 15%.
  // DND поважається — тост не показується, коли dndEnabled.
  property bool lowNotified: false
  onLowChanged: {
    // Гістерезис: re-arm лише при зарядці або >= 20% — без нього заряд,
    // що коливається біля 15%, спамив би тостом на кожному пересіченні
    if (root.percent >= 20 || root.charging) { root.lowNotified = false; return }
    if (!root.low || root.lowNotified) return
    root.lowNotified = true
    if (window.appConfig.cfg.dndEnabled) return
    window.toast.showNotif({
      appName: "Battery",
      summary: "Low battery (" + root.percent + "%)",
      body: "Connect the charger.",
      appIcon: "battery-low",
      actions: []
    })
  }

  readonly property string icon: {
    var p = root.percent
    if (p < 0) return "\uF097" // battery-unknown
    if (root.charging) return "\uF0E7" // bolt
    if (p < 13) return "\uF240"
    if (p < 38) return "\uF241"
    if (p < 63) return "\uF242"
    if (p < 88) return "\uF243"
    return "\uF244"
  }

  readonly property color iconColor: root.low ? window.palette.danger
      : root.charging ? window.palette.green
      : root.hovered ? window.palette.green
      : window.palette.fg

  // sysfs не підтримує inotify, тому раз на 30 с опитуємо upower
  Timer {
    interval: 30000
    repeat: true
    triggeredOnStart: true
    running: true
    onTriggered: devsProc.running = true
  }

  // Крок 1: знайти пристрій батареї
  Process {
    id: devsProc
    command: ["upower", "-e"]
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        var dev = ""
        for (var line of String(data ?? "").split(/\r?\n/)) {
          if (/battery/i.test(line)) { dev = line; break }
        }
        if (root.device !== dev) root.device = dev
        if (dev !== "") {
          infoProc.command = ["upower", "-i", dev]
          infoProc.running = true
        }
      }
    }
  }

  // Крок 2: прочитати стан та відсоток
  Process {
    id: infoProc
    command: []
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        var pct = root.percent
        var st = root.state
        for (var line of String(data ?? "").split(/\r?\n/)) {
          var m = line.match(/^\s*([a-z]+)\s*:\s*(.+?)\s*$/)
          if (!m) continue
          if (m[1] === "percentage") {
            var v = parseInt(m[2], 10)
            if (!isNaN(v)) pct = v
          } else if (m[1] === "state") {
            st = m[2]
          }
        }
        root.percent = pct
        root.state = st
      }
    }
  }

  // Клік — негайне оновлення
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    onEntered: root.hovered = true
    onExited: root.hovered = false
    onClicked: devsProc.running = true
  }

  RowLayout {
    id: rowLayout
    anchors.centerIn: parent
    spacing: 5
    scale: root.hovered ? 1.08 : 1.0
    Behavior on scale {
      NumberAnimation { duration: window.appConfig.anim(120); easing.type: Easing.OutBack; easing.overshoot: 2.5 }
    }

    Text {
      text: root.icon
      color: root.iconColor
      font.family: window.palette.font
      font.pixelSize: window.appConfig.scaled(13)
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(220) } }
    }
    Text {
      text: root.percent >= 0 ? root.percent + "%" : "--"
      color: root.iconColor
      font.family: window.palette.font
      font.pixelSize: window.appConfig.scaled(12)
      Behavior on color { ColorAnimation { duration: window.appConfig.anim(220) } }
    }
  }
}
