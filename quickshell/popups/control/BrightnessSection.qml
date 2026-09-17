// ============================================================
// quickshell/popups/control/BrightnessSection.qml — слайдер яскравості монітора через ddcutil
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../scripts/ControlState.js" as State

// Слайдер яскравості через ddcutil. Дисплей оптимістичний (значення видно
// одразу), на шину йде один запис за драг: одна DDC-транзакція йде секунди,
// а покроковий sub-stepping на такій шині давав 6 команд на драг 100→10
// і слайдер стрибав по проміжних станах. Значення персиститься через сигнал
// stateDirty (корінь дебаунсить запис у control-state.json). Опитування
// датчика — тільки поки попап відкритий (setPolling з кореневого
// onVisibleChanged: у вкладеному компоненті власний onVisibleChanged
// не стріляє). Корінь — ColumnLayout (див. ReadingTempSection).
ColumnLayout {
  id: root

  required property QtObject window
  signal stateDirty()

  property int brightness: -1
  property int prevBrightness: 50
  // Останнє значення, віддане в ddcutil (-2 = ще нічого не слали)
  property int _sent: -2

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
    // драг шле тік за тіком — на шину лише останнє в простої
    setDebounce.restart()
    State.setBrightness(brightness)
    stateDirty()
  }

  // Коалесцинг записів: пишемо не частіше ніж раз на паузу в драгу
  Timer {
    id: setDebounce
    interval: 120
    onTriggered: root._flushSet()
  }

  function _flushSet() {
    if (setBrightnessProc.running) return // onExited докаже сам
    if (root.brightness === root._sent) return // залізо вже там
    _doSetDdcutil(root.brightness)
  }

  function toggleBrightness() {
    if (brightness <= 10) {
      setBrightness(prevBrightness)
    } else {
      prevBrightness = brightness
      setBrightness(10)
    }
  }

  function _doSetDdcutil(val) {
    root._sent = val
    setBrightnessProc.command = ["ddcutil", "setvcp", "10", String(val)]
    setBrightnessProc.running = true
  }

  StdioCollector {
    id: brightnessCollector
    waitForEnd: true
    onDataChanged: {
      if (brightnessCollector.text) {
        // поки є недослане (драг/політ) — чужу відповідь не чіпаємо,
        // інакше слайдер стрибає на проміжне/застаріле значення
        if (root.brightness !== root._sent || setBrightnessProc.running || setDebounce.running) return
        var text = brightnessCollector.text.trim()
        var match = text.match(/current value = +(\d+).+max value = +(\d+)/)
        if (match) { brightness = parseInt(match[1]) }
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
      // ціль зрушилась під час польоту — шлемо свіже
      if (root._sent !== root.brightness) root._flushSet()
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
