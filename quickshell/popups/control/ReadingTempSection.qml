// ============================================================
// quickshell/popups/control/ReadingTempSection.qml — режим читання: слайдер температури hyprsunset
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../scripts/ControlState.js" as State

// Слайдер колірної температури (hyprsunset через сокет, з дебаунсом,
// одноразовими ретраями і автостартом демона). Значення персиститься
// через сигнал stateDirty (корінь дебаунсить запис у control-state.json).
// Корінь — ColumnLayout (не Item): дитина RowLayout живе за Layout.fillWidth,
// у plain Item вона схлопнулась би в нуль.
ColumnLayout {
  id: root

  required property QtObject window
  signal stateDirty()

  property int readingTemp: 6500
  // 3500 = макс. тепло, 6500 = вимкнено (≈identity)

  function stopRetry() {
    hyprsunsetRetry.stop()
  }

  Layout.fillWidth: true

  function setReadingTemp(val) {
    readingTemp = Math.max(3500, Math.min(6500, val))
    hyprsunsetDebounce.restart()
    State.setReadingTemp(readingTemp)
    stateDirty()
  }

  function ensureHyprsunset() {
    hyprsunsetEnsureProc.command = ["sh", "-c",
      'SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.hyprsunset.sock"; ' +
      'if echo "temperature 6500" | socat - UNIX-CONNECT:"$SOCK" 2>/dev/null; then exit 0; fi; ' +
      'killall hyprsunset 2>/dev/null; ' +
      'rm -f "$SOCK" 2>/dev/null; ' +
      'sleep 0.5; ' +
      'nohup hyprsunset --temperature 6500 >/dev/null 2>&1 &']
    hyprsunsetEnsureProc.running = true
  }

  function _doSetHyprsunset() {
    hyprsunsetRetry.stop()
    var temp = readingTemp
    hyprsunsetSocat.command = ["sh", "-c",
      'SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.hyprsunset.sock"; ' +
      'if echo "temperature ' + temp + '" | socat - UNIX-CONNECT:"$SOCK" 2>/dev/null; then exit 0; fi; ' +
      'exit 1']
    hyprsunsetSocat.running = true
  }

  Process {
    id: hyprsunsetEnsureProc
    onExited: running = false
  }

  // socat для зміни температури через сокет (одноразовий).
  // Обмежена кількість ретраїв — якщо hyprsunset зламаний/відсутній,
  // не спамимо socat-процесами вічно
  property int _hyprsunsetRetries: 0
  readonly property int _hyprsunsetMaxRetries: 6

  Process {
    id: hyprsunsetSocat
    onExited: (exitCode) => {
      running = false
      if (exitCode === 0) {
        _hyprsunsetRetries = 0
      } else if (readingTemp < 6500 && _hyprsunsetRetries < _hyprsunsetMaxRetries) {
        _hyprsunsetRetries++
        hyprsunsetRetry.start()
      } else {
        _hyprsunsetRetries = 0
      }
    }
  }

  Timer {
    id: hyprsunsetDebounce
    interval: 80
    onTriggered: _doSetHyprsunset()
  }

  Timer {
    id: hyprsunsetRetry
    interval: 500
    onTriggered: _doSetHyprsunset()
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 8

    Text {
      text: "\uF186"
      color: readingTemp < 6400 ? window.palette.orange : window.palette.gray
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
          readonly property real fill: Math.max(0, Math.min(1, (6500 - readingTemp) / 3000))
          width: parent.width * fill
          height: parent.height
          radius: 3
          color: window.palette.orange
          Behavior on width { NumberAnimation { duration: window.appConfig.anim(250); easing.type: Easing.OutSine } }
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => { if (mouse.button === Qt.LeftButton) setReadingTemp(6500 - Math.round(mouse.x / width * 3000)) }
        onPositionChanged: mouse => { if (pressedButtons & Qt.LeftButton) setReadingTemp(6500 - Math.round(mouse.x / width * 3000)) }
        onClicked: mouse => {
          if (mouse.button === Qt.MiddleButton) setReadingTemp(readingTemp < 6400 ? 6500 : 4500)
          else if (mouse.button === Qt.RightButton) setReadingTemp(6500)
        }
        onWheel: wheel => {
          var step = wheel.angleDelta.y > 0 ? -150 : 150
          setReadingTemp(readingTemp + step)
        }
      }
    }

    Text {
      text: readingTemp >= 6500 ? "OFF" : readingTemp + "K"
      color: readingTemp < 6400 ? window.palette.orange : window.palette.textLight
      font.family: window.palette.font
      font.pixelSize: window.appConfig.scaled(11)
      Layout.preferredWidth: 36
      horizontalAlignment: Text.AlignRight
      Layout.alignment: Qt.AlignVCenter
    }
  }
}
