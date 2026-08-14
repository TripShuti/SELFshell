// ============================================================
// LockSurface.qml — UI екрану блокування на один монітор
// ============================================================
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

// Поверхня блокування для одного монітора.
// Інстанціюється WlSessionLock через WlSessionLockSurface.
Rectangle {
  id: root

  required property QtObject context
  required property QtObject palette

  // current.<ext> генерується локально (update-palette.sh) і не в git —
  // шлях шукаємо через update-palette.py current, на свіжому клоні
  // fallback на трековану заглушку wp1.jpg
  readonly property string paletteScriptPath: Qt.resolvedUrl("../scripts/update-palette.py").toString().replace("file://", "")
  readonly property string wallpaperFallback: Qt.resolvedUrl("../wp/wp1.jpg")
  property string wallpaperSource: wallpaperFallback

  // Отримує шлях шпалери для lock-скріна (current-lock.jpg або фолбек).
  // Читаємо через onDataChanged колектора (як у WallpaperPopup): у
  // onExited текст ще може бути неповним — тоді зостається wp1.jpg.
  Process {
    id: curProc
    stdout: curCollector
    command: ["python3", root.paletteScriptPath, "current"]
  }

  StdioCollector {
    id: curCollector
    waitForEnd: true
    onDataChanged: {
      var p = curCollector.text.trim()
      if (p)
        root.wallpaperSource = "file://" + p
    }
  }

  Component.onCompleted: curProc.running = true

  color: "#000000"

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  // Фокус: клік на будь-якій ділянці екрана форсує фокус
  // на полі пароля (необхідно для багатомоніторних конфігурацій)
  MouseArea {
    anchors.fill: parent
    onClicked: hiddenInput.forceActiveFocus()
  }

  // Шпалера як фон з блюром
  Image {
    id: wallpaperImg
    anchors.fill: parent
    source: root.wallpaperSource
    fillMode: Image.PreserveAspectCrop
    onStatusChanged: {
      if (status === Image.Error && source !== root.wallpaperFallback)
        source = root.wallpaperFallback
    }
  }

  FastBlur {
    anchors.fill: parent
    source: wallpaperImg
    radius: 24
    transparentBorder: true
  }

  // Затемнення поверх блюра
  Rectangle {
    anchors.fill: parent
    color: "#000000"
    opacity: 0.35
  }

  Text {
    id: clockText
    anchors {
      horizontalCenter: parent.horizontalCenter
      top: parent.top
      topMargin: 120
    }
    text: Qt.formatDateTime(clock.date, "HH:mm")
    color: root.palette.textLight
    font.family: root.palette.font
    font.pixelSize: 120
    font.weight: Font.Normal
    style: Text.Outline
    styleColor: "#40000000"

    Timer {
      running: true
      repeat: true
      interval: 1000
      onTriggered: clockText.text = Qt.formatDateTime(clock.date, "HH:mm")
    }
  }

  Text {
    anchors {
      horizontalCenter: parent.horizontalCenter
      top: clockText.bottom
      topMargin: 8
    }
    text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
    color: root.palette.muted
    font.family: root.palette.font
    font.pixelSize: 24
    style: Text.Outline
    styleColor: "#30000000"

    Timer {
      running: true
      repeat: true
      interval: 60000
      onTriggered: parent.text = Qt.formatDateTime(clock.date, "dddd, d MMMM")
    }
  }

  Text {
    anchors {
      horizontalCenter: parent.horizontalCenter
      bottom: passwordLayout.top
      bottomMargin: 32
    }
    text: root.context.userName
    color: root.palette.fg
    font.family: root.palette.font
    font.pixelSize: 20
    opacity: 0.8
  }

  ColumnLayout {
    id: passwordLayout
    anchors {
      horizontalCenter: parent.horizontalCenter
      top: parent.verticalCenter
      topMargin: -12
    }
    spacing: 8

    Rectangle {
      id: inputBg
      implicitWidth: 280
      implicitHeight: 46
      radius: 23
      color: root.palette.bg0H
      opacity: hiddenInput.activeFocus ? 0.7 : 0.5
      border.width: hiddenInput.activeFocus ? 1 : 0
      border.color: root.palette.mutedAlt
      Behavior on opacity { NumberAnimation { duration: 200 } }

      // Прихований TextInput — тільки приймає введення
      TextInput {
        id: hiddenInput
        anchors.fill: parent
        color: "transparent"
        echoMode: TextInput.Normal
        inputMethodHints: Qt.ImhSensitiveData
        focus: true
        enabled: !root.context.unlockInProgress && root.context.lockoutRemaining === 0

        onTextChanged: root.context.currentText = text
        onAccepted: root.context.tryUnlock()
      }

      // Анімовані точки замість символів
      Row {
        anchors.centerIn: parent
        spacing: 6

        Repeater {
          model: hiddenInput.text.length

          delegate: Text {
            text: "\u25CF"
            color: root.palette.textLight
            font.family: root.palette.font
            font.pixelSize: 12

            NumberAnimation on scale { from: 0; to: 1; duration: 400; easing.type: Easing.OutCubic }
            NumberAnimation on opacity { from: 0; to: 1; duration: 350 }
          }
        }
      }
    }

    Text {
      id: failureText
      Layout.alignment: Qt.AlignHCenter
      visible: root.context.showFailure
      text: root.context.lockoutRemaining > 0
        ? "Too many attempts. Try again in " + root.context.lockoutRemaining + "s"
        : "Incorrect password"
      color: root.palette.danger
      font.family: root.palette.font
      font.pixelSize: 14
      opacity: visible ? 1 : 0

      Behavior on opacity { NumberAnimation { duration: 200 } }

      Timer {
        running: root.context.showFailure
        interval: 3000
        onTriggered: root.context.showFailure = false
      }
    }

    // Повідомлення "Unlocking..." поки PAM обробляє пароль
    Text {
      Layout.alignment: Qt.AlignHCenter
      visible: root.context.unlockInProgress
      text: "Unlocking..."
      color: root.palette.muted
      font.family: root.palette.font
      font.pixelSize: 13
    }
  }

  RowLayout {
    anchors {
      horizontalCenter: parent.horizontalCenter
      bottom: parent.bottom
      bottomMargin: 60
    }
    spacing: 24

    property var actions: [
      { icon: "\uF186", tooltip: "Suspend", cmd: ["sh", "-c", "qs ipc call lockscreen lock && systemctl suspend"] },
      { icon: "\uF021", tooltip: "Reboot", cmd: ["reboot"] },
      { icon: "\uF011", tooltip: "Shutdown", cmd: ["shutdown", "now"] }
    ]

    Repeater {
      model: parent.actions

      delegate: Item {
        required property var modelData
        readonly property var act: modelData

        implicitWidth: 56
        implicitHeight: 56

        Rectangle {
          anchors.fill: parent
          radius: 14
          color: btnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
          Behavior on color { ColorAnimation { duration: 150 } }

          Text {
            anchors.centerIn: parent
            text: act.icon
            color: btnArea.containsMouse ? root.palette.textLight : root.palette.mutedAlt
            font.family: root.palette.font
            font.pixelSize: 24
            Behavior on color { ColorAnimation { duration: 150 } }
          }

          MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              powerProc.command = act.cmd
              powerProc.running = true
            }
          }
        }
      }
    }
  }

  Process {
    id: powerProc
    onExited: running = false
  }
}
