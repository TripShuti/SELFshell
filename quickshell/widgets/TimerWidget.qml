// ============================================================
// TimerWidget.qml — таймер на панелі
// ============================================================
import Quickshell
import Quickshell.Io
import "../Palette.js" as Palette
import QtQuick

// Віджет таймера на панелі — відлік, нагадування, керування колесом
Item {
  id: root

  property bool timerRunning: false
  property int timerDuration: 25
  property int timerRemaining: 0
  property string timerClass: "idle"

  readonly property string displayText: {
    if (timerClass === "done") return "\uF253 00:00"
    if (timerRunning) {
      var m = Math.floor(timerRemaining / 60)
      var s = timerRemaining % 60
      return "\uF017 " + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0")
    }
    return "\uF017 " + String(timerDuration).padStart(2, "0") + ":00"
  }

  implicitWidth: txt.implicitWidth
  implicitHeight: parent?.height ?? 36

  // Лічильник з інтервалом 1 секунда
  Timer {
    id: countdown
    interval: 1000
    repeat: true
    triggeredOnStart: false
    onTriggered: {
      root.timerRemaining -= 1
      if (root.timerRemaining <= 0) {
        countdown.stop()
        root.timerRunning = false
        root.timerRemaining = 0
        root.timerClass = "done"
        notifyProc.running = true
      }
    }
  }

  // Сповіщення та звук при завершенні
  Process {
    id: notifyProc
    command: ["sh", "-c", "notify-send -u critical 'Таймер' 'Час вийшов!' & for i in 1 2 3; do paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null; sleep 0.5; done"]
  }

  // Старт / стоп
  function toggle() {
    if (root.timerRunning) {
      countdown.stop()
      root.timerRunning = false
      root.timerClass = "idle"
      root.timerRemaining = 0
    } else {
      root.timerClass = "running"
      root.timerRunning = true
      root.timerRemaining = root.timerDuration * 60
      countdown.start()
    }
  }

  // Збільшити тривалість
  function durUp() {
    if (!root.timerRunning) {
      root.timerDuration += 1
    }
  }

  // Зменшити тривалість
  function durDown() {
    if (!root.timerRunning && root.timerDuration > 1) {
      root.timerDuration -= 1
    }
  }

  Text {
    id: txt
    text: root.displayText
    color: root.timerClass === "running" ? Palette.green
         : root.timerClass === "done" ? Palette.red
         :  Palette.widgetFg
    font.family: Palette.font
    font.pixelSize: 13
    anchors.verticalCenter: parent.verticalCenter

    Behavior on color { ColorAnimation { duration: 220 } }

    // Блимання при завершенні
    SequentialAnimation on opacity {
      running: root.timerClass === "done"
      loops: Animation.Infinite
      NumberAnimation { to: 0.4; duration: 600; easing.type: Easing.InOutSine }
      NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    onClicked: root.toggle()
    onWheel: wheel => {
      if (wheel.angleDelta.y > 0)
        root.durUp()
      else
        root.durDown()
    }
  }
}
