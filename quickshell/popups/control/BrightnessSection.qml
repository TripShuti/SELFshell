// ============================================================
// quickshell/popups/control/BrightnessSection.qml — слайдер яскравості монітора через ddcutil
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../scripts/ControlState.js" as State

// Слайдер яскравості (ddcutil з покроковим sub-stepping — обмеження DDC/CI).
// Значення персиститься через сигнал stateDirty (корінь дебаунсить запис
// у control-state.json). Опитування датчика — тільки поки попап відкритий
// (setPolling з кореневого onVisibleChanged: у вкладеному компоненті власний
// onVisibleChanged не стріляє). Корінь — ColumnLayout (див. ReadingTempSection).
ColumnLayout {
  id: root

  required property QtObject window
  signal stateDirty()

  property int brightness: -1
  property int prevBrightness: 50
  property int _pendingBrightness: -1

  Layout.fillWidth: true

  function refreshBrightness() {
    getBrightnessProc.running = true
  }

  function setPolling(on) {
    if (on) {
      refreshBrightness()
      brightnessPollTimer.running = true
    } else {
      brightnessPollTimer.running = false
    }
  }

  function setBrightness(val) {
    brightness = Math.max(0, Math.min(100, val))
    if (!setBrightnessProc.running) _advanceSubStep()
    State.setBrightness(brightness)
    stateDirty()
  }

  function toggleBrightness() {
    if (brightness <= 10) {
      setBrightness(prevBrightness)
    } else {
      prevBrightness = brightness
      setBrightness(10)
    }
  }

  function _advanceSubStep() {
    var target = brightness
    if (_pendingBrightness < 0) {
      _pendingBrightness = target
      _doSetDdcutil(target)
      return
    }
    var diff = target - _pendingBrightness
    if (Math.abs(diff) <= 15) {
      _pendingBrightness = target
      _doSetDdcutil(target)
    } else {
      _pendingBrightness += diff > 0 ? 15 : -15
      _doSetDdcutil(_pendingBrightness)
    }
  }

  function _doSetDdcutil(val) {
    setBrightnessProc.command = ["ddcutil", "setvcp", "10", String(val)]
    setBrightnessProc.running = true
  }

  StdioCollector {
    id: brightnessCollector
    waitForEnd: true
    onDataChanged: {
      if (brightnessCollector.text) {
        var text = brightnessCollector.text.trim()
        var match = text.match(/current value = +(\d+).+max value = +(\d+)/)
        if (match) { brightness = parseInt(match[1]); _pendingBrightness = brightness }
      }
    }
  }

  Process {
    id: getBrightnessProc
    command: ["ddcutil", "getvcp", "10"]
    stdout: brightnessCollector
  }

  Process {
    id: setBrightnessProc
    onExited: {
      running = false
      if (_pendingBrightness !== brightness) _advanceSubStep()
    }
  }

  Timer {
    id: brightnessPollTimer
    interval: 5000
    // Опитуємо ddcutil тільки поки попап відкритий — старт/стоп в
    // onVisibleChanged. Раніше таймер крутився вічно з моменту старту шела
    running: false
    repeat: true
    onTriggered: refreshBrightness()
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 8
    visible: brightness >= 0

    Text {
      text: "\uF185"
      color: window.palette.yellow
      font.family: window.palette.font
      font.pixelSize: window.appConfig.scaled(14)
      Layout.alignment: Qt.AlignVCenter
    }

    Item {
      Layout.fillWidth: true
      implicitHeight: 24

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: 6
        radius: 3
        color: window.palette.bgAlpha

        Rectangle {
          width: parent.width * (Math.max(0, Math.min(brightness, 100)) / 100)
          height: parent.height
          radius: 3
          color: window.palette.yellow
          Behavior on width { NumberAnimation { duration: window.appConfig.anim(350); easing.type: Easing.OutSine } }
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => { if (mouse.button === Qt.LeftButton) setBrightness(Math.round(mouse.x / width * 100)) }
        onPositionChanged: mouse => { if (pressedButtons & Qt.LeftButton) setBrightness(Math.round(mouse.x / width * 100)) }
        onClicked: mouse => {
          if (mouse.button === Qt.MiddleButton) toggleBrightness()
          else if (mouse.button === Qt.RightButton) setBrightness(100)
        }
        onWheel: wheel => {
          var step = wheel.angleDelta.y > 0 ? window.appConfig.cfg.brightnessStep : -window.appConfig.cfg.brightnessStep
          setBrightness(brightness + step)
        }
      }
    }

    Text {
      id: pctText
      text: brightness + "%"
      color: window.palette.textLight
      font.family: window.palette.font
      font.pixelSize: window.appConfig.scaled(11)
      Layout.preferredWidth: 32
      horizontalAlignment: Text.AlignRight
      Layout.alignment: Qt.AlignVCenter
    }
  }
}
