// ============================================================
// quickshell/core/LockSurface.qml — UI екрану блокування на один монітор
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
  // Опційно: для глобального множника тривалостей анімацій
  property QtObject appConfig: null

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

  Component.onCompleted: {
    curProc.running = true
    entranceAnim.start()
  }

  color: "#000000"

  // М'яка поява елементів при блокуванні: годинник → користувач+пароль →
  // кнопки живлення. Швидка і стримана (групи по 200ms з паузою 60ms).
  function _d(ms) { return root.appConfig ? root.appConfig.anim(ms) : ms }

  SequentialAnimation {
    id: entranceAnim
    ParallelAnimation {
      NumberAnimation { target: clockText; property: "opacity"; from: 0; to: 1; duration: root._d(200); easing.type: Easing.OutCubic }
      NumberAnimation { target: dateText; property: "opacity"; from: 0; to: 1; duration: root._d(200); easing.type: Easing.OutCubic }
      NumberAnimation { target: clockText; property: "scale"; from: 0.98; to: 1; duration: root._d(200); easing.type: Easing.OutCubic }
    }
    PauseAnimation { duration: root._d(60) }
    ParallelAnimation {
      NumberAnimation { target: userText; property: "opacity"; from: 0; to: 1; duration: root._d(200); easing.type: Easing.OutCubic }
      NumberAnimation { target: passwordLayout; property: "opacity"; from: 0; to: 1; duration: root._d(200); easing.type: Easing.OutCubic }
      NumberAnimation { target: passwordLayout; property: "scale"; from: 0.97; to: 1; duration: root._d(200); easing.type: Easing.OutCubic }
    }
    PauseAnimation { duration: root._d(60) }
    ParallelAnimation {
      NumberAnimation { target: powerRow; property: "opacity"; from: 0; to: 1; duration: root._d(200); easing.type: Easing.OutCubic }
    }
  }

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
    asynchronous: true
    cache: false
    onStatusChanged: {
      if (status === Image.Error && source !== root.wallpaperFallback)
        source = root.wallpaperFallback
    }
  }

  FastBlur {
    anchors.fill: parent
    source: wallpaperImg
    radius: 16
    transparentBorder: true
    // Кешуємо блюр у шарі — без layer 3 монітори = 3× full-screen blur 60fps
    layer.enabled: true
    layer.smooth: true
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
  }

  Text {
    id: dateText
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
  }

  Text {
    id: userText
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
      Behavior on opacity { NumberAnimation { duration: root._d(200) } }

      // Прихований TextInput — тільки приймає введення (echoMode Password щоб не
      // світився в accessibility/clipboard, ImhHiddenText + SensitiveData)
      TextInput {
        id: hiddenInput
        anchors.fill: parent
        color: "transparent"
        echoMode: TextInput.Password
        inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData
        passwordCharacter: " "
        focus: true
        enabled: !root.context.unlockInProgress && root.context.lockoutRemaining === 0

        onTextChanged: root.context.currentText = text
        onAccepted: root.context.tryUnlock()
      }
      // Синхронізація назад: коли LockContext очищає currentText
      // (при lock/fail/success), скидаємо текст поля
      Connections {
        target: root.context
        function onCurrentTextChanged() {
          if (hiddenInput.text !== root.context.currentText)
            hiddenInput.text = root.context.currentText
        }
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

            NumberAnimation on scale { from: 0; to: 1; duration: root._d(400); easing.type: Easing.OutCubic }
            NumberAnimation on opacity { from: 0; to: 1; duration: root._d(350) }
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

      Behavior on opacity { NumberAnimation { duration: root._d(200) } }

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
    id: powerRow
    anchors {
      horizontalCenter: parent.horizontalCenter
      bottom: parent.bottom
      bottomMargin: 60
    }
    spacing: 24

    property var actions: [
      { icon: "\uF186", tooltip: "Suspend", cmd: ["/usr/bin/systemctl", "suspend"] },
      { icon: "\uF021", tooltip: "Reboot", cmd: ["/usr/bin/systemctl", "reboot"] },
      { icon: "\uF011", tooltip: "Shutdown", cmd: ["/usr/bin/systemctl", "poweroff"] }
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
          Behavior on color { ColorAnimation { duration: root._d(150) } }

          Text {
            anchors.centerIn: parent
            text: act.icon
            color: btnArea.containsMouse ? root.palette.textLight : root.palette.mutedAlt
            font.family: root.palette.font
            font.pixelSize: 24
            Behavior on color { ColorAnimation { duration: root._d(150) } }
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
