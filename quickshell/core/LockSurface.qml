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

  // Стан розкладки — спільний KeyboardLayoutState (та сама логіка, що
  // у віджета бара). Тут лишаються лише локальні UI-стани бейджа.
  property bool kbHovered: false
  property bool kbListOpen: false

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

  KeyboardLayoutState { id: kbState }

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
      NumberAnimation { target: kbBadge; property: "opacity"; from: 0; to: 1; duration: root._d(200); easing.type: Easing.OutCubic }
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
    onClicked: {
      root.kbListOpen = false
      hiddenInput.forceActiveFocus()
    }
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
      // Єдина дитина колонки — поле завжди строго по центру; бейдж
      // розкладки живе всередині (якори до parent валідні). z щоб меню
      // розкладки перекривало текст помилки під полем.
      z: 2
      // Розширюється під довгий пароль миттєво (без Behavior: анімована
      // ширина відставала від точок і вони на мить обрізались). Далі
      // максимуму точки скроляться через dotsViewport, краї цілі (clip).
      implicitWidth: Math.max(280, Math.min(dotsRow.implicitWidth + 56, 560, Math.max(0, root.width - 220)))
      implicitHeight: 46
      radius: 23
      // Без clip: краї ріже dotsViewport з власним clip нижче
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

      // Анімовані точки замість символів. В'юпорт з полями + автоскрол
      // до хвоста: поки влазять — по центру, довший пароль — видно
      // останні символи, краї пігулки не розриваються.
      Item {
        id: dotsViewport
        anchors.fill: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        clip: true

        Row {
          id: dotsRow
          spacing: 6
          anchors.verticalCenter: parent.verticalCenter
          x: Math.min((parent.width - width) / 2, parent.width - width)
          Behavior on x { NumberAnimation { duration: root._d(150); easing.type: Easing.OutCubic } }

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

  // Бейдж розкладки праворуч від поля вводу: ЛКМ — next (як віджет
  // в барі), ПКМ — інлайн-список. Кореневий елемент з x/y-біндингами:
  // якори до inputBg недійсні (не sibling/parent), а дитина поза межами
  // батька кліки не отримує. Поле лишається єдиною дитиною колонки —
  // строго по центру. Кліки повертають фокус паролю вручну.
  Item {
    id: kbBadge
    x: passwordLayout.x + inputBg.x + inputBg.width + 10
    y: passwordLayout.y + inputBg.y + (inputBg.height - height) / 2
    width: kbPill.implicitWidth
    height: kbPill.implicitHeight
    opacity: 0

    Rectangle {
      id: kbPill
      anchors.centerIn: parent
      implicitWidth: kbText.implicitWidth + 30
      implicitHeight: 34
      radius: 17
      color: root.palette.bg0H
      opacity: kbMouse.containsMouse ? 0.85 : 0.6
      border.width: kbMouse.containsMouse ? 1 : 0
      border.color: root.palette.mutedAlt
      Behavior on opacity { NumberAnimation { duration: root._d(150) } }

      Text {
        id: kbText
        anchors.centerIn: parent
        text: kbState.displayText
        color: root.kbHovered ? root.palette.green : root.palette.textLight
        font.family: root.palette.font
        font.pixelSize: 14
        scale: root.kbHovered ? 1.08 : 1.0
        Behavior on color { ColorAnimation { duration: root._d(220) } }
        Behavior on scale {
          NumberAnimation { duration: root._d(120); easing.type: Easing.OutBack; easing.overshoot: 2.5 }
        }
      }

      MouseArea {
        id: kbMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        onEntered: root.kbHovered = true
        onExited: root.kbHovered = false
        onClicked: mouse => {
          if (mouse.button === Qt.LeftButton) {
            root.kbListOpen = false
            kbState.cycleNext()
          } else {
            if (root.kbListOpen) {
              root.kbListOpen = false
            } else {
              kbState.refreshMenu()
              root.kbListOpen = true
            }
          }
          hiddenInput.forceActiveFocus()
        }
      }
    }
  }

  // Меню вибору розкладки — окремий кореневий елемент під бейджем:
  // всередині kbBadge вилазило б за його межі з тією самою проблемою кліків.
  Rectangle {
    id: kbMenu
    x: kbBadge.x + kbBadge.width - width
    y: kbBadge.y + kbBadge.height + 8
    width: 140
    height: kbMenuCol.implicitHeight + 16
    radius: 10
    color: root.palette.bg0H
    opacity: 0.95
    border.width: 1
    border.color: root.palette.mutedAlt
    visible: root.kbListOpen && kbState.layoutsModel.length > 0

    Column {
      id: kbMenuCol
      anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        topMargin: 8
        leftMargin: 6
        rightMargin: 6
      }
      spacing: 2

      Repeater {
        model: kbState.layoutsModel

        delegate: Rectangle {
          required property var modelData
          required property int index
          readonly property bool isActive: modelData.active

          width: kbMenuCol.width
          height: 28
          radius: 6
          color: kbRowArea.containsMouse ? root.palette.bg2 : "transparent"
          Behavior on color { ColorAnimation { duration: root._d(120) } }

          Text {
            anchors {
              left: parent.left
              leftMargin: 10
              verticalCenter: parent.verticalCenter
            }
            text: modelData.label
            color: isActive ? root.palette.green : root.palette.fg
            font.family: root.palette.font
            font.pixelSize: 12
            font.bold: isActive
          }

          Rectangle {
            opacity: isActive ? 1 : 0
            anchors {
              right: parent.right
              rightMargin: 10
              verticalCenter: parent.verticalCenter
            }
            width: 6
            height: 6
            radius: 3
            color: root.palette.green
            Behavior on opacity { NumberAnimation { duration: root._d(150); easing.type: Easing.OutCubic } }
          }

          MouseArea {
            id: kbRowArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: {
              kbState.switchTo(index)
              root.kbListOpen = false
              hiddenInput.forceActiveFocus()
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
